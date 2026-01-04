#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-.env.dev}"

usage() {
  cat <<EOF
Usage: ./scripts/init-mysql.sh [env-file]

Creates dev/prod databases and users inside the MySQL container.
EOF
}

if [[ "${ENV_FILE}" == "-h" || "${ENV_FILE}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Env file not found: ${ENV_FILE}"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

required_vars=(
  MYSQL_ROOT_PASSWORD
  MYSQL_DATABASE_PROD
  MYSQL_USER_PROD
  MYSQL_PASSWORD_PROD
  MYSQL_DATABASE_DEV
  MYSQL_USER_DEV
  MYSQL_PASSWORD_DEV
)

missing=()
for k in "${required_vars[@]}"; do
  if [[ -z "${!k:-}" ]]; then
    missing+=("$k")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Missing required env vars in ${ENV_FILE}: ${missing[*]}"
  exit 1
fi

compose_cmd=(docker compose --env-file "${ENV_FILE}" -f docker-compose.yml -f docker-compose.server.yml)

wait_for_mysql() {
  local i
  for i in {1..30}; do
    if ${compose_cmd[@]} exec -T mysql mysqladmin ping -u root "-p${MYSQL_ROOT_PASSWORD}" --silent; then
      return 0
    fi
    sleep 2
  done
  echo "MySQL did not become ready in time."
  return 1
}

sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

db_escape() {
  printf "%s" "$1" | sed 's/`/``/g'
}

db_prod="$(db_escape "${MYSQL_DATABASE_PROD}")"
db_dev="$(db_escape "${MYSQL_DATABASE_DEV}")"
user_prod="$(sql_escape "${MYSQL_USER_PROD}")"
user_dev="$(sql_escape "${MYSQL_USER_DEV}")"
pass_prod="$(sql_escape "${MYSQL_PASSWORD_PROD}")"
pass_dev="$(sql_escape "${MYSQL_PASSWORD_DEV}")"

wait_for_mysql

${compose_cmd[@]} exec -T mysql mysql -u root "-p${MYSQL_ROOT_PASSWORD}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${db_prod}\`;
CREATE DATABASE IF NOT EXISTS \`${db_dev}\`;

CREATE USER IF NOT EXISTS '${user_prod}'@'%' IDENTIFIED BY '${pass_prod}';
ALTER USER '${user_prod}'@'%' IDENTIFIED BY '${pass_prod}';
GRANT ALL PRIVILEGES ON \`${db_prod}\`.* TO '${user_prod}'@'%';

CREATE USER IF NOT EXISTS '${user_dev}'@'%' IDENTIFIED BY '${pass_dev}';
ALTER USER '${user_dev}'@'%' IDENTIFIED BY '${pass_dev}';
GRANT ALL PRIVILEGES ON \`${db_dev}\`.* TO '${user_dev}'@'%';

FLUSH PRIVILEGES;
SQL

echo "[init-mysql] Done."
