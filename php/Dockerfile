FROM php:8.3.2-fpm-alpine3.20

# System deps
RUN set -eux; \
    apk add --no-cache \
      bash \
      git \
      curl \
      icu-data-full icu-libs \
      libzip \
      oniguruma \
      $PHPIZE_DEPS \
      icu-dev \
      libzip-dev \
      oniguruma-dev \
      zlib-dev \
      ; \
    docker-php-ext-install -j$(nproc) \
      pdo_mysql \
      pdo_pgsql \
      intl \
      mbstring \
      zip \
      opcache \
      ; \
    apk del --no-network $PHPIZE_DEPS icu-dev libzip-dev oniguruma-dev zlib-dev

# Composer (pinned major; consider pinning sha256 for stricter supply chain)
COPY --from=composer:2.7.7 /usr/bin/composer /usr/bin/composer

# PHP config
COPY php.ini /usr/local/etc/php/php.ini

WORKDIR /var/www/app
