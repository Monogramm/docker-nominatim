#!/bin/sh

set -e

log() {
    echo "[$0] [$(date +%Y-%m-%dT%H:%M:%S%:z)] $@"
}

OSMFILE=$1
PGDIR=${2:-${NOMINATIM_DB_NAME}-postgres}
THREADS=${3:-$(nproc)}
OSMDOWNLOAD=$4

export PGDATA=/data/${PGDIR}

if [ ! -f "${OSMFILE}" ]; then
    rm -rf "${PGDATA}"
    mkdir -p "${PGDATA}"

    if [ -z "${OSMDOWNLOAD}" ]; then
        log "Missing download URL for OSM file!"
        exit 1
    fi

    log "Starting download of OSM map '${OSMFILE}'..."
    curl -q -L -o "${OSMFILE}" "${OSMDOWNLOAD}"
    log "Download OSM map '${OSMFILE}' finished."

    touch "${OSMFILE}.todo"

fi

chown postgres:postgres "${PGDATA}"

log "Starting database for initialization..."
sudo -u postgres "/usr/lib/postgresql/${POSTGRES_VERSION}/bin/initdb" -D "${PGDATA}"
sudo -u postgres "/usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_ctl" -D "${PGDATA}" start

if ! id -u "${NOMINATIM_DB_USER}"; then
    log "Creating users in database..."

    sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${NOMINATIM_DB_USER}'" | grep -q 1 || sudo -u postgres createuser -s "${NOMINATIM_DB_USER}"
    sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='www-data'" | grep -q 1 || sudo -u postgres createuser -SDR www-data
    sudo -u postgres psql postgres -c "DROP DATABASE IF EXISTS ${NOMINATIM_DB_NAME}"
    useradd -m -p "${NOMINATIM_DB_PASSWD}" "${NOMINATIM_DB_USER}"
    chown -R "${NOMINATIM_DB_USER}:${NOMINATIM_DB_USER}" ./src

    log "Creation of users in database finished."
fi

if [ -f "${OSMFILE}.todo" ]; then
    log "Importing OSM file '${OSMFILE}'..."
    sudo -u "${NOMINATIM_DB_USER}" ./src/build/utils/setup.php --osm-file "${OSMFILE}" --all --threads "${THREADS}"

    rm "${OSMFILE}.todo"
    log "Import of OSM file '${OSMFILE}' finished."
fi

if [ -f ./src/build/utils/check_import_finished.php ]; then
    log "Starting check of import ..."
    sudo -u "${NOMINATIM_DB_USER}" ./src/build/utils/check_import_finished.php
    log "Check of import finished."
fi

log "Stoping database after initialization..."
sudo -u postgres "/usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_ctl" -D "${PGDATA}" stop
sudo chown -R postgres:postgres "${PGDATA}"
