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
    if [ ! -f "./.docker-version" ]; then
        log "[TODO] Mattermost-LDAP init to $(cat /app/src/.docker-version)..."
    elif ! cmp --silent "./.docker-version" "/app/src/.docker-version"; then
        log "[TODO] Mattermost-LDAP update from $(cat ./.docker-version) to $(cat /app/src/.docker-version)..."
    fi

    cp -p "/app/src/.docker-version" "./.docker-version"
}

# start application
start() {
    init


    # Install server Oauth
    cp -r /opt/Mattermost-LDAP/oauth/ /var/www/html/
    # Get config file
    cp /var/www/html/oauth/config_db.php.example /var/www/html/oauth/config_db.php; cp /var/www/html/oauth/LDAP/config_ldap.php.example /var/www/html/oauth/LDAP/config_ldap.php
    rm /var/www/html/oauth/config_db.php.example; rm /var/www/html/oauth/LDAP/config_ldap.php.example

    # Update the config_db.php file
    sed -i \
        -e "s|\$db_name	  = getenv\(\'db_name\'\) \?: \"oauth_db\";|\$db_name	  = getenv\(\'MATTERMOST-LDAP_DB_NAME\'\) \?: \"mattermost-ldap_db_name\";|g" \
        -e "s|\$db_user	  = getenv\(\'db_user\'\) \?: \"oauth_db\";|\$db_user	  = getenv\(\'MATTERMOST-LDAP_DB_USER\'\) \?: \"mattermost-ldap_db_user\";|g" \
        -e "s|\$db_pass	  = getenv\(\'db_pass\'\) \?: \"oauth_db\";|\$db_name	  = getenv\(\'MATTERMOST-LDAP_DB_PASSWD\'\) \?: \"mattermost-ldap_db_passwd\";|g" \
        -e "s|\/\/date_default_timezone_set \(\'Europe/Paris\'\);|date_default_timezone_set \(\'Europe/Paris\'\);|g" \
        /var/www/html/oauth/config_db.php
    
    # [TODO] if mattermostldap db is postgresql
    sed -i \
        -e "s|\$db_type	  = getenv\(\'db_type\'\) \?: \"oauth_db\";|\$db_type	  = \"pgsql\";|g" \
        -e "s|\$db_port	  = getenv\(\'db_port\'\) \?: \"oauth_db\";|\$db_port	  = 5432;|g" \
        -e "s|\$db_host	  = getenv\(\'db_host\'\) \?: \"oauth_db\";|\$db_host	  = \"127.0.0.1\";|g" \
        /var/www/html/oauth/config_db.php
    # fi
    # [TODO] elif mattermostldap db is mariadb
    sed -i \
        -e "s|\$db_type	  = getenv\(\'db_type\'\) \?: \"oauth_db\";|\$db_type	  = \"mysql\";|g" \
        -e "s|\$db_port	  = getenv\(\'db_port\'\) \?: \"oauth_db\";|\$db_port	  = 3306;|g" \
        -e "s|\$db_host	  = getenv\(\'db_host\'\) \?: \"oauth_db\";|\$db_host	  = \"127.0.0.1\";|g" \
        /var/www/html/oauth/config_db.php
    # fi


    # Update the config_ldap.php file
    sed -i \
        -e "s|\$ldap_host = getenv\(\'ldap_host\'\) \?: \"ldap:\/\/ldap\.company\.com\/\";|\$ldap_host	  = getenv\(\'LDAP_HOST\'\) \?: \"ldap:\/\/openldap:389/\";|g" \
        -e "s|\$ldap_port = intval\(getenv\(\'ldap_port\'\)\) \?: 389;|\$ldap_port	  = getenv\(\'LDAP_PORT\'\) \?: 389;|g" \
        -e "s|\$ldap_version = intval\(getenv\(\'ldap_version\'\)\) \?: 3;|\$ldap_version = intval\(getenv\(\'LDAP_VERSION\'\)\) \?: 3;|g" \
        -e "s|\$ldap_start_tls = boolval\(getenv\(\'ldap_start_tls\'\)\) \?: false;|\$ldap_start_tls = boolval\(getenv\(\'LDAP_START_TLS\'\)\) \?: true;|g" \
        -e "s|\$ldap_search_attribute = getenv\(\'ldap_search_attribute\'\) \?: \"uid\";|\$ldap_search_attribute = getenv\(\'LDAP_SEARCH_ATTRIBUTE\'\) \?: \"uid\";|g" \
        -e "s|\$ldap_base_dn = getenv\(\'ldap_base_dn\'\) \?: \"ou=People,o=Company\";|\$ldap_base_dn = getenv\(\'LDAP_BASE_DN\'\) \?: \"ou=People,o=Company\";|g" \
        -e "s|\$ldap_filter = getenv\(\'ldap_filter\'\) \?: \"\(objectClass=\*\)\";|\$ldap_filter = getenv\(\'LDAP_FILTER\'\) \?: \"\(objectClass=\*\)\";|g" \
        -e "s|\$ldap_bind_dn = getenv\(\'ldap_bind_dn\'\) \?: \"\";|\$ldap_bind_dn = getenv\(\'LDAP_BIND_DN\'\) \?: \"\";|g" \
        -e "s|\$ldap_bind_pass = getenv\(\'ldap_bind_pass\'\) \?: \"\";|\$ldap_bind_pass = getenv\(\'LDAP_BIND_PASS\'\) \?: \"\";|g" \
        /var/www/html/oauth/config_ldap.php


    echo "[TODO] Start main service"
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
"start") start ;;
*) exec "$@" ;;
esac
