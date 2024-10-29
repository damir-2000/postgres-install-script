#!/bin/bash
source ./.env

touch /var/spool/cron/crontabs/postgres

cat > /var/spool/cron/crontabs/postgres << EOF
15 4 * * *    /usr/local/bin/wal-g backup-push /var/lib/postgresql/$VERSION/main >> /var/log/postgresql/walg_backup.log 2>&1
30 6 * * *    /usr/local/bin/wal-g delete before FIND_FULL \$(date -d '-5 days' '+\\%FT\\%TZ') --confirm >> /var/log/postgresql/walg_delete.log 2>&1
EOF

chown postgres: /var/spool/cron/crontabs/postgres
chmod 600 /var/spool/cron/crontabs/postgres