#!/bin/bash
source ./.env

declare -r PGV=$(apt-cache policy postgresql-$VERSION | grep -e Installed: | cut -d' ' -f4)
if [[ -z "$PGV" ]] || [[ $PGV == "(none)" ]]; then
    echo "Error Postgres did not install"
    exit
fi

# Create the repository configuration file:
apt -y install gpg

sh -c 'echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/timescaledb.list'

wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg

# Update the package lists:
apt update

# Install the latest version of PostgreSQL:
# If you want a specific version, use 'postgresql-16' or similar instead of 'postgresql'
apt -y install timescaledb-2-postgresql-$VERSION

timescaledb-tune -y

sudo systemctl restart postgresql

su - postgres -c "psql -c 'CREATE EXTENSION IF NOT EXISTS timescaledb'"
