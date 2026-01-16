#!/usr/bin/env bash
set -euo pipefail

# Permissions fix script for stack-vps-multiapp
# This script sets correct ownership and permissions across the entire stack

DEPLOY_USER="${1:-ben}"

echo "=== Stack VPS Multi-App: Permissions Fix ==="
echo "Deploy user: ${DEPLOY_USER}"
echo

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo"
   echo "Usage: sudo ./scripts/fix-permissions.sh [deploy-user]"
   exit 1
fi

echo "[1/7] Fixing /srv/docker/stack-vps-multiapp (stack repo)..."
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" /srv/docker/stack-vps-multiapp
find /srv/docker/stack-vps-multiapp -type d -exec chmod 755 {} \;
find /srv/docker/stack-vps-multiapp -type f -exec chmod 644 {} \;
chmod 700 /srv/docker/stack-vps-multiapp/.claude 2>/dev/null || true

echo "[2/7] Fixing /srv/docker/stack-vps-multiapp/scripts (executables)..."
chmod +x /srv/docker/stack-vps-multiapp/scripts/*.sh

echo "[3/7] Fixing /srv/apps (app code folders)..."
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" /srv/apps
find /srv/apps -type d -exec chmod 755 {} \; 2>/dev/null || true
find /srv/apps -type f -exec chmod 644 {} \; 2>/dev/null || true

echo "[4/7] Fixing /srv/letsencrypt (certificates)..."
# Letsencrypt should remain root:root, but ensure proper permissions
chown -R root:root /srv/letsencrypt
chmod 755 /srv/letsencrypt
chmod 755 /srv/letsencrypt/www
chmod 755 /srv/letsencrypt/conf
# Certificate private keys should be 600
find /srv/letsencrypt/conf -name "privkey*.pem" -exec chmod 600 {} \; 2>/dev/null || true
find /srv/letsencrypt/conf -name "fullchain*.pem" -exec chmod 644 {} \; 2>/dev/null || true

echo "[5/7] Verifying Docker socket permissions..."
if [[ -S /var/run/docker.sock ]]; then
  # Ensure deploy user is in docker group
  if ! groups "${DEPLOY_USER}" | grep -q docker; then
    echo "  Adding ${DEPLOY_USER} to docker group..."
    usermod -aG docker "${DEPLOY_USER}"
    echo "  Note: ${DEPLOY_USER} may need to re-login for group changes to take effect"
  else
    echo "  ✓ ${DEPLOY_USER} is already in docker group"
  fi
  # Socket should be root:docker with 660
  chown root:docker /var/run/docker.sock
  chmod 660 /var/run/docker.sock
else
  echo "  Warning: Docker socket not found at /var/run/docker.sock"
fi

echo "[6/7] Setting up /srv parent directory..."
# /srv should be readable by all
chmod 755 /srv
# But we keep ownership as root for security
chown root:root /srv

echo "[7/7] Verifying key paths..."
echo "  Stack repo: $(ls -ld /srv/docker/stack-vps-multiapp | awk '{print $3":"$4}')"
echo "  Apps folder: $(ls -ld /srv/apps | awk '{print $3":"$4}')"
echo "  Letsencrypt: $(ls -ld /srv/letsencrypt | awk '{print $3":"$4}')"
echo "  Docker socket: $(ls -l /var/run/docker.sock | awk '{print $3":"$4}')"

echo
echo "=== Permissions Fix Complete ==="
echo
echo "Summary:"
echo "  ✓ Stack repo owned by: ${DEPLOY_USER}:${DEPLOY_USER}"
echo "  ✓ Apps folder owned by: ${DEPLOY_USER}:${DEPLOY_USER}"
echo "  ✓ Letsencrypt owned by: root:root (secure)"
echo "  ✓ Scripts are executable"
echo "  ✓ Docker socket accessible to ${DEPLOY_USER} (via docker group)"
echo
echo "If you modified group membership, ${DEPLOY_USER} should re-login or run:"
echo "  newgrp docker"
