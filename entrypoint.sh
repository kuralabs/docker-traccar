#!/usr/bin/env bash

set -o errexit
set -o nounset

##################
# Setup          #
##################

MYSQL_ROOT_PASSWORD_SET=${MYSQL_ROOT_PASSWORD:-}

if [ -z "${MYSQL_ROOT_PASSWORD_SET}" ]; then
    echo "Please set the MySQL root password:"
    echo "    docker run -e MYSQL_ROOT_PASSWORD=<mysecret> ... kuralabs/docker-traccar:latest ..."
    echo "See README.rst for more information on usage."
    exit 1
fi

# Logging
for i in mysql,mysql supervisor,root; do

    IFS=',' read directory owner <<< "${i}"

    if [ ! -d "/var/log/${directory}" ]; then
        echo "Setting up /var/log/${directory} ..."
        mkdir -p "/var/log/${directory}"
        chown "${owner}:adm" "/var/log/${directory}"
    else
        echo "Directory /var/log/${directory} already setup ..."
    fi
done

# Copy configuration files if new mount
if find /opt/traccar/conf -mindepth 1 | read; then
   echo "Configuration is mounted. Skipping copy ..."
else
   echo "First configuration. Copying config files ..."
   cp -R /opt/traccar/conf.package/* /opt/traccar/conf
   chown -R traccar:traccar /opt/traccar/conf
fi

##################
# Waits          #
##################

function wait_for_mysql {

    echo -n "Waiting for MySQL "
    for i in {10..0}; do
        if mysqladmin ping > /dev/null 2>&1; then
            break
        fi
        echo -n "."
        sleep 1
    done
    echo ""

    if [ "$i" == 0 ]; then
        echo >&2 "FATAL: MySQL failed to start"
        echo "Showing content of /var/log/mysql/error.log ..."
        cat /var/log/mysql/error.log || true
        exit 1
    fi
}

##################
# Initialization #
##################

# MySQL boot

# Workaround for issue #72 that makes MySQL to fail to
# start when using docker's overlay2 storage driver:
#   https://github.com/docker/for-linux/issues/72
find /var/lib/mysql -type f -exec touch {} \;

# Initialize /var/lib/mysql if empty (first --volume mount)
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Empty /var/lib/mysql/ directory. Initializing MySQL structure ..."

    echo "MySQL user has uid $(id -u mysql). Changing /var/lib/mysql ownership ..."
    chown -R mysql:mysql /var/lib/mysql

    echo "Initializing MySQL ..."
    echo "UPDATE mysql.user
        SET authentication_string = PASSWORD('${MYSQL_DEFAULT_PASSWORD}'), password_expired = 'N'
        WHERE User = 'root' AND Host = 'localhost';
        FLUSH PRIVILEGES;" > /tmp/mysql-init.sql

    /usr/sbin/mysqld \
        --initialize-insecure \
        --init-file=/tmp/mysql-init.sql || cat /var/log/mysql/error.log

    rm /tmp/mysql-init.sql
fi

##################
# Supervisord    #
##################

echo "Starting supervisord ..."
# Note: stdout and stderr are redirected to /dev/null as logs are already being
#       saved in /var/log/supervisor/supervisord.log
supervisord --nodaemon -c /etc/supervisor/supervisord.conf > /dev/null 2>&1 &

# Wait for MySQL to start
wait_for_mysql

##################
# MySQL          #
##################

# Check if password was changed
echo "\
[client]
user=root
password=${MYSQL_DEFAULT_PASSWORD}
" > ~/.my.cnf

if echo "SELECT 1;" | mysql &> /dev/null; then

    echo "Securing MySQL installation ..."
    mysql_secure_installation --use-default

    echo "Changing root password ..."
    echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
          FLUSH PRIVILEGES;" | mysql
else
    echo "Root password already set. Continue ..."
fi

# Start using secure credentials
echo "\
[client]
user=root
password=${MYSQL_ROOT_PASSWORD}
" > ~/.my.cnf

# Create database
if ! echo "USE traccar;" | mysql &> /dev/null; then
    echo "Creating traccar database ..."
    echo "CREATE DATABASE traccar;" | mysql
else
    echo "Database already exists. Continue ..."
fi

##################
# Traccar        #
##################

if echo "SELECT COUNT(DISTINCT table_name) FROM information_schema.columns WHERE table_schema = 'traccar';" | mysql | grep 0 &> /dev/null; then

    echo "Database is empty, installing Traccar for the first time ..."

    # Create standard user and grant permissions
    MYSQL_USER_PASSWORD=$(openssl rand -base64 32)

    if ! echo "SELECT COUNT(*) FROM mysql.user WHERE user = 'traccar';" | mysql | grep 1 &> /dev/null; then

        echo "Creating traccar database user ..."

        echo "CREATE USER 'traccar'@'localhost' IDENTIFIED BY '${MYSQL_USER_PASSWORD}';
              GRANT ALL PRIVILEGES ON traccar.* TO 'traccar'@'localhost';
              FLUSH PRIVILEGES;" | mysql
    else
        echo "Traccar not installed but user was created. Resetting password ..."

        echo "ALTER USER 'traccar'@'localhost' IDENTIFIED BY '${MYSQL_USER_PASSWORD}';
              FLUSH PRIVILEGES;" | mysql
    fi

    GREEN='\033[0;32m'
    NO_COLOR='\033[0m'

    echo -e "${GREEN}"
    echo "*****************************************************************"
    echo ""
    echo "The following parameters will be set in your traccar.xml:"
    echo ""
    echo "    <entry key='database.driver'>com.mysql.jdbc.Driver</entry>"
    echo "    <entry key='database.url'>jdbc:mysql://localhost:3306/traccar?useSSL=false&amp;allowMultiQueries=true&amp;autoReconnect=true&amp;useUnicode=yes&amp;characterEncoding=UTF-8&amp;sessionVariables=sql_mode=''</entry>"
    echo "    <entry key='database.user'>traccar</entry>"
    echo "    <entry key='database.password'>${MYSQL_USER_PASSWORD}</entry>"
    echo ""
    echo "*****************************************************************"
    echo -e "${NO_COLOR}"

    xmlstarlet edit --ps --inplace \
        -u '/properties/entry[@key="database.driver"]' -v "com.mysql.jdbc.Driver" \
        -u '/properties/entry[@key="database.url"]' -v "jdbc:mysql://localhost:3306/traccar?useSSL=false&allowMultiQueries=true&autoReconnect=true&useUnicode=yes&characterEncoding=UTF-8&sessionVariables=sql_mode=''" \
        -u '/properties/entry[@key="database.user"]' -v "traccar" \
        -u '/properties/entry[@key="database.password"]' -v "${MYSQL_USER_PASSWORD}" \
        /opt/traccar/conf/traccar.xml

else
    echo "Traccar already installed. Continue ..."
fi

supervisorctl start traccar

# FIXME! Wait for traccar up!

##################
# Finish         #
##################

# Display final status
supervisorctl status

# Security clearing
rm ~/.my.cnf

unset MYSQL_DEFAULT_PASSWORD
unset MYSQL_ROOT_PASSWORD
unset MYSQL_USER_PASSWORD

history -c
history -w

if [ -z "$@" ]; then
    echo "Done booting up. Waiting on supervisord pid $(supervisorctl pid) ..."
    wait $(supervisorctl pid)
else
    echo "Running user command : $@"
    exec "$@"
fi
