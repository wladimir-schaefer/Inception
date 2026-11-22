#!/bin/sh
set -eu

root_password=$(cat /run/secrets/db_root_password)
db_password=$(cat /run/secrets/db_password)

if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql
fi

mariadbd --user=mysql --skip-networking &

until mariadb-admin ping --silent; do
    sleep 1
done

mariadb -u root <<SQL
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS 'wpuser'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'%';
SQL

mariadb --socket=/run/mysqld/mysqld.sock -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown

wait "$pid" || true

exec mariadbd --user=mysql