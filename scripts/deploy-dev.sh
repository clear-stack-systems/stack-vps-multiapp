#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:-}"
if [[ -z "${APP_NAME}" ]]; then
  echo "Usage: ./scripts/deploy-dev.sh <app-name>"
  exit 1
fi

echo "[deploy] Pull latest code (host-side, expected to be done by the caller)"
echo "[deploy] Building frontend assets using node_builder..."
docker compose run --rm node_builder sh -lc "npm ci && npm run build"

echo "[deploy] Installing PHP dependencies..."
docker compose exec app sh -lc "composer install --no-interaction --prefer-dist --optimize-autoloader"

echo "[deploy] Running migrations..."
docker compose exec app sh -lc "php artisan migrate --force"

echo "[deploy] Clearing caches..."
docker compose exec app sh -lc "php artisan optimize:clear || true"

echo "[deploy] Fixing permissions (storage + bootstrap/cache)..."
# Adjust UID:GID to match your PHP-FPM user inside the image (Alpine often uses 82:82).
docker compose exec app sh -lc "chown -R 82:82 storage bootstrap/cache || true"

echo "[deploy] Done."
