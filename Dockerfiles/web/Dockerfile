FROM php:8.3-apache AS base

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    libzip-dev \
    libpng-dev \
    unzip \
    curl \
    git \
    && docker-php-ext-install gd zip mysqli pdo pdo_mysql \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY Dockerfiles/boot.sh /usr/local/bin/boot.sh
RUN chmod +x /usr/local/bin/boot.sh

COPY Dockerfiles/apache.conf /etc/apache2/sites-available/000-default.conf
COPY Dockerfiles/php.ini /usr/local/etc/php/conf.d/dev.ini

ENTRYPOINT ["/usr/local/bin/boot.sh"]
CMD ["apache2-foreground"]

FROM base AS prod

COPY . .

EXPOSE 80

FROM base AS dev

RUN pecl install xdebug \
 && docker-php-ext-enable xdebug

EXPOSE 80
