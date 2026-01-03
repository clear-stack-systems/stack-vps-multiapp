#!/usr/bin/env bash
set -euo pipefail

sudo mkdir -p /srv/apps
sudo mkdir -p /srv/letsencrypt/www /srv/letsencrypt/conf
sudo chmod 755 /srv/letsencrypt/www /srv/letsencrypt/conf

echo "Created /srv/apps and /srv/letsencrypt/*"
