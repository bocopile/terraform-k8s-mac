#!/bin/bash
set -e
LOGFILE="/home/ubuntu/mysql-install.log"
exec > >(tee -a $LOGFILE) 2>&1

echo "[MYSQL] Waiting for MySQL installation to complete..."

# Wait for MySQL to be installed and running (up to 5 minutes)
TIMEOUT=300
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if command -v mysql >/dev/null 2>&1 && sudo systemctl is-active --quiet mysql; then
        echo "[MYSQL] MySQL is installed and running."
        break
    fi
    echo "[MYSQL] Waiting for MySQL... ($ELAPSED/$TIMEOUT seconds)"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "[MYSQL] ERROR: MySQL installation timed out after $TIMEOUT seconds"
    exit 1
fi

# Additional wait to ensure MySQL is fully ready to accept connections
sleep 10

echo "[MYSQL] Securing MySQL installation..."

# Set root password and create database/user
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$1'; FLUSH PRIVILEGES;"
sudo mysql -uroot -p$1 -e "CREATE DATABASE IF NOT EXISTS $2;"
sudo mysql -uroot -p$1 -e "CREATE USER IF NOT EXISTS '$3'@'%' IDENTIFIED WITH mysql_native_password BY '$4';"
sudo mysql -uroot -p$1 -e "GRANT ALL PRIVILEGES ON $2.* TO '$3'@'%'; FLUSH PRIVILEGES;"

echo "[MYSQL] MySQL root password, user, and database configured."