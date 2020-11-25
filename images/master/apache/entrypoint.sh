#!/bin/sh
##
##    Docker image for Mattermost-LDAP.
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

# init / update application
init() {
    # Check version
    log "jean-michel"
    if [ ! -f "./.docker-version" ]; then
        log "Toto Mattermost-LDAP init to ..."
        # Install server Oauth
        log "jean-michel"
        cp -r /opt/Mattermost-LDAP/oauth/ /var/www/html/
        log "jean-michel 2"
        # Get config file
        cp /var/www/html/oauth/config_db.php.example /var/www/html/oauth/config_db.php
        cp /var/www/html/oauth/LDAP/config_ldap.php.example /var/www/html/oauth/LDAP/config_ldap.php
        log "echo ${VERSION} ${VCS_REF} ${BUILD_DATE} to docker-version file"
        echo "${VERSION} ${VCS_REF} ${BUILD_DATE}" > "/opt/Mattermost-LDAP/.docker-version"

        rm /var/www/html/oauth/config_db.php.example /var/www/html/oauth/LDAP/config_ldap.php.example
    elif ! cmp --silent "./.docker-version" "/opt/Mattermost-LDAP/.docker-version"; then
        log "Mattermost-LDAP update from $(cat ./.docker-version) to $(cat /opt/Mattermost-LDAP/.docker-version)..."
        # Install server Oauth
        rsync -r /opt/Mattermost-LDAP/oauth/ /var/www/html/
        # Get config file
        rsync /var/www/html/oauth/config_db.php.example /var/www/html/oauth/config_db.php
        rsync /var/www/html/oauth/LDAP/config_ldap.php.example /var/www/html/oauth/LDAP/config_ldap.php

        rm /var/www/html/oauth/config_db.php.example /var/www/html/oauth/LDAP/config_ldap.php.example
    fi

    # cp -p "/opt/Mattermost-LDAP/.docker-version" "./.docker-version"
}

# start application
start() {
    init

    log "Update the config_db.php file..."
    sed -i \
        -e "s|\/\/date_default_timezone_set \(\'Europe/Paris\'\);|date_default_timezone_set \(\'TIMEZONE\'\);|g" \
        /var/www/html/oauth/config_db.php


    log "Start main service: '$@'"
    exec "$@"
}

# display help
print_help() {
    echo "Monogramm Docker entrypoint for Mattermost-LDAP.

Usage:
docker exec  <option> [arguments]

Options:
    start                     Start main service
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
"start") start "$2" ;;
*) exec "$@" ;;
esac
