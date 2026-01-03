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

mkdir -p nginx/sites

render_app() {
  local server_name="$1"
  local upstream="$2"
  SERVER_NAME="${server_name}" UPSTREAM="${upstream}" envsubst < nginx/templates/app.conf.tpl > "nginx/sites/${server_name}.conf"
}

render_n8n() {
  local server_name="$1"
  SERVER_NAME="${server_name}" envsubst < nginx/templates/n8n.conf.tpl > "nginx/sites/${server_name}.conf"
}

render_app "${DOMAIN_DEV}" "${APP_NAME}_php_dev"
render_app "${DOMAIN_PROD}" "${APP_NAME}_php_prod"

if [[ -n "${DOMAIN_N8N:-}" ]]; then
  render_n8n "${DOMAIN_N8N}"
fi

echo "[render-nginx] Rendered vhosts into nginx/sites/"
