FROM composer:2.8.7 AS composer

FROM php:8.4.16-fpm-alpine3.23

RUN set -eux; \
  apk add --no-cache \
    icu-libs \
    libzip \
    libpng \
    libjpeg-turbo \
    freetype; \
  apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    icu-dev \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev; \
  docker-php-ext-configure gd --with-freetype --with-jpeg; \
  docker-php-ext-install -j"$(nproc)" \
    gd \
    intl \
    pdo_mysql \
    zip; \
  apk del .build-deps

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

ENV COMPOSER_ALLOW_SUPERUSER=1
