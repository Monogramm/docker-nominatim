#!/bin/sh
set -e

/usr/sbin/apache2ctl -D FOREGROUND
tail -f /var/log/apache2/error.log
