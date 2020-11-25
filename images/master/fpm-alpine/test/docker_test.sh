#!/bin/sh

set -e

echo "Waiting to ensure everything is fully ready for the tests..."
sleep 60

echo "Checking main containers are reachable..."
if ! ping -c 10 -q mattermost-ldap-db ; then
    echo 'Mattermost-LDAP Database container is not responding!'
    #echo 'Check the following logs for details:'
    #tail -n 100 logs/*.log
    exit 2
fi

if ! ping -c 10 -q mattermost-ldap ; then
    echo 'Mattermost-LDAP Main container is not responding!'
    #echo 'Check the following logs for details:'
    #tail -n 100 logs/*.log
    exit 4
fi

# XXX Add your own tests
# https://docs.docker.com/docker-hub/builds/automated-testing/
#echo "Executing Mattermost-LDAP app tests..."
## TODO Test result of tests

# Success
echo 'Docker tests successful'
exit 0
