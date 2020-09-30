FROM mediagis/nominatim:3.3

ENV NOMINATIM_INIT_THREADS= \
    GEOFABRIK_DOWNLOAD_URL= \
    GEOFABRIK_REPLICATION_URL= \
    NOMINATIM_MAP_PATH=/data/nominatim.osm.pbf \
    NOMINATIM_DB_PATH=/data/postgres \
    NOMINATIM_DB_DRIVER=pgsql \
    NOMINATIM_DB_HOST=localhost \
    NOMINATIM_DB_PORT=5432 \
    NOMINATIM_DB_NAME= \
    NOMINATIM_DB_USER= \
    NOMINATIM_DB_PASSWD=

COPY ./entrypoint.sh /

# Add requirements and install application
RUN set -ex; \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["start"]

VOLUME /data

# Arguments to label built container
ARG VCS_REF
ARG BUILD_DATE
ARG VERSION=3.3

# Keep track of image version
RUN set -ex; \
    echo "${VERSION} ${VCS_REF} ${BUILD_DATE}" > '/app/src/.docker-version'; \
    echo "${NOMINATIM_VERSION}" > '/app/src/.app-version'

# Container labels (http://label-schema.org/)
# Container annotations (https://github.com/opencontainers/image-spec)
LABEL maintainer="Monogramm maintainers <opensource at monogramm dot io>" \
      product="Nominatim" \
      version=$VERSION \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/Monogramm/docker-nominatim" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="Nominatim" \
      org.label-schema.description="Open Source search based on OpenStreetMap data" \
      org.label-schema.url="https://nominatim.org/" \
      org.label-schema.vendor="osm-search" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0" \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.source="https://github.com/Monogramm/docker-nominatim" \
      org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.title="Nominatim" \
      org.opencontainers.image.description="Open Source search based on OpenStreetMap data" \
      org.opencontainers.image.url="https://nominatim.org/" \
      org.opencontainers.image.vendor="osm-search" \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.authors="Monogramm maintainers <opensource at monogramm dot io>"
