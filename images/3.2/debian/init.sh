#!/bin/sh

set -e

OSMFILE=$1
PGDIR=${2:-${NOMINATIM_DB_NAME}-postgres}
THREADS=${3:-$(nproc)}

rm -rf "/data/${PGDIR}"
mkdir -p "/data/${PGDIR}"

export PGDATA=/data/${PGDIR}
chown postgres:postgres "${PGDATA}"

sudo -u postgres "/usr/lib/postgresql/${POSTGRES_VERSION}/bin/initdb" -D "${PGDATA}"
sudo -u postgres "/usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_ctl" -D "${PGDATA}" start
sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${NOMINATIM_DB_USER}'" | grep -q 1 || sudo -u postgres createuser -s "${NOMINATIM_DB_USER}"
sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='www-data'" | grep -q 1 || sudo -u postgres createuser -SDR www-data
sudo -u postgres psql postgres -c "DROP DATABASE IF EXISTS ${NOMINATIM_DB_NAME}"
useradd -m -p "${NOMINATIM_DB_PASSWD}" "${NOMINATIM_DB_USER}"
chown -R "${NOMINATIM_DB_USER}:${NOMINATIM_DB_USER}" ./src
sudo -u "${NOMINATIM_DB_USER}" ./src/build/utils/setup.php --osm-file "${OSMFILE}" --all --threads "${THREADS}"

if [ -f ./src/build/utils/check_import_finished.php ]; then
    sudo -u "${NOMINATIM_DB_USER}" ./src/build/utils/check_import_finished.php
fi

sudo -u postgres "/usr/lib/postgresql/${POSTGRES_VERSION}/bin/pg_ctl" -D "${PGDATA}" stop
sudo chown -R postgres:postgres "${PGDATA}"
