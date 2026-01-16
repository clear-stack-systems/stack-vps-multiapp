#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-.env.dev}"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Env file not found: ${ENV_FILE}"
  echo "Usage: ./scripts/deploy-generatemedia.sh [env-file]"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

if [[ -z "${GENERATEMEDIA_APP_PATH:-}" ]]; then
  echo "GENERATEMEDIA_APP_PATH is not set in ${ENV_FILE}"
  exit 1
fi

echo "[deploy:generatemedia] Updating repo on host: ${GENERATEMEDIA_APP_PATH}"
if [[ -d "${GENERATEMEDIA_APP_PATH}/.git" ]]; then
  git -C "${GENERATEMEDIA_APP_PATH}" fetch --all
  git -C "${GENERATEMEDIA_APP_PATH}" reset --hard origin/main
else
  echo "[deploy:generatemedia] Warning: No git repo found at ${GENERATEMEDIA_APP_PATH}"
  echo "[deploy:generatemedia] Skipping git update. Clone the repo first or run install.sh."
fi

echo "[deploy:generatemedia] Checking if app has package.json..."
if [[ ! -f "${GENERATEMEDIA_APP_PATH}/package.json" ]]; then
  echo "[deploy:generatemedia] Warning: No package.json found at ${GENERATEMEDIA_APP_PATH}/package.json"
  echo "[deploy:generatemedia] The repo may be empty. Build will fail gracefully."
fi

echo "[deploy:generatemedia] Checking app environment file..."
if [[ ! -f "${GENERATEMEDIA_APP_PATH}/.env" ]]; then
  echo "[deploy:generatemedia] Warning: No .env file found at ${GENERATEMEDIA_APP_PATH}/.env"
  echo "[deploy:generatemedia] Please create one from .env.example:"
  echo "  cp ${GENERATEMEDIA_APP_PATH}/.env.example ${GENERATEMEDIA_APP_PATH}/.env"
  echo "  nano ${GENERATEMEDIA_APP_PATH}/.env"
  echo "[deploy:generatemedia] Required: KIE_API_KEY, KIE_DEFAULT_MODEL"
  echo ""
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

echo "[deploy:generatemedia] Building generatemedia image..."
docker compose --env-file "${ENV_FILE}" -f docker-compose.yml -f docker-compose.server.yml build generatemedia_web

echo "[deploy:generatemedia] Running database migrations (if prisma exists)..."
if [[ -f "${GENERATEMEDIA_APP_PATH}/prisma/schema.prisma" ]]; then
  docker compose --env-file "${ENV_FILE}" -f docker-compose.yml -f docker-compose.server.yml run --rm generatemedia_web npx prisma migrate deploy || echo "Warning: Prisma migration failed or not configured"
else
  echo "[deploy:generatemedia] No Prisma schema found, skipping migrations"
fi

echo "[deploy:generatemedia] Starting services..."
docker compose --env-file "${ENV_FILE}" -f docker-compose.yml -f docker-compose.server.yml up -d redis generatemedia_web generatemedia_worker

echo "[deploy:generatemedia] Rendering and reloading Nginx..."
./scripts/render-nginx.sh "${ENV_FILE}"
./scripts/reload-nginx.sh

echo "[deploy:generatemedia] Deployment complete!"
echo
echo "Check services:"
echo "  docker ps | grep generatemedia"
echo "  docker logs generatemedia_web"
echo "  docker logs generatemedia_worker"
echo
echo "Test endpoint:"
echo "  curl -I https://${DOMAIN_GENERATEMEDIA:-generatemedia.jenyn.com}"
