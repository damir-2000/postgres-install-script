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

# останавливаем саму базу данных
service postgresql stop
# удаляем все данные из текущей базы (!!!); лучше предварительно сделать их копию, если есть свободное место на диске
rm -rf /var/lib/postgresql/$VERSION/main
# скачиваем резервную копию и разархивируем её
su - postgres -c '/usr/local/bin/wal-g backup-fetch /var/lib/postgresql/$VERSION/main LATEST'
# помещаем рядом с базой специальный файл-сигнал для восстановления (см. https://postgrespro.ru/docs/postgresql/12/runtime-config-wal#RUNTIME-CONFIG-WAL-ARCHIVE-RECOVERY ), он обязательно должен быть создан от пользователя postgres
su - postgres -c 'touch /var/lib/postgresql/$VERSION/main/recovery.signal'
# запускаем базу данных, чтобы она инициировала процесс восстановления
service postgresql start