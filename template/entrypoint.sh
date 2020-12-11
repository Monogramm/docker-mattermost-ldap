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
        log "Mattermost-LDAP init to $(cat /opt/Mattermost-LDAP/.docker-version)..."
        # Install server Oauth
        cp -r /opt/Mattermost-LDAP/oauth/ /var/www/html/
        # Get config file
        cp /var/www/html/oauth/config_db.php.example /var/www/html/oauth/config_db.php
        cp /var/www/html/oauth/LDAP/config_ldap.php.example /var/www/html/oauth/LDAP/config_ldap.php
        log "echo ${VERSION} ${VCS_REF} ${BUILD_DATE} to docker-version file"
        echo "${VERSION} ${VCS_REF} ${BUILD_DATE}" > "/opt/Mattermost-LDAP/.docker-version"

        rm /var/www/html/oauth/config_db.php.example /var/www/html/oauth/LDAP/config_ldap.php.example

        log "Update the config_db.php file..."
        sed -i \
            -e "s|\/\/date_default_timezone_set \(\'Europe/Paris\'\);|date_default_timezone_set \(\'TIMEZONE\'\);|g" \
            /var/www/html/oauth/config_db.php

        log "Update the init database files..."
        if [ -z ${db_type} ]; then
            log "No database detected for initialisation."
            exit
        elif [ "${db_type}" = "mysql" ]; then
            if [ -x /opt/Mattermost-LDAP/db_init/init_mysql.sh ]; then
                # [TODO] Use a .sql script
                sed -i \
                    -e "s|source config_init\.sh|source \/opt\/Mattermost-LDAP\/db_init\/config_init\.sh|g" \
                    -e "s|mysql_pass=\"\"|mysql_pass=\"\${DB_ROOT_PASSWD}\"|g" \
                    -e "s|sudo mysql -u root --password=\$mysql_pass --execute|sudo mysql -u root --password=\$mysql_pass -h \$db_host --port=\$db_port --execute|g" \
                    -e "s|mysql -u \$db_user --password=\$db_pass \$db_name --execute|mysql -u \$db_user --password=\$db_pass -h \$db_host --port=\$db_port \$db_name --execute|g" \
                    /opt/Mattermost-LDAP/db_init/init_mysql.sh
            fi
        elif [ "${db_type}" = "pgsql" ]; then
            if [ -x /opt/Mattermost-LDAP/db_init/init_postgres.sh ]; then
                # [TODO] Use a .sql script
                sed -i \
                    -e "s|#!\/bin\/bash|#!\/bin\/sh|g" \
                    -e "s|source config_init\.sh|source \/opt\/Mattermost-LDAP\/db_init\/config_init\.sh|g" \
                    -e "s|psql -U postgres -c|#psql -h \$db_host -p \$db_port -U postgres -c|g" \
                    -e "s|psql -U \$db_user -d \$db_name -c|PGPASSWORD=\$db_pass psql -U \$db_user -d \$db_name -h \$db_host -p \$db_port -c|g" \
                    /opt/Mattermost-LDAP/db_init/init_postgres.sh
            fi
        else
            log "${db_type} is not an accepted value for database."
            exit
        fi

        log "Init the database..."
        if [ "${db_type}" = "mysql" ]; then
            /opt/Mattermost-LDAP/db_init/init_mysql.sh
        elif [ "${db_type}" = "pgsql" ]; then
            /opt/Mattermost-LDAP/db_init/init_postgres.sh
        else
            log "${db_type} is not an accepted value for database."
            exit
        fi
    elif ! cmp -s "./.docker-version" "/opt/Mattermost-LDAP/.docker-version"; then
        log "Mattermost-LDAP update from $(cat ./.docker-version) to $(cat /opt/Mattermost-LDAP/.docker-version)..."
        # Install server Oauth
        rsync -rlDog --exclude="/etc/nginx/conf.d/default.conf" /opt/Mattermost-LDAP/oauth/ /var/www/html/
        # Get config file
        if [ -f "/var/www/html/oauth/config_db.php.example" ]; then
            rsync -lDog /var/www/html/oauth/config_db.php.example /var/www/html/oauth/config_db.php
            rm /var/www/html/oauth/config_db.php.example
        fi
        if [ -f "/var/www/html/oauth/LDAP/config_ldap.php.example" ]; then
            rsync -lDog /var/www/html/oauth/LDAP/config_ldap.php.example /var/www/html/oauth/LDAP/config_ldap.php
            rm /var/www/html/oauth/LDAP/config_ldap.php.example
        fi
            
        # [TODO] Implement update script for database
    fi

    cp -p "/opt/Mattermost-LDAP/.docker-version" "./.docker-version"
}

# start application
start() {
    init

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
