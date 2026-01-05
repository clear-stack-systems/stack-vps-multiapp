#!/usr/bin/env bash
set -euo pipefail

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q '^claude_cli$'; then
  echo "Error: claude_cli container is not running"
  echo "Start it with: docker compose up -d claude_cli"
  exit 1
fi

# If no arguments, start interactive shell
if [ $# -eq 0 ]; then
  docker exec -it claude_cli bash
else
  # Pass through arguments to claude command
  docker exec -it claude_cli claude "$@"
fi
