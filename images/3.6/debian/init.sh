#!/bin/sh

set -e

log() {
    echo "[$0] [$(date +%Y-%m-%dT%H:%M:%S%:z)] $*"
}

OSMFILE=${1:-/data/${NOMINATIM_MAP_NAME}}
PGDIR=${2:-${NOMINATIM_DB_NAME}-postgres}
THREADS=${3:-$(nproc)}
OSMDOWNLOAD=${4:-${GEOFABRIK_DOWNLOAD_URL}}

PROJECT_DIR=/app/src/

export PGDATA=/data/${PGDIR}

if [ "$IMPORT_WIKIPEDIA" = "true" ]; then
    log "Downloading Wikipedia importance dump"
    curl 'https://www.nominatim.org/data/wikimedia-importance.sql.gz' -o "${PROJECT_DIR}/data/wikimedia-importance.sql.gz"
else
    log "Skipping optional Wikipedia importance import"
fi

if [ "$IMPORT_GB_POSTCODES" = "true" ]; then
    log "Downloading optional GB postcode file"
    curl 'http://www.nominatim.org/data/gb_postcode_data.sql.gz' > "${PROJECT_DIR}/data/gb_postcode_data.sql.gz"
else
    log "Skipping optional GB postcode file"
fi

if [ "$IMPORT_US_POSTCODES" = "true" ]; then
    log "Downloading optional US postcode file"
    curl 'http://www.nominatim.org/data/us_postcode_data.sql.gz' > "${PROJECT_DIR}/data/us_postcode_data.sql.gz"
else
    log "Skipping optional US postcode file"
fi

if [ "$IMPORT_COUNTRY_GRID" = "true" ]; then
    log "Downloading optional country grid file"
    curl 'http://www.nominatim.org/data/country_grid.sql.gz' > "${PROJECT_DIR}/data/country_osm_grid.sql.gz"
else
    log "Skipping optional country grid file"
fi

# If no map, or database not initialized or initialized with different DB version
if [ ! -f "${OSMFILE}" ] || [ ! -f "${PGDATA}/.docker-data-version" ] || ! cmp --silent "${PGDATA}/.docker-data-version" "${PROJECT_DIR}/.docker-data-version"; then
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

    log "Starting download of OSM map '${OSMFILE}' at '${OSMDOWNLOAD}'..."
    curl -q -L -o "${OSMFILE}" "${OSMDOWNLOAD}"
    log "Download OSM map '${OSMFILE}' finished."

    touch "${OSMFILE}.todo"

else

    log "Initialization of database already performed for OSM map '${OSMFILE}'."
    exit 0

fi

log "Starting initialization of OSM database with map '${OSMFILE}' (this may take hours or days)..."
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

if [ -f "${OSMFILE}.todo" ]; then
    log "Dropping database '${NOMINATIM_DB_NAME}'..."

    sudo -u postgres psql postgres -c "DROP DATABASE IF EXISTS ${NOMINATIM_DB_NAME}"

    log "Drop of database '${NOMINATIM_DB_NAME}' finished."
fi

if ! id -u "${NOMINATIM_DB_USER}"; then
    log "Creating system user '${NOMINATIM_DB_USER}'..."
    useradd -m -p "${NOMINATIM_DB_PASSWD}" "${NOMINATIM_DB_USER}"

    log "Setting permissions to user '${NOMINATIM_DB_USER}'..."
    chown -R "${NOMINATIM_DB_USER}:${NOMINATIM_DB_USER}" "${PROJECT_DIR}"

    log "Creation of system user '${NOMINATIM_DB_USER}' finished."
fi

if [ -f "${OSMFILE}.todo" ]; then
    log "Importing OSM file '${OSMFILE}'..."

    if which nominatim; then
        # Starting Nominatim 3.7+
        sudo -u "${NOMINATIM_DB_USER}" nominatim import --project-dir "${PROJECT_DIR}/" --osm-file "${OSMFILE}" --threads "${THREADS}"
    else
        sudo -u "${NOMINATIM_DB_USER}" "${PROJECT_DIR}/build/utils/setup.php" --osm-file "${OSMFILE}" --all --threads "${THREADS}"
    fi

    rm "${OSMFILE}.todo"
    log "Import of OSM file '${OSMFILE}' finished."
fi

if which nominatim; then
    # Starting Nominatim 3.7+
    log "Starting check of import ..."
    sudo -u "${NOMINATIM_DB_USER}" nominatim admin --project-dir "${PROJECT_DIR}/build/" --check-database
    log "Check of import finished."

    log "Setup replication ..."
    sudo -u "${NOMINATIM_DB_USER}" nominatim replication --project-dir "${PROJECT_DIR}/build/" --init
    log "Setup of replication finished."
elif [ -f "${PROJECT_DIR}/build/utils/check_import_finished.php" ]; then
    log "Starting check of import ..."
    sudo -u "${NOMINATIM_DB_USER}" "${PROJECT_DIR}/build/utils/check_import_finished.php"
    log "Check of import finished."
fi

log "Stopping database..."
sudo -u postgres "/usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_ctl" -D "${PGDATA}" stop
sudo chown -R postgres:postgres "${PGDATA}"

log "Flag database version..."
cp -p "${PROJECT_DIR}/.docker-data-version" "${PGDATA}/.docker-data-version"

log "Deleting downloaded dumps in ${PGDATA}"
rm -f "${PGDATA}"/*sql.gz "${OSMFILE}"
