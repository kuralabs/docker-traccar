# Traccar Docker Container

## About

Traccar is open source server for various GPS tracking devices.

- https://www.traccar.org/

This repository holds the source of the all-in-one Traccar Docker image
available at:

- https://hub.docker.com/r/kuralabs/docker-traccar/


## Usage

Adapt the following script to your needs:

```bash
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
    --env MYSQL_ROOT_PASSWORD="[YOUR_AWESOME_MYSQL_ROOT_PASSWORD]" \
    kuralabs/docker-traccar:latest
```

If you need to set the container to the same time zone as your host machine you
may use the following options:

```
    --env TZ=America/New_York \
    --volume /etc/timezone:/etc/timezone:ro \
    --volume /etc/localtime:/etc/localtime:ro \
```

You may use the following website to find your time zone:

- http://timezonedb.com/

Finally, open `http://localhost:8082/` (or corresponding URL) in your browser
and register a first user.


## Development

Build me with:

```
docker build --tag kuralabs/docker-traccar:latest .
```

In development, run me with:

```
MYSQL_ROOT_PASSWORD=[MYSQL SECURE ROOT PASSWORD] ./run/traccar-dev.sh
```


## License

```
Copyright (C) 2017-2018 KuraLabs S.R.L

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
```
