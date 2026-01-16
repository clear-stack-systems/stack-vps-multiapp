#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env.dev"

usage() {
  cat <<EOF
Usage: ./scripts/install.sh [--env-file <path>]

This installer is designed to be non-interactive.
Prepare the env file first (copy .env.example -> .env.dev and edit).

Example:
  cp .env.example .env.dev
  nano .env.dev
  ./scripts/install.sh --env-file .env.dev
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
  echo "Create it first: cp .env.example ${ENV_FILE} && nano ${ENV_FILE}"
  exit 1
fi

require_cmd() { command -v "$1" >/dev/null 2>&1; }

echo "[install] Packages"
sudo apt update
sudo apt -y install ca-certificates curl git unzip ufw gettext-base openssl

echo "[install] Firewall (UFW)"
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

if ! require_cmd docker; then
  echo "[install] Installing Docker + Compose plugin"
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
  echo     "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu     $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |     sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt update
  sudo apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker "$USER" || true
  echo "[install] Docker installed. Re-login might be required for docker group."
fi

echo "[install] Load env from ${ENV_FILE}"
set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

missing=()
for k in DOMAIN_PROD DOMAIN_DEV APP_NAME APP_PATH_DEV APP_PATH_PROD APP_REPO_URL MYSQL_DATABASE_DEV MYSQL_DATABASE_PROD MYSQL_USER_DEV MYSQL_USER_PROD; do
  if [[ -z "${!k:-}" ]]; then missing+=("$k"); fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Missing required env vars in ${ENV_FILE}: ${missing[*]}"
  exit 1
fi

gen_secret() { openssl rand -hex 24; }
gen_key32()  { openssl rand -hex 32; }

if [[ "${MYSQL_ROOT_PASSWORD:-}" == "change-me" || -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
  MYSQL_ROOT_PASSWORD="$(gen_secret)"
  sed -i "s|^MYSQL_ROOT_PASSWORD=.*|MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}|" "${ENV_FILE}"
fi
if [[ "${MYSQL_PASSWORD_DEV:-}" == "change-me" || -z "${MYSQL_PASSWORD_DEV:-}" ]]; then
  MYSQL_PASSWORD_DEV="$(gen_secret)"
  sed -i "s|^MYSQL_PASSWORD_DEV=.*|MYSQL_PASSWORD_DEV=${MYSQL_PASSWORD_DEV}|" "${ENV_FILE}"
fi
if [[ "${MYSQL_PASSWORD_PROD:-}" == "change-me" || -z "${MYSQL_PASSWORD_PROD:-}" ]]; then
  MYSQL_PASSWORD_PROD="$(gen_secret)"
  sed -i "s|^MYSQL_PASSWORD_PROD=.*|MYSQL_PASSWORD_PROD=${MYSQL_PASSWORD_PROD}|" "${ENV_FILE}"
fi
if [[ "${POSTGRES_PASSWORD:-}" == "change-me" || -z "${POSTGRES_PASSWORD:-}" ]]; then
  POSTGRES_PASSWORD="$(gen_secret)"
  sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${POSTGRES_PASSWORD}|" "${ENV_FILE}"
fi
if [[ "${N8N_BASIC_AUTH_PASSWORD:-}" == "change-me" || -z "${N8N_BASIC_AUTH_PASSWORD:-}" ]]; then
  N8N_BASIC_AUTH_PASSWORD="$(gen_secret)"
  sed -i "s|^N8N_BASIC_AUTH_PASSWORD=.*|N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}|" "${ENV_FILE}"
fi
if [[ "${N8N_ENCRYPTION_KEY:-}" == "change-me-32chars-min" || -z "${N8N_ENCRYPTION_KEY:-}" ]]; then
  N8N_ENCRYPTION_KEY="$(gen_key32)"
  sed -i "s|^N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}|" "${ENV_FILE}"
fi
if [[ "${GENERATEMEDIA_DB_PASS:-}" == "change-me" || -z "${GENERATEMEDIA_DB_PASS:-}" ]]; then
  GENERATEMEDIA_DB_PASS="$(gen_secret)"
  sed -i "s|^GENERATEMEDIA_DB_PASS=.*|GENERATEMEDIA_DB_PASS=${GENERATEMEDIA_DB_PASS}|" "${ENV_FILE}"
fi
if [[ "${GENERATEMEDIA_API_KEY:-}" == "change-me" || -z "${GENERATEMEDIA_API_KEY:-}" ]]; then
  GENERATEMEDIA_API_KEY="$(gen_key32)"
  sed -i "s|^GENERATEMEDIA_API_KEY=.*|GENERATEMEDIA_API_KEY=${GENERATEMEDIA_API_KEY}|" "${ENV_FILE}"
fi

echo "[install] Folders under /srv"
sudo mkdir -p /srv/apps
sudo mkdir -p /srv/letsencrypt/www /srv/letsencrypt/conf
sudo chmod 755 /srv/letsencrypt/www /srv/letsencrypt/conf
sudo chown -R "$USER:$USER" /srv/apps

echo "[install] Clone app repo into host paths (if missing)"
mkdir -p "$(dirname "${APP_PATH_DEV}")" "$(dirname "${APP_PATH_PROD}")"
if [[ ! -d "${APP_PATH_DEV}/.git" ]]; then
  git clone --branch "${APP_BRANCH_DEV:-dev}" "${APP_REPO_URL}" "${APP_PATH_DEV}"
fi
if [[ ! -d "${APP_PATH_PROD}/.git" ]]; then
  git clone --branch "${APP_BRANCH_PROD:-main}" "${APP_REPO_URL}" "${APP_PATH_PROD}"
fi

echo "[install] Clone generatemedia app (if configured and missing)"
if [[ -n "${GENERATEMEDIA_APP_REPO:-}" && -n "${GENERATEMEDIA_APP_PATH:-}" ]]; then
  mkdir -p "$(dirname "${GENERATEMEDIA_APP_PATH}")"
  if [[ ! -d "${GENERATEMEDIA_APP_PATH}/.git" ]]; then
    git clone "${GENERATEMEDIA_APP_REPO}" "${GENERATEMEDIA_APP_PATH}" || echo "Warning: generatemedia repo clone failed (repo may be empty)"
  fi
fi

echo "[install] Render Nginx vhosts"
./scripts/render-nginx.sh "${ENV_FILE}"

echo "[install] Start stack"
docker compose --env-file "${ENV_FILE}" -f docker-compose.yml -f docker-compose.server.yml up -d

echo "[install] Initialize MySQL databases and users"
./scripts/init-mysql.sh "${ENV_FILE}"

echo "[install] Request TLS certificates (DNS must point to this server)"
./scripts/first-time-certbot.sh "${ENV_FILE}"

echo "[install] Done."
echo
echo "Generated/confirmed secrets in ${ENV_FILE}:"
echo "  MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}"
echo "  MYSQL_PASSWORD_DEV=${MYSQL_PASSWORD_DEV}"
echo "  MYSQL_PASSWORD_PROD=${MYSQL_PASSWORD_PROD}"
echo "  POSTGRES_PASSWORD=${POSTGRES_PASSWORD}"
echo "  N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}"
echo "  N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}"
echo "  GENERATEMEDIA_DB_PASS=${GENERATEMEDIA_DB_PASS:-}"
echo "  GENERATEMEDIA_API_KEY=${GENERATEMEDIA_API_KEY:-}"
