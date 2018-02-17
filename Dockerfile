FROM ubuntu:16.04
LABEL mantainer="info@kuralabs.io"


# Setup and install base system software
USER root
ENV DEBIAN_FRONTEND noninteractive

RUN echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections \
    && echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections \
    && apt-get update \
    && apt-get --yes --no-install-recommends install \
        locales tzdata sudo \
        ca-certificates apt-transport-https software-properties-common \
        bash-completion iproute2 curl unzip nano tree xmlstarlet \
    && rm -rf /var/lib/apt/lists/*
ENV LANG en_US.UTF-8


# Install supervisord
RUN apt-get update \
    && apt-get --yes --no-install-recommends install \
        supervisor dirmngr \
    && rm -rf /var/lib/apt/lists/*


# Install MySQL
ENV MYSQL_DEFAULT_PASSWORD 4vgZT6vgXcr61bXubYm2zxrpj0LGBJYrzi05H2+ROJo=

RUN echo "mysql-server-5.7 mysql-server/root_password_again password ${MYSQL_DEFAULT_PASSWORD}" | debconf-set-selections \
    && echo "mysql-server-5.7 mysql-server/root_password password ${MYSQL_DEFAULT_PASSWORD}" | debconf-set-selections \
    && apt-get update && apt-get install --yes \
        mysql-server-5.7 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/lib/mysql /var/run/mysqld /var/mysqld/ \
    && chown mysql:mysql /var/lib/mysql /var/run/mysqld /var/mysqld/


# Install Java stack
RUN apt-get update \
    && apt-get --yes --no-install-recommends install \
        openjdk-8-jdk-headless \
    && rm -rf /var/lib/apt/lists/*


# Create system user
RUN adduser \
        --system \
        --home /opt/traccar \
        --disabled-password \
        --group \
        traccar
WORKDIR /opt/traccar


# Install Traccar
ENV TRACCAR_VERSION 3.15

RUN curl --location --output /tmp/traccar.zip https://github.com/tananaev/traccar/releases/download/v${TRACCAR_VERSION}/traccar-other-${TRACCAR_VERSION}.zip \
    && unzip /tmp/traccar.zip -d /opt/traccar \
    && rm /tmp/traccar.zip \
    && chown -R traccar:traccar /opt/traccar \
    && cp -R /opt/traccar/conf /opt/traccar/conf.package


# Install files
COPY supervisord/*.conf /etc/supervisor/conf.d/


# Start supervisord
EXPOSE 8082/TCP

COPY entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
