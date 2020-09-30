[![License: AGPL v3][uri_license_image]][uri_license]
[![Docs](https://img.shields.io/badge/Docs-Github%20Pages-blue)](https://monogramm.github.io/docker-nominatim/)
[![Build Status](https://travis-ci.org/Monogramm/docker-nominatim.svg)](https://travis-ci.org/Monogramm/docker-nominatim)
[![Docker Automated buid](https://img.shields.io/docker/cloud/build/monogramm/docker-nominatim.svg)](https://hub.docker.com/r/monogramm/docker-nominatim/)
[![Docker Pulls](https://img.shields.io/docker/pulls/monogramm/docker-nominatim.svg)](https://hub.docker.com/r/monogramm/docker-nominatim/)
[![Docker Version](https://images.microbadger.com/badges/version/monogramm/docker-nominatim.svg)](https://microbadger.com/images/monogramm/docker-nominatim)
[![Docker Size](https://images.microbadger.com/badges/image/monogramm/docker-nominatim.svg)](https://microbadger.com/images/monogramm/docker-nominatim)
[![GitHub stars](https://img.shields.io/github/stars/Monogramm/docker-nominatim?style=social)](https://github.com/Monogramm/docker-nominatim)

# **Nominatim** Docker image

Docker image for **Nominatim**.

:construction: **This image is still in development!**

## What is **Nominatim**

Open Source search based on OpenStreetMap data

> [**Nominatim**](https://nominatim.org/)

## Supported tags

[Dockerhub monogramm/docker-nominatim](https://hub.docker.com/r/monogramm/docker-nominatim/)

-   `3.5` `latest`
-   `3.4`
-   `3.3`
-   `3.2`
-   `3.1`
-   `3.0`
-   `2.5`

## How to run this image

This image provides an NOMINATIM Manager in the form of the Docker entrypoint.
It manages map downloads from Geofabrik and NOMINATIM extraction/pre-processing/routing based on environment variables.

```shell
# Number of threads used during Nominatim DB init (leave empty to use all CPU)
NOMINATIM_INIT_THREADS=2

## Geofabrik URL to download map
GEOFABRIK_DOWNLOAD_URL=http://download.geofabrik.de/europe/monaco-latest.osm.pbf

## Geofabrik URL to update map
GEOFABRIK_REPLICATION_URL=http://download.geofabrik.de/europe/monaco-updates

## Geofabrik map relative file path
NOMINATIM_MAP_NAME=monaco-latest.osm.pbf

## Nominatim Postgres relative directory
NOMINATIM_DB_PATH=monaco-latest-postgres

```

See **Nominatim** base image documentation for details.

> [**Nominatim Docker** GitHub](https://github.com/mediagis/nominatim-docker)

> [**Nominatim** DockerHub](https://hub.docker.com/r/mediagis/nominatim/)

See **Nominatim** documentation for details.

> [**Nominatim** GitHub](https://github.com/osm-search/Nominatim)

> [**Nominatim** WebSite](https://nominatim.org/)

## Questions / Issues

If you got any questions or problems using the image, please visit our [Github Repository](https://github.com/Monogramm/docker-nominatim) and write an issue.


[uri_license]: http://www.gnu.org/licenses/agpl.html

[uri_license_image]: https://img.shields.io/badge/License-AGPL%20v3-blue.svg
