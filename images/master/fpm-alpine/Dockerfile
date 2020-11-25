FROM php:7.3-fpm-alpine

# Add requirements and install application
# Enable development php.ini config (Solve empty answer from token.php)
# Not apt-get on alpine ; not same library
RUN set -ex; \
    apk add --update --no-cache \
        libpq-dev \
        libldap2-dev \
        git \
        rsync \
    ; \
    rm -rf /var/cache/apk/*; \
    docker-php-ext-configure pgsql --with-pgsql=/usr/local/pgsql; \
    docker-php-ext-install pdo pdo_pgsql pgsql; \
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/; \
    docker-php-ext-install ldap; \
    ln -s /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini;

COPY ./entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["start", "php-fpm"]

# Arguments to label built container
ARG VCS_REF
ARG BUILD_DATE
ARG VERSION=master

# Get Mattermost-LDAP project
ADD https://github.com/crivaledaz/Mattermost-LDAP/archive/${VERSION}.tar.gz /tmp/${VERSION}.tar.gz

# Decompress the tar.gz to the right location.
# Keep track of image version
RUN set -ex; \
    mkdir -p /tmp/Mattermost-LDAP; \
    tar zxvf /tmp/${VERSION}.tar.gz -C /tmp/Mattermost-LDAP; \
    rm ${VERSION}.tar.gz; \
    mkdir -p /opt/Mattermost-LDAP; \
    cp -r "/tmp/Mattermost-LDAP/${VERSION}"/* /opt/Mattermost-LDAP; \
    rm -rf /tmp/Mattermost-LDAP; \
    echo "${VERSION} ${VCS_REF} ${BUILD_DATE}" > '/opt/Mattermost-LDAP/oauth/.docker-version';

# Container labels (http://label-schema.org/)
# Container annotations (https://github.com/opencontainers/image-spec)
LABEL maintainer="Monogramm maintainers <opensource at Monogramm dot io>" \
      product="Mattermost-LDAP" \
      version=$VERSION \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/Monogramm/docker-mattermost-ldap" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="Mattermost-LDAP" \
      org.label-schema.description="Custom image for mattermost-ldap." \
      org.label-schema.url="https://mattermost.com/" \
      org.label-schema.vendor="Mattermost" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0" \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.source="https://github.com/Monogramm/docker-mattermost-ldap" \
      org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.title="Mattermost-LDAP" \
      org.opencontainers.image.description="Custom image for mattermost-ldap." \
      org.opencontainers.image.url="https://mattermost.com/" \
      org.opencontainers.image.vendor="Mattermost" \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.authors="Monogramm maintainers <opensource at Monogramm dot io>"
