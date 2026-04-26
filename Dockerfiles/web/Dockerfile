FROM php:8.3-apache AS base

ARG APP_NAME
ENV APP_NAME=${APP_NAME}
ENV HOME=/tmp \
    COMPOSER_HOME=/tmp/composer \
    COMPOSER_CACHE_DIR=/tmp/composer/cache

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    libzip-dev \
    libpng-dev \
    default-mysql-client \
    unzip \
    curl \
    git \
    && docker-php-ext-install gd zip mysqli pdo pdo_mysql \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY Dockerfiles/boot.sh /usr/local/bin/boot.sh
COPY scripts/update_env_value.php /usr/local/bin/update_env_value.php
RUN chmod +x /usr/local/bin/boot.sh

COPY Dockerfiles/apache.conf /etc/apache2/sites-available/000-default.conf
COPY Dockerfiles/php.ini /usr/local/etc/php/conf.d/dev.ini
RUN sed -i "s#__APP_PUBLIC_ROOT__#/var/www/html/${APP_NAME}/public#g" /etc/apache2/sites-available/000-default.conf

ENTRYPOINT ["/usr/local/bin/boot.sh"]
CMD ["apache2-foreground"]

FROM base AS production

COPY . .

EXPOSE 80

FROM base AS local

RUN pecl install xdebug \
 && docker-php-ext-enable xdebug

EXPOSE 80
