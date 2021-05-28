#!/bin/sh
set -e

stopServices() {
    service postgresql stop
}
trap stopServices TERM

service postgresql start
tail -f "/var/log/postgresql/postgresql-${POSTGRES_VERSION}-main.log"
