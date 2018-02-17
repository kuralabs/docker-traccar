#!/usr/bin/env bash

set -o errexit
set -o nounset

sudo mkdir -p /srv/traccar/mysql
sudo mkdir -p /srv/traccar/logs
sudo mkdir -p /srv/traccar/config

docker stop traccar || true
docker rm traccar || true

docker run --interactive --tty \
    --hostname traccar \
    --name traccar \
    --volume /srv/traccar/mysql:/var/lib/mysql \
    --volume /srv/traccar/logs:/var/log \
    --volume /srv/traccar/config:/opt/traccar/conf \
    --publish 8082:8082 \
    --env MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
    --env TZ=America/Costa_Rica \
    --volume /etc/timezone:/etc/timezone:ro \
    --volume /etc/localtime:/etc/localtime:ro \
    kuralabs/docker-traccar:latest bash
