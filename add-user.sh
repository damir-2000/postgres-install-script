#!/usr/bin/env bash
#
# Скрипт: create_db_user_su_args_pgbouncer.sh
# Описание: создаёт базу данных и пользователя в PostgreSQL через su - postgres -c "psql -c '...'"
#           с передачей имени БД, имени пользователя и пароля через аргументы.
#           После создания добавляет запись с именем пользователя и его SCRAM-паролем в /etc/pgbouncer/userlist.txt.
#
# Как использовать:
#   chmod +x create_db_user_su_args_pgbouncer.sh
#   sudo ./create_db_user_su_args_pgbouncer.sh <имя_бд> <имя_пользователя> <пароль>
#
# Примечание: скрипт должен быть запущен от root или через sudo, чтобы su - postgres
#             работал без запроса пароля и чтобы была возможность править /etc/pgbouncer/userlist.txt.

# Проверяем, что передано ровно 3 аргумента
if [[ $# -ne 3 ]]; then
    echo "Использование: $0 <имя_бд> <имя_пользователя> <пароль>"
    exit 1
fi

DB_NAME="$1"
DB_USER="$2"
DB_PASS="$3"
PGB_USERLIST="/etc/pgbouncer/userlist.txt"

# Проверяем, что скрипт запущен от root (или через sudo)
if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: запустите скрипт от имени root или через sudo"
    exit 1
fi

# Проверяем, что psql доступен в PATH
if ! command -v psql >/dev/null 2>&1; then
    echo "Ошибка: не найден psql (установите PostgreSQL client)"
    exit 1
fi

echo "Создаём базу \"$DB_NAME\" и пользователя \"$DB_USER\"..."

# 1) Создание базы данных
su - postgres -c "psql -c \"CREATE DATABASE $DB_NAME;\"" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "Ошибка: не удалось создать базу данных \"$DB_NAME\""
    exit 1
fi

# 2) Создание пользователя
su - postgres -c "psql -c \"CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';\"" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "Ошибка: не удалось создать пользователя \"$DB_USER\""
    exit 1
fi

# 3) Выдача всех привилегий на базу
su - postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;\"" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "Ошибка: не удалось выдать привилегии пользователю \"$DB_USER\" на базу \"$DB_NAME\""
    exit 1
fi

# 4) Получаем SCRAM-пароль (rolpassword) для нового пользователя и добавляем в /etc/pgbouncer/userlist.txt
#    Формат записи: "username" "SCRAM-SHA-256$..."
PGB_LINE=""
ROLPASS_HASH=$(su - postgres -c "psql -At -c \"SELECT rolpassword FROM pg_authid WHERE rolname = '$DB_USER';\"")
if [[ -z "$ROLPASS_HASH" ]]; then
    echo "Предупреждение: не удалось получить SCRAM-хэш для пользователя \"$DB_USER\". Проверьте, что ролевой пароль действительно задан."
else
    PGB_LINE="\"$DB_USER\" \"$ROLPASS_HASH\""
    # Убедимся, что userlist.txt существует; если нет — создаём и задаём правильные права
    if [[ ! -f "$PGB_USERLIST" ]]; then
        touch "$PGB_USERLIST"
        chown postgres:postgres "$PGB_USERLIST"
        chmod 640 "$PGB_USERLIST"
    fi
    # Проверим, нет ли уже записи для этого имени пользователя
    if grep -q "^\"$DB_USER\" " "$PGB_USERLIST"; then
        echo "Запись для пользователя \"$DB_USER\" уже есть в $PGB_USERLIST. Заменяем её."
        # Заменяем существующую строку:
        sed -i "s/^\"$DB_USER\" \".*\"$/$PGB_LINE/" "$PGB_USERLIST"
    else
        # Добавляем новую строку
        echo "$PGB_LINE" >>"$PGB_USERLIST"
    fi
    echo "Пользователь \"$DB_USER\" добавлен в $PGB_USERLIST."
fi

echo "Готово! Пользователь \"$DB_USER\" успешно создан с паролем \"$DB_PASS\" и добавлен в pgbouncer."
exit 0
