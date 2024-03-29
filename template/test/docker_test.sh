#!/bin/sh

set -e

echo "Waiting to ensure everything is fully ready for the tests..."
sleep 1200

echo "Checking main containers are reachable..."
if ! ping -c 10 -q nominatim-db ; then
    echo 'Nominatim Database container is not responding!'
    # TODO Display logs to help bug fixing
    #echo 'Check the following logs for details:'
    #tail -n 100 logs/*.log
    exit 2
fi

if ! ping -c 10 -q nominatim ; then
    echo 'Nominatim Main container is not responding!'
    # TODO Display logs to help bug fixing
    #echo 'Check the following logs for details:'
    #tail -n 100 logs/*.log
    exit 4
fi

# Add your own tests
# https://docs.docker.com/docker-hub/builds/automated-testing/
echo "Checking Nominatim status..."
curl --fail http://nominatim:8080/status.php | grep -q -e 'OK' || exit 1

# Success
echo 'Docker tests successful'
exit 0
