FROM ubuntu:focal AS build

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    POSTGRES_VERSION=12 \
    POSTGIS_VERSION=3 \
    NOMINATIM_VERSION=v3.4.2 \
    NOMINATIM_INIT_THREADS= \
    GEOFABRIK_DOWNLOAD_URL= \
    GEOFABRIK_REPLICATION_URL= \
    NOMINATIM_MAP_NAME= \
    NOMINATIM_DB_PATH= \
    NOMINATIM_DB_DRIVER=pgsql \
    NOMINATIM_DB_HOST=localhost \
    NOMINATIM_DB_PORT=5432 \
    NOMINATIM_DB_NAME=nominatim \
    NOMINATIM_DB_USER=nominatim \
    NOMINATIM_DB_PASSWD=password1234

# Do not start daemons after installation.
# Add requirements
# Configure postgres
# Osmium install to run continuous updates
# Nominatim install
# Remove development and unused packages
# Clear temporary files and directories
RUN set -ex; \
    echo '#!/bin/sh\nexit 101' > /usr/sbin/policy-rc.d; \
    chmod +x /usr/sbin/policy-rc.d; \
    apt-get update -y -qq; \
    apt-get install -y --allow-unauthenticated \
        locales \
    ; \
    locale-gen en_US.UTF-8; \
    update-locale LANG=en_US.UTF-8; \
    apt-get install -o APT::Install-Recommends="false" -o APT::Install-Suggests="false" -y --allow-unauthenticated \
        build-essential \
        cmake \
        g++ \
        libboost-dev \
        libboost-system-dev \
        libboost-filesystem-dev \
        libexpat1-dev \
        zlib1g-dev \
        libxml2-dev \
        libbz2-dev \
        libpq-dev \
        libproj-dev \
        "postgresql-server-dev-${POSTGRES_VERSION}" \
        "postgresql-${POSTGRES_VERSION}-postgis-${POSTGIS_VERSION}" \
        postgresql-contrib \
        "postgresql-${POSTGRES_VERSION}-postgis-${POSTGIS_VERSION}-scripts" \
        apache2 \
        php \
        php-pgsql \
        libapache2-mod-php \
        php-intl \
        python3-setuptools \
        python3-dev \
        python3-pip \
        python3-psycopg2 \
        python3-tidylib \
        git \
        curl \
        sudo \
        netcat \
    ; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf \
        /tmp/* \
        /var/tmp/* \
    ; \
    echo "host all  all    0.0.0.0/0  trust" >> "/etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf"; \
    echo "listen_addresses='*'" >> "/etc/postgresql/${POSTGRES_VERSION}/main/postgresql.conf"; \
    pip3 install osmium; \
    git clone \
        --config advice.detachedHead=false \
        --single-branch \
        --branch $NOMINATIM_VERSION \
        --depth 1 \
        --recursive \
        https://github.com/openstreetmap/Nominatim \
        /app/src\
    ; \
    cd /app/src; \
    git checkout "tags/$NOMINATIM_VERSION"; \
    git submodule update --recursive --init; \
    mkdir build; \
    cd build; \
    cmake ..; \
    make -j`nproc`; \
    chmod o=rwx .; \
    apt-get -y remove --purge --allow-remove-essential \
        cpp-9 \
        gcc-9* \
        g++ \
        git \
        make \
        cmake \
        llvm-10* \
        libc6-dev \
        linux-libc-dev \
        libclang-*-dev \
        build-essential \
        "postgresql-server-dev-${POSTGRES_VERSION}" \
    ; \
    apt-get clean; \
    rm -rf \
        /tmp/* \
        /var/tmp/* \
        /root/.cache \
        /app/src/.git \
        /var/lib/apt/lists/* \
        "/var/lib/postgresql/${POSTGRES_VERSION}/main"/*

# Apache configure
COPY local.php /app/src/build/settings/local.php
COPY nominatim-apache.conf /etc/apache2/sites-enabled/000-default.conf

# Load initial data
ARG with_postcodes_gb
ARG with_postcodes_us
RUN set -ex; \
    if [ "$with_postcodes_gb" = "" ]; then \
        echo "Skipping optional GB postcode file"; \
    else \
        echo "Downloading optional GB postcode file"; \
        curl http://www.nominatim.org/data/gb_postcode_data.sql.gz > /app/src/data/gb_postcode_data.sql.gz; \
    fi; \
    if [ "$with_postcodes_us" = "" ]; then \
        echo "Skipping optional US postcode file"; \
    else \
        echo "Downloading optional US postcode file"; \
        curl http://www.nominatim.org/data/us_postcode_data.sql.gz > /app/src/data/us_postcode_data.sql.gz; \
    fi; \
    curl http://www.nominatim.org/data/country_grid.sql.gz > /app/src/data/country_osm_grid.sql.gz; \
    sed -i \
        -e "s|@define('CONST_Postgresql_Version', '.*');|@define('CONST_Postgresql_Version', '${POSTGRES_VERSION}');|g" \
        -e "s|@define('CONST_Postgis_Version', '.*');|@define('CONST_Postgis_Version', '${POSTGIS_VERSION}');//|g" \
        /app/src/build/settings/local.php

COPY entrypoint.sh start.sh startapache.sh startpostgres.sh init.sh /app/

# Update entrypoint permissions
RUN set -ex; \
    chmod +x \
        /app/entrypoint.sh \
        /app/start.sh \
        /app/startapache.sh \
        /app/startpostgres.sh \
        /app/init.sh \
    ;

# Keep track of image version
RUN set -ex; \
    echo "${NOMINATIM_VERSION} ${VCS_REF} ${BUILD_DATE}" > '/app/src/.docker-version'; \
    echo "${NOMINATIM_VERSION}" > '/app/src/.app-version'

# Collapse image to single layer.
FROM scratch

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["start"]

VOLUME [ "/data" ]

WORKDIR /app

EXPOSE 5432
EXPOSE 8080

# Arguments to label built container
ARG VCS_REF
ARG BUILD_DATE

# Container labels (http://label-schema.org/)
# Container annotations (https://github.com/opencontainers/image-spec)
LABEL maintainer="Monogramm maintainers <opensource at monogramm dot io>" \
      product="Nominatim" \
      version=$NOMINATIM_VERSION \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/Monogramm/docker-nominatim" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="Nominatim" \
      org.label-schema.description="Open Source search based on OpenStreetMap data" \
      org.label-schema.url="https://nominatim.org/" \
      org.label-schema.vendor="osm-search" \
      org.label-schema.version=$NOMINATIM_VERSION \
      org.label-schema.schema-version="1.0" \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.source="https://github.com/Monogramm/docker-nominatim" \
      org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.title="Nominatim" \
      org.opencontainers.image.description="Open Source search based on OpenStreetMap data" \
      org.opencontainers.image.url="https://nominatim.org/" \
      org.opencontainers.image.vendor="osm-search" \
      org.opencontainers.image.version=$NOMINATIM_VERSION \
      org.opencontainers.image.authors="Monogramm maintainers <opensource at monogramm dot io>"

COPY --from=build / /
