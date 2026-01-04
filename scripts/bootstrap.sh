#!/usr/bin/env bash
set -euo pipefail

echo "[bootstrap] Checking docker..."
docker --version >/dev/null
docker compose version >/dev/null

echo "[bootstrap] Creating folders under /srv/letsencrypt..."
sudo mkdir -p /srv/letsencrypt/www /srv/letsencrypt/conf
sudo chmod 755 /srv/letsencrypt/www /srv/letsencrypt/conf

echo "[bootstrap] Pulling images..."
docker compose pull

echo "[bootstrap] Starting services..."
docker compose up -d

echo "[bootstrap] Done."
