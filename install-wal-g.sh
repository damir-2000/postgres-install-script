#!/bin/bash
source ./.env

if [ -f "/usr/local/bin/wal-g" ]; then
    echo "Error wal-g already installed"
    exit
fi

curl -L "https://github.com/wal-g/wal-g/releases/download/v3.0.3/wal-g-pg-ubuntu-20.04-amd64.tar.gz" -o "wal-g.linux-amd64.tar.gz"

tar -xzf wal-g.linux-amd64.tar.gz

mv wal-g /usr/local/bin/


cat > /var/lib/postgresql/.walg.json << EOF
{
    "WALG_S3_PREFIX": "s3://your_bucket/path",
    "AWS_ACCESS_KEY_ID": "key_id",
    "AWS_SECRET_ACCESS_KEY": "secret_key",
    "WALG_COMPRESSION_METHOD": "brotli",
    "WALG_DELTA_MAX_STEPS": "5",
    "PGDATA": "/var/lib/postgresql/12/main",
    "PGHOST": "/var/run/postgresql/.s.PGSQL.5432"
}
EOF
# обязательно меняем владельца файла:
chown postgres: /var/lib/postgresql/.walg.json


echo "wal_level=replica" >> /etc/postgresql/12/main/postgresql.conf
echo "archive_mode=on" >> /etc/postgresql/12/main/postgresql.conf
echo "archive_command='/usr/local/bin/wal-g wal-push \"%p\" >> /var/log/postgresql/archive_command.log 2>&1' " >> /etc/postgresql/12/main/postgresql.conf
echo “archive_timeout=60” >> /etc/postgresql/12/main/postgresql.conf
echo "restore_command='/usr/local/bin/wal-g wal-fetch \"%f\" \"%p\" >> /var/log/postgresql/restore_command.log 2>&1' " >> /etc/postgresql/12/main/postgresql.conf
