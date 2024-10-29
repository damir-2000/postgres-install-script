#!/bin/bash

echo "15 4 * * *    /usr/local/bin/wal-g backup-push /var/lib/postgresql/12/main >> /var/log/postgresql/walg_backup.log 2>&1" >>/var/spool/cron/crontabs/postgres
# задаем владельца и выставляем правильные права файлу
chown postgres: /var/spool/cron/crontabs/postgres
chmod 600 /var/spool/cron/crontabs/postgres

echo "30 6 * * *    /usr/local/bin/wal-g delete before FIND_FULL \$(date -d '-5 days' '+\\%FT\\%TZ') --confirm >> /var/log/postgresql/walg_delete.log 2>&1" >>/var/spool/cron/crontabs/postgres
# ещё раз задаем владельца и выставляем правильные права файлу (хоть это обычно это и не нужно повторно делать)
chown postgres: /var/spool/cron/crontabs/postgres
chmod 600 /var/spool/cron/crontabs/postgres
