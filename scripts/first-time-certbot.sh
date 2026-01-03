#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-.env.dev}"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Env file not found: ${ENV_FILE}"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

mkdir -p /srv/letsencrypt/www /srv/letsencrypt/conf

email="${CERTBOT_EMAIL:-admin@${DOMAIN_PROD}}"

request_cert() {
  local domain="$1"
  echo "[certbot] Requesting cert for ${domain}..."
  docker compose run --rm certbot certonly --webroot     -w /var/www/certbot     -d "${domain}"     --email "${email}"     --agree-tos     --no-eff-email
}

request_cert "${DOMAIN_PROD}"
request_cert "${DOMAIN_DEV}"

if [[ -n "${DOMAIN_N8N:-}" ]]; then
  request_cert "${DOMAIN_N8N}"
fi

echo "[certbot] Reloading nginx..."
docker compose exec nginx nginx -s reload

echo "[certbot] Done."
