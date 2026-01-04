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
find nginx/sites -maxdepth 1 -type f -name "*.conf" ! -name "00-acme.conf" -delete

cert_exists() {
  local server_name="$1"
  local cert_dir="/srv/letsencrypt/conf/live/${server_name}"
  [[ -s "${cert_dir}/fullchain.pem" && -s "${cert_dir}/privkey.pem" ]]
}

render_app() {
  local server_name="$1"
  local upstream="$2"
  local template="nginx/templates/app-http.conf.tpl"
  if cert_exists "${server_name}"; then
    template="nginx/templates/app.conf.tpl"
  fi
  SERVER_NAME="${server_name}" UPSTREAM="${upstream}" \
    envsubst '${SERVER_NAME} ${UPSTREAM}' < "${template}" > "nginx/sites/${server_name}.conf"
}

render_n8n() {
  local server_name="$1"
  local template="nginx/templates/n8n-http.conf.tpl"
  if cert_exists "${server_name}"; then
    template="nginx/templates/n8n.conf.tpl"
  fi
  SERVER_NAME="${server_name}" \
    envsubst '${SERVER_NAME}' < "${template}" > "nginx/sites/${server_name}.conf"
}

render_app "${DOMAIN_DEV}" "${APP_NAME}_php_dev"
render_app "${DOMAIN_PROD}" "${APP_NAME}_php_prod"

if [[ -n "${DOMAIN_N8N:-}" ]]; then
  render_n8n "${DOMAIN_N8N}"
fi

echo "[render-nginx] Rendered vhosts into nginx/sites/"
