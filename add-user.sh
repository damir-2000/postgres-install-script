#!/usr/bin/env bash
#
# Скрипт: create_db_user_full.sh
# Описание:
#   1) создаёт базу данных и пользователя в PostgreSQL через `su - postgres -c "psql -c '...'"`;
#   2) выдаёт все привилегии на базу;
#   3) выдаёт права на работу с схемой public;
#   4) **необязательный 4-й параметр**: если указан (любой непустой), выполняется
#      `CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;` в созданной базе;
#   5) добавляет запись с SCRAM-хешем пользователя в /etc/pgbouncer/userlist.txt;
#   6) перезапускает службу pgbouncer.
#
# Использование:
#   chmod +x create_db_user_full.sh
#   sudo ./create_db_user_full.sh <имя_бд> <имя_пользователя> <пароль> [enable_timescaledb]
#
#   Где:
#     <имя_бд>         – имя создаваемой базы
#     <имя_пользователя> – имя создаваемой роли
#     <пароль>         – пароль для этой роли
#     [enable_timescaledb] – необязательный 4-й параметр. Любое непустое значение
#                            (например, "timescaledb" или "1") приведёт к тому,
#                            что после выдачи прав на схему будет выполнена
#                            команда `CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;`.
#
# Примечание:
#   • Скрипт должен выполняться от root (или через sudo), чтобы `su - postgres`
#     работал без пароля, а также чтобы была возможность править /etc/pgbouncer/userlist.txt
#     и перезапускать pgbouncer.
#   • Если вы не хотите устанавливать TimescaleDB, просто не указывайте 4-й параметр.
#

if [[ $# -lt 3 ]] || [[ $# -gt 4 ]]; then
    echo "Использование: $0 <имя_бд> <имя_пользователя> <пароль> [enable_timescaledb]"
    exit 1
fi

DB_NAME="$1"
DB_USER="$2"
DB_PASS="$3"
ENABLE_TSDB="$4" # будет пустым, если не задан
PGB_USERLIST="/etc/pgbouncer/userlist.txt"
PGB_SERVICE="pgbouncer"

# Проверка, что скрипт запущен от root
if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: запустите скрипт от имени root или через sudo"
    exit 1
fi

# Проверка наличия psql
if ! command -v psql >/dev/null 2>&1; then
    echo "Ошибка: не найден psql (установите PostgreSQL client)"
    exit 1
fi

echo "=== Шаг 1: создаём базу \"$DB_NAME\" и пользователя \"$DB_USER\" ==="

# 1) Создание базы
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
    echo "Ошибка: не удалось выдать привилегии на базу \"$DB_NAME\" пользователю \"$DB_USER\""
    exit 1
fi

echo "=== Шаг 2: выдаём права на схему public в базе \"$DB_NAME\" ==="

# 4) GRANT USAGE и CREATE на схему public
su - postgres -c "psql -d \"$DB_NAME\" -c \"GRANT USAGE ON SCHEMA public TO $DB_USER;\"" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "Ошибка: не удалось выдать право USAGE ON SCHEMA public пользователю \"$DB_USER\""
    exit 1
fi

su - postgres -c "psql -d \"$DB_NAME\" -c \"GRANT CREATE ON SCHEMA public TO $DB_USER;\"" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo "Ошибка: не удалось выдать право CREATE ON SCHEMA public пользователю \"$DB_USER\""
    exit 1
fi

echo "Пользователь \"$DB_USER\" теперь имеет права создавать объекты в схеме public базы \"$DB_NAME\"."

# 5) Необязательный шаг: создать extension timescaledb в базе
if [[ -n "$ENABLE_TSDB" ]]; then
    echo "=== Шаг 3: создаём extension timescaledb в базе \"$DB_NAME\" ==="
    su - postgres -c "psql -d \"$DB_NAME\" -c \"CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;\"" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Ошибка: не удалось создать или проверить extension timescaledb в базе \"$DB_NAME\""
        exit 1
    fi
    echo "Extension timescaledb успешно установлен (или уже существовал)."
fi

echo "=== Шаг 4: обновляем /etc/pgbouncer/userlist.txt и перезапускаем pgbouncer ==="

# Получаем SCRAM-хеш пользователя
ROLPASS_HASH=$(su - postgres -c "psql -At -d \"$DB_NAME\" -c \"SELECT rolpassword FROM pg_authid WHERE rolname = '$DB_USER';\"")
if [[ -z "$ROLPASS_HASH" ]]; then
    echo "Предупреждение: не удалось получить SCRAM-хеш для пользователя \"$DB_USER\"."
else
    PGB_LINE="\"$DB_USER\" \"$ROLPASS_HASH\""
    # Создаём userlist.txt, если его нет, и задаём права
    if [[ ! -f "$PGB_USERLIST" ]]; then
        touch "$PGB_USERLIST"
        chown postgres:postgres "$PGB_USERLIST"
        chmod 640 "$PGB_USERLIST"
    fi
    # Если запись уже есть — заменяем, иначе — добавляем
    if grep -q "^\"$DB_USER\" " "$PGB_USERLIST"; then
        echo "Запись для \"$DB_USER\" уже есть → заменяем."
        sed -i "s/^\"$DB_USER\" \".*\"$/$PGB_LINE/" "$PGB_USERLIST"
    else
        echo "$PGB_LINE" >>"$PGB_USERLIST"
    fi
    echo "Добавлена/обновлена запись для \"$DB_USER\" в $PGB_USERLIST."
fi

# Перезапускаем службу pgbouncer
if systemctl list-unit-files | grep -q "^${PGB_SERVICE}.service"; then
    echo "Перезапускаем службу $PGB_SERVICE..."
    systemctl restart "$PGB_SERVICE"
    if [[ $? -ne 0 ]]; then
        echo "Ошибка: не удалось перезапустить службу $PGB_SERVICE. Проверьте статус и логи."
        exit 1
    fi
    echo "Служба $PGB_SERVICE успешно перезапущена."
else
    echo "Предупреждение: служба $PGB_SERVICE не найдена. Проверьте её установку."
fi

echo "=== Готово! ==="
echo "База \"$DB_NAME\" создана, пользователь \"$DB_USER\" имеет все нужные права."
if [[ -n "$ENABLE_TSDB" ]]; then
    echo "Включён TimescaleDB (extension выбран опционально)."
fi
echo "Запись пользователя добавлена в pgbouncer, служба перезапущена."
exit 0
