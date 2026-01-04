#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env.dev"

usage() {
  cat <<EOF
Usage: ./scripts/health-check.sh [--env-file <path>]

Runs basic checks for the stack (containers, nginx config, HTTPS endpoints).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)
      ENV_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Env file not found: ${ENV_FILE}"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

missing=()
for k in DOMAIN_PROD DOMAIN_DEV; do
  if [[ -z "${!k:-}" ]]; then missing+=("$k"); fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Missing required env vars in ${ENV_FILE}: ${missing[*]}"
  exit 1
fi

compose_cmd=(docker compose --env-file "${ENV_FILE}" -f docker-compose.yml -f docker-compose.server.yml)

echo "[health] Services"
${compose_cmd[@]} ps

echo "[health] Nginx config"
${compose_cmd[@]} exec nginx nginx -t

check_https() {
  local domain="$1"
  echo "[health] HTTPS ${domain}"
  curl -Ik "https://${domain}" | sed -n '1,5p'
}

check_https "${DOMAIN_PROD}"
check_https "${DOMAIN_DEV}"

if [[ -n "${DOMAIN_N8N:-}" ]]; then
  check_https "${DOMAIN_N8N}"
fi

echo "[health] Done."
