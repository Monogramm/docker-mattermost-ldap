FROM alpine
# If based on official images
# FROM __app_owner_slug__/__app_slug__:alpine

# Add requirements and install application
RUN set -ex; \
    echo '[TODO] ADD INSTALL OPERATIONS'

COPY ./entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--help"]

# Arguments to label built container
ARG VCS_REF
ARG BUILD_DATE
ARG VERSION=1.0.0

# Container labels (http://label-schema.org/)
# Container annotations (https://github.com/opencontainers/image-spec)
LABEL maintainer="Monogramm maintainers <opensource at monogramm dot io>" \
      product="__app_name__" \
      version=$VERSION \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/Monogramm/docker-__app_slug__" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="__app_name__" \
      org.label-schema.description="__app_description__" \
      org.label-schema.url="__app_url__" \
      org.label-schema.vendor="__app_vendor_name__" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0" \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.source="https://github.com/Monogramm/docker-__app_slug__" \
      org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.title="__app_name__" \
      org.opencontainers.image.description="__app_description__" \
      org.opencontainers.image.url="__app_url__" \
      org.opencontainers.image.vendor="__app_vendor_name__" \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.authors="Monogramm maintainers <opensource at monogramm dot io>"
