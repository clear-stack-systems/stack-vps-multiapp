#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
if [[ "${TARGET}" != "dev" && "${TARGET}" != "prod" ]]; then
  echo "Usage: ./scripts/deploy.sh <dev|prod>"
  exit 1
fi

if [[ "${TARGET}" == "dev" ]]; then
  APP_SERVICE="app_dev"
  NODE_SERVICE="node_builder_dev"
  APP_PATH="${APP_PATH_DEV:-}"
  BRANCH="${APP_BRANCH_DEV:-}"
else
  APP_SERVICE="app_prod"
  NODE_SERVICE="node_builder_prod"
  APP_PATH="${APP_PATH_PROD:-}"
  BRANCH="${APP_BRANCH_PROD:-}"
fi

if [[ -z "${APP_PATH}" ]]; then
  echo "APP_PATH for ${TARGET} is not set (APP_PATH_DEV/APP_PATH_PROD)."
  exit 1
fi

echo "[deploy:${TARGET}] Updating repo on host: ${APP_PATH}"
if [[ -n "${BRANCH}" ]]; then
  git -C "${APP_PATH}" fetch --all
  git -C "${APP_PATH}" reset --hard "origin/${BRANCH}"
else
  echo "[deploy:${TARGET}] No branch configured; skipping host-side git update."
fi

echo "[deploy:${TARGET}] Building frontend assets..."
docker compose run --rm "${NODE_SERVICE}" sh -lc "npm ci && npm run build"

echo "[deploy:${TARGET}] Installing PHP dependencies..."
docker compose exec "${APP_SERVICE}" sh -lc "composer install --no-interaction --prefer-dist --optimize-autoloader"

echo "[deploy:${TARGET}] Running migrations..."
docker compose exec "${APP_SERVICE}" sh -lc "php artisan migrate --force"

echo "[deploy:${TARGET}] Clearing caches..."
docker compose exec "${APP_SERVICE}" sh -lc "php artisan optimize:clear || true"

echo "[deploy:${TARGET}] Fixing permissions (storage + bootstrap/cache)..."
docker compose exec "${APP_SERVICE}" sh -lc "chown -R 82:82 storage bootstrap/cache || true"

echo "[deploy:${TARGET}] Done."
