#!/bin/bash
source ./.env

if ! [[ $(apt-cache policy postgresql-$VERSION | grep -e Installed: | cut -d' ' -f4) == "(none)" ]]; then
    echo "Error Postgres did not install"
    exit
fi

if ! [ -f "/usr/local/bin/wal-g" ]; then
    echo "Error wal-g did not install"
    exit
fi

su - postgres -c '/usr/local/bin/wal-g backup-push /var/lib/postgresql/$VERSION/main'
