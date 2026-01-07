#!/bin/bash
# Docker Compose helper script - ensures correct files are always used
# Usage: ./scripts/dc.sh [docker-compose commands]
# Example: ./scripts/dc.sh up -d
#          ./scripts/dc.sh logs -f app_dev

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Always use both compose files
exec docker compose \
  --env-file .env.dev \
  -f docker-compose.yml \
  -f docker-compose.server.yml \
  "$@"
