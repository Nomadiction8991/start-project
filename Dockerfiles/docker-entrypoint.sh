set -e

cd /var/www/html || exit 0


if command -v composer >/dev/null 2>&1; then
    if [ ! -d vendor ] || [ ! -f vendor/composer/installed.json ] || [ composer.lock -nt vendor/composer/installed.json ]; then
        echo "Executando composer install..."
        composer install --no-interaction --prefer-dist --no-progress --optimize-autoloader
    else
        echo "Dependências já instaladas, pulando composer install."
    fi
else
    echo "Composer não encontrado, pulando composer install."
fi

chown -R www-data:www-data /var/www/html || true

if [ -x /usr/local/bin/docker-php-entrypoint ]; then
    exec docker-php-entrypoint "$@"
else
    exec "$@"
fi
