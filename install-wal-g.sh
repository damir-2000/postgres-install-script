#!/bin/bash
source ./.env

if [ -f "/usr/local/bin/wal-g" ]; then
    echo "Error wal-g already installed"
    exit
fi

curl -L "https://github.com/wal-g/wal-g/releases/download/v3.0.3/wal-g-pg-ubuntu-20.04-amd64.tar.gz" -o "wal-g.linux-amd64.tar.gz"

tar -xzf wal-g.linux-amd64.tar.gz

mv wal-g /usr/local/bin/

cat >/var/lib/postgresql/.walg.json <<EOF
{
    "WALG_S3_PREFIX": "$WALG_S3_PREFIX",
    "AWS_ACCESS_KEY_ID": "$AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY": "$AWS_SECRET_ACCESS_KEY",
    "AWS_S3_FORCE_PATH_STYLE": $AWS_S3_FORCE_PATH_STYLE,
    "WALG_COMPRESSION_METHOD": "brotli",
    "WALG_DELTA_MAX_STEPS": "$WALG_DELTA_MAX_STEPS",
    "WALG_LIBSODIUM_KEY_TRANSFORM": "$WALG_LIBSODIUM_KEY_TRANSFORM",
    "WALG_LIBSODIUM_KEY": "$WALG_LIBSODIUM_KEY",
    "PGDATA": "/var/lib/postgresql/$VERSION/main",
    "PGHOST": "/var/run/postgresql/.s.PGSQL.5432"
}
EOF
# обязательно меняем владельца файла:
chown postgres: /var/lib/postgresql/.walg.json

echo "wal_level=replica" >>/etc/postgresql/$VERSION/main/postgresql.conf
echo "archive_mode=on" >>/etc/postgresql/$VERSION/main/postgresql.conf
echo "archive_command='/usr/local/bin/wal-g wal-push \"%p\" >> /var/log/postgresql/archive_command.log 2>&1' " >>/etc/postgresql/$VERSION/main/postgresql.conf
echo “archive_timeout=60” >>/etc/postgresql/$VERSION/main/postgresql.conf
echo "restore_command='/usr/local/bin/wal-g wal-fetch \"%f\" \"%p\" >> /var/log/postgresql/restore_command.log 2>&1' " >>/etc/postgresql/$VERSION/main/postgresql.conf