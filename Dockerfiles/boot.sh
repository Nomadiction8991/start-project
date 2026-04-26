#!/bin/sh
set -e

APP_DIR="${APP_NAME}"
APP_PATH="/var/www/html/${APP_DIR}"

init_runtime_dirs() {
    mkdir -p "$COMPOSER_HOME" "$COMPOSER_CACHE_DIR"
}

set_env_value() {
    env_file="$1"
    env_key="$2"
    env_value="$3"

    php /usr/local/bin/update_env_value.php "$env_file" "$env_key" "$env_value"
}

ensure_laravel_app() {
    if command -v composer >/dev/null 2>&1; then
        if [ ! -f "${APP_PATH}/artisan" ]; then
            echo "Criando Laravel em ${APP_DIR}..."
            composer create-project laravel/laravel "${APP_PATH}" --no-interaction --prefer-dist --no-progress --no-scripts
        fi
    else
        echo "Composer não encontrado, não foi possível criar o Laravel."
        exit 1
    fi
}

sync_app_env() {
    if [ -f "${APP_PATH}/.env.example" ]; then
        if [ ! -f "${APP_PATH}/.env" ]; then
            cp "${APP_PATH}/.env.example" "${APP_PATH}/.env"
        fi

        set_env_value "${APP_PATH}/.env" "APP_NAME" "${APP_DIR}"
        set_env_value "${APP_PATH}/.env" "APP_URL" "http://localhost:${HOST_PORT}"
        set_env_value "${APP_PATH}/.env" "DB_CONNECTION" "mysql"
        set_env_value "${APP_PATH}/.env" "DB_HOST" "${DB_HOST}"
        set_env_value "${APP_PATH}/.env" "DB_PORT" "${DB_PORT}"
        set_env_value "${APP_PATH}/.env" "DB_DATABASE" "${DB_DATABASE}"
        set_env_value "${APP_PATH}/.env" "DB_USERNAME" "root"
        set_env_value "${APP_PATH}/.env" "DB_PASSWORD" "${DB_ROOT_PASSWORD}"

        if [ -f "${APP_PATH}/${APP_DIR}" ]; then
            rm -f "${APP_PATH}/${APP_DIR}"
        fi
        rm -f "${APP_PATH}/database/database.sqlite"
    fi
}

wait_for_database() {
    if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ] && [ -n "$DB_DATABASE" ] && [ -n "$DB_ROOT_PASSWORD" ] && command -v mysql >/dev/null 2>&1; then
        echo "Aguardando o banco em ${DB_HOST}:${DB_PORT}..."

        attempt=1
        while ! MYSQL_PWD="${DB_ROOT_PASSWORD}" mysql \
            -h"$DB_HOST" \
            -P"$DB_PORT" \
            -uroot \
            -e "SELECT 1" \
            "$DB_DATABASE" >/dev/null 2>&1; do
            if [ "$attempt" -ge 30 ]; then
                echo "Banco não ficou pronto a tempo."
                exit 1
            fi

            echo "Banco ainda indisponível, tentativa ${attempt}/30..."
            attempt=$((attempt + 1))
            sleep 2
        done
    else
        echo "Variáveis do banco ausentes ou cliente MySQL indisponível, pulando espera."
        exit 1
    fi
}

install_dependencies() {
    if command -v composer >/dev/null 2>&1; then
        if [ ! -d vendor ] || [ ! -f vendor/composer/installed.json ] || [ composer.lock -nt vendor/composer/installed.json ]; then
            echo "Executando composer install em ${APP_PATH}..."
            composer install --no-interaction --prefer-dist --no-progress --optimize-autoloader
        else
            echo "Dependências já instaladas, pulando composer install."
        fi
    else
        echo "Composer não encontrado, pulando composer install."
        exit 1
    fi
}

run_migrations() {
    if [ -f artisan ] && command -v php >/dev/null 2>&1; then
        echo "Arquivo artisan encontrado, executando migrations..."
        php artisan migrate --force || echo "Falha ao executar migrate, seguindo inicialização."
    else
        echo "Artisan não encontrado, pulando migrations."
        exit 1
    fi
}

ensure_app_key() {
    if [ -f artisan ] && command -v php >/dev/null 2>&1; then
        if grep -qE '^APP_KEY=.+$' .env; then
            echo "APP_KEY já definida, pulando geração."
        else
            echo "Gerando APP_KEY..."
            php artisan key:generate --ansi
        fi
    else
        echo "Artisan não encontrado, pulando geração da APP_KEY."
        exit 1
    fi
}

exec_entrypoint() {
    if [ -x /usr/local/bin/docker-php-entrypoint ]; then
        exec docker-php-entrypoint "$@"
    else
        exec "$@"
    fi
}

init_runtime_dirs
ensure_laravel_app
cd "${APP_PATH}" || exit 1
sync_app_env
wait_for_database
unset APP_NAME APP_ENV DB_HOST DB_PORT DB_DATABASE DB_ROOT_PASSWORD HOST_PORT LOCAL_UID LOCAL_GID
install_dependencies
ensure_app_key
run_migrations
exec_entrypoint "$@"
