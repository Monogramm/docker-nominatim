#!/bin/sh
set -e

if [ -f /data/local.php ]; then
    cp /data/local.php /app/src/build/settings/local.php
fi

/usr/sbin/apache2ctl -D FOREGROUND
tail -f /var/log/apache2/error.log
