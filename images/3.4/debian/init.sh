#!/bin/sh

set -e

log() {
    echo "[$0] [$(date +%Y-%m-%dT%H:%M:%S%:z)] $@"
}

OSMFILE=${1:-/data/${NOMINATIM_MAP_NAME}}
PGDIR=${2:-${NOMINATIM_DB_NAME}-postgres}
THREADS=${3:-$(nproc)}
OSMDOWNLOAD=${4:-${GEOFABRIK_DOWNLOAD_URL}}

export PGDATA=/data/${PGDIR}

if [ ! -f "${OSMFILE}" ] || [ ! -d "${PGDATA}" ]; then
    rm -rf "${PGDATA}"
    mkdir -p "${PGDATA}"

    if [ -z "${OSMFILE}" ]; then
        log "Missing download URL for OSM file!"
        exit 1
    fi

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

if [ -f "${OSMFILE}.todo" ]; then
    log "Initializating database..."
    sudo -u postgres "/usr/lib/postgresql/${POSTGRES_VERSION}/bin/initdb" -D "${PGDATA}"
fi

log "Starting database..."
sudo -u postgres "/usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_ctl" -D "${PGDATA}" start

log "Checking Postgres user '${NOMINATIM_DB_USER}'..."
sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${NOMINATIM_DB_USER}'" | grep -q 1 || sudo -u postgres createuser -s "${NOMINATIM_DB_USER}"
log "Checking Postgres user 'www-data'..."
sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='www-data'" | grep -q 1 || sudo -u postgres createuser -SDR www-data

if ! id -u "${NOMINATIM_DB_USER}"; then
    log "Dropping database '${NOMINATIM_DB_NAME}' and creating system user '${NOMINATIM_DB_USER}'..."

    sudo -u postgres psql postgres -c "DROP DATABASE IF EXISTS ${NOMINATIM_DB_NAME}"
    useradd -m -p "${NOMINATIM_DB_PASSWD}" "${NOMINATIM_DB_USER}"
    chown -R "${NOMINATIM_DB_USER}:${NOMINATIM_DB_USER}" ./src

    log "Drop of database '${NOMINATIM_DB_NAME}' and creation of system user '${NOMINATIM_DB_USER}' finished."
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

log "Stoping database..."
sudo -u postgres "/usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_ctl" -D "${PGDATA}" stop
sudo chown -R postgres:postgres "${PGDATA}"
