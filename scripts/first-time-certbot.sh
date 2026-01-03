#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DOMAIN_PROD:-}" || -z "${DOMAIN_DEV:-}" ]]; then
  echo "DOMAIN_PROD and DOMAIN_DEV must be set in your env file."
  exit 1
fi

mkdir -p /srv/letsencrypt/www /srv/letsencrypt/conf

echo "[certbot] Requesting cert for ${DOMAIN_PROD}..."
docker compose run --rm certbot certonly --webroot       -w /var/www/certbot       -d "${DOMAIN_PROD}"       --email "admin@${DOMAIN_PROD}"       --agree-tos       --no-eff-email

echo "[certbot] Requesting cert for ${DOMAIN_DEV}..."
docker compose run --rm certbot certonly --webroot       -w /var/www/certbot       -d "${DOMAIN_DEV}"       --email "admin@${DOMAIN_DEV}"       --agree-tos       --no-eff-email

echo "[certbot] Reloading nginx..."
docker compose exec nginx nginx -s reload

echo "[certbot] Done."
