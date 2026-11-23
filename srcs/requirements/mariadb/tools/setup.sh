#!/bin/sh
set -eu

root_password=$(cat /run/secrets/db_root_password)
db_password=$(cat /run/secrets/db_password)
db_name="$MYSQL_DATABASE"
db_user="$MYSQL_USER"

mkdir -p /run/mysqld /var/lib/mysql
chown -R mysql:mysql /run/mysqld /var/lib/mysql

if [ ! -d /var/lib/mysql/mysql ]; then

    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql \
        --auth-root-authentication-method=normal

    # Start MariaDB temporarily
    mariadbd --user=mysql --skip-networking &
    pid=$!

    # Wait until MariaDB is ready
    count=0
    until mariadb-admin ping --silent; do
        count=$((count + 1))

        if [ "$count" -ge 30 ]; then
            echo "MariaDB failed to start"
            exit 1
        fi

        sleep 1
    done

    # Escape password quotes for SQL
    escaped_db_password=$(printf '%s' "$db_password" | sed "s/'/''/g")
    escaped_root_password=$(printf '%s' "$root_password" | sed "s/'/''/g")

    # Create database and users
    mariadb -u root <<SQL
SET SESSION sql_mode = 'NO_BACKSLASH_ESCAPES';
CREATE DATABASE IF NOT EXISTS \`$db_name\`;
CREATE USER IF NOT EXISTS '$db_user'@'%' IDENTIFIED BY '${escaped_db_password}';
GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$db_user'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${escaped_root_password}';
DROP USER IF EXISTS ''@'localhost';
SQL

    # Stop temporary server
    mariadb-admin -u root -p"$root_password" shutdown
    wait "$pid"
fi

# Start MariaDB normally
exec mariadbd --user=mysql