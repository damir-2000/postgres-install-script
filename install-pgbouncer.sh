#!/bin/bash
source ./.env

declare -r PGV=$(apt-cache policy postgresql-$VERSION | grep -e Installed: | cut -d' ' -f4)
if [[ -z "$PGV" ]] || [[ $PGV == "(none)" ]]; then
    echo "Error Postgres did not install"
    exit
fi

apt -y install pgbouncer

cp ./pgbouncer.ini /etc/pgbouncer/pgbouncer.ini
touch /etc/pgbouncer/userlist.txt

systemctl enable --now pgbouncer