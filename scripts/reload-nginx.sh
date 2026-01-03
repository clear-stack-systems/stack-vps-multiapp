#!/usr/bin/env bash
set -euo pipefail
docker compose exec nginx nginx -s reload
