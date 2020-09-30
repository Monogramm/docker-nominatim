#!/bin/sh
##
##    Docker image for Nominatim.
##    Copyright (C) 2020  Monogramm
##
set -e

# -------------------------------------------------------------------
# Functions

log() {
    echo "[$0] [$(date +%Y-%m-%dT%H:%M:%S%:z)] $@"
}

# wait for file/directory to exists
wait_for_file() {
    WAIT_FOR_FILE=${1}
    if [ -z "${WAIT_FOR_FILE}" ]; then
        log "Missing file path to wait for!"
        exit 1
    fi

    WAIT_TIME=0
    WAIT_STEP=${2:-10}
    WAIT_TIMEOUT=${3:--1}

    while [ ! -d "${WAIT_FOR_FILE}" ]; do
        if [ "${WAIT_TIMEOUT}" -gt 0 ] && [ "${WAIT_TIME}" -gt "${WAIT_TIMEOUT}" ]; then
            log "File '${WAIT_FOR_FILE}' was not available on time!"
            exit 1
        fi

        log "Waiting file '${WAIT_FOR_FILE}'..."
        sleep "${WAIT_STEP}"
        WAIT_TIME=$((WAIT_TIME + WAIT_STEP))
    done
    log "File '${WAIT_FOR_FILE}' exists."
}

wait_for_files() {
    if [ -z "${WAIT_FOR_FILES}" ]; then
        log "Missing env var 'WAIT_FOR_FILES' defining files to wait for!"
        exit 1
    fi

    for H in ${WAIT_FOR_FILES}; do
        wait_for_file "${H}" "${WAIT_STEP}" "${WAIT_TIMEOUT}"
    done

}

# wait for service to be reachable
wait_for_service() {
    WAIT_FOR_ADDR=${1}
    if [ -z "${WAIT_FOR_ADDR}" ]; then
        log "Missing service's address to wait for!"
        exit 1
    fi

    WAIT_FOR_PORT=${2}
    if [ -z "${WAIT_FOR_PORT}" ]; then
        log "Missing service's port to wait for!"
        exit 1
    fi

    WAIT_TIME=0
    WAIT_STEP=${3:-10}
    WAIT_TIMEOUT=${4:--1}

    while ! nc -z "${WAIT_FOR_ADDR}" "${WAIT_FOR_PORT}"; do
        if [ "${WAIT_TIMEOUT}" -gt 0 ] && [ "${WAIT_TIME}" -gt "${WAIT_TIMEOUT}" ]; then
            log "Service '${WAIT_FOR_ADDR}:${WAIT_FOR_PORT}' was not available on time!"
            exit 1
        fi

        log "Waiting service '${WAIT_FOR_ADDR}:${WAIT_FOR_PORT}'..."
        sleep "${WAIT_STEP}"
        WAIT_TIME=$((WAIT_TIME + WAIT_STEP))
    done
    log "Service '${WAIT_FOR_ADDR}:${WAIT_FOR_PORT}' available."
}

wait_for_services() {
    if [ -z "${WAIT_FOR_SERVICES:-$1}" ]; then
        log "Missing env var 'WAIT_FOR_SERVICES' defining services to wait for!"
        exit 1
    fi

    for S in ${WAIT_FOR_SERVICES}; do
        WAIT_FOR_ADDR=$(echo "${S}" | cut -d: -f1)
        WAIT_FOR_PORT=$(echo "${S}" | cut -d: -f2)

        wait_for_service "${WAIT_FOR_ADDR}" "${WAIT_FOR_PORT}" "${WAIT_STEP}" "${WAIT_TIMEOUT}"
    done

}

# init OSM database
init_postgres() {
    if [ -z "${NOMINATIM_MAP_PATH}" ]; then
        log "Missing path to OSM map!"
        exit 1
    fi
    if [ -z "${NOMINATIM_DB_PATH}" ]; then
        log "Missing path to OSM database!"
        exit 1
    fi

    if [ ! -f "/data/${NOMINATIM_MAP_PATH}" ]; then
        if [ -z "${GEOFABRIK_DOWNLOAD_URL}" ]; then
            log "Missing file path to wait for!"
            exit 1
        fi

        log "Starting download of OSM map..."
        wget -O "/data/${NOMINATIM_MAP_PATH}" "${GEOFABRIK_DOWNLOAD_URL}"
        curl -q -L \
            -o "/data/${NOMINATIM_MAP_PATH}" \
            "${GEOFABRIK_DOWNLOAD_URL}"
        log "Download OSM map '${OSRM_MAP_NAME}' finished."
    fi

    if [ ! -d "/data/${NOMINATIM_DB_PATH}" ]; then
        log "Starting import of OSM map into database (this may take hours or days)..."
        sh /app/init.sh "/data/${NOMINATIM_MAP_PATH}" "${NOMINATIM_DB_PATH}" "${NOMINATIM_INIT_THREADS:-$(nproc)}"
        log "Import of OSM map into database finished."
    fi
}

# init Nominatim config
init_config() {
    if [ ! -f '/data/local.php' ]; then
        log "Initializing custom Nominatim config..."
        cp '/app/src/build/settings/local.php' '/data'
    fi

    if [ -z "${GEOFABRIK_REPLICATION_URL}" ]; then
        log "Removing Nominatim replication URL..."
        sed -i \
            -e "s|^@define('CONST_Replication_Url', '.*');|//@define('CONST_Replication_Url', '');//|g" \
            '/data/local.php'
    else
        log "Setting Nominatim replication URL..."
        sed -i \
            -e "s|^@define('CONST_Replication_Url', '.*');|@define('CONST_Replication_Url', '${GEOFABRIK_REPLICATION_URL}');//|g" \
            '/data/local.php'
    fi

    if [ -z "${NOMINATIM_DB_HOST}" ] || [ "${NOMINATIM_DB_HOST}" = 'localhost' ]; then
        log "Removing Nominatim Database DSN..."
        sed -i \
            -e "s|^@define('CONST_Database_DSN', '.*');.*|//@define('CONST_Database_DSN', '');|g" \
            '/data/local.php'
    else
        log "Setting Nominatim Database DSN..."
        sed -i \
            -e "s|^//@define('CONST_Database_DSN', '.*');|@define('CONST_Database_DSN', '${NOMINATIM_DB_DRIVER}:host=${NOMINATIM_DB_HOST};port=${NOMINATIM_DB_PORT};user=${NOMINATIM_DB_USER};password=${NOMINATIM_DB_PASSWD};dbname=${NOMINATIM_DB_NAME}');//|g" \
            '/data/local.php'
    fi

}

startstandalone() {
    log "Starting Nominatim as a single node..."
    bash /app/start.sh
}

startpostgres() {
    log "Starting Nominatim Database..."
    sh /app/startpostgres.sh
}

startapache() {
    wait_for_service "${NOMINATIM_DB_HOST}" "${NOMINATIM_DB_PORT}" "${WAIT_STEP}" "${WAIT_TIMEOUT}"

    log "Starting Nominatim REST service..."
    sh /app/startapache.sh
}

# init / update application
init_version() {
    # Check version
    if [ ! -f "./.docker-version" ]; then
        log "Nominatim init to $(cat /app/src/.docker-version)..."
    elif ! cmp --silent "./.docker-version" "/app/src/.docker-version"; then
        log "Nominatim update from $(cat ./.docker-version) to $(cat /app/src/.docker-version)..."

        if [ -n "${NOMINATIM_DB_PATH}" ] && [ -d "/data/${NOMINATIM_DB_PATH}" ]; then
            sudo -u postgres /app/src/build/utils/update.php --init-updates
            sudo -u postgres /app/src/build/utils/update.php --import-osmosis-all
        fi
    fi

    cp -p "/app/src/.docker-version" "./.docker-version"
}

# start application
start() {
    if [ -z "${NOMINATIM_DB_HOST}" ] || [ "${NOMINATIM_DB_HOST}" = 'localhost' ]; then
        init_postgres
        init_config
        init_version
        startstandalone
    else
        if [ -z "${NOMINATIM_DB_HOST}" ]; then
            init_postgres
            init_version
            startpostgres
        else
            init_config
            init_version
            startapache
        fi
    fi
}

# display help
print_help() {
    echo "Monogramm Docker entrypoint for Nominatim.

Usage:
docker exec  <option> [arguments]

Options:
    start                     Start main service with init of database
    --help                    Displays this help
    <command>                 Run an arbitrary command
"
}

# -------------------------------------------------------------------
# Runtime

# Execute task based on command
case "${1}" in
# Management tasks
"--help") print_help ;;
    # Service tasks
"start") start ;;
*) exec "$@" ;;
esac
