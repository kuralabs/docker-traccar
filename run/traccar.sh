#!/usr/bin/env bash

set -o errexit
set -o nounset

# Create mount points
sudo mkdir -p /srv/traccar/mysql
sudo mkdir -p /srv/traccar/logs
sudo mkdir -p /srv/traccar/config

# Stop the running container
docker stop traccar || true

# Remove existing container
docker rm traccar || true

# Pull the new image
docker pull kuralabs/docker-traccar:latest

# Run the container
docker run --detach --init \
    --hostname traccar \
    --name traccar \
    --restart always \
    --publish 8082:8082 \
    --volume /srv/traccar/mysql:/var/lib/mysql \
    --volume /srv/traccar/logs:/var/log \
    --volume /srv/traccar/config:/opt/traccar/conf \
    --env MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
    --env TZ=America/Costa_Rica \
    --volume /etc/timezone:/etc/timezone:ro \
    --volume /etc/localtime:/etc/localtime:ro \
    kuralabs/docker-traccar:latest
