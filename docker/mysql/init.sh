#!/usr/bin/env bash
set -euo pipefail

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
  echo "Missing required env vars for MySQL init: ${missing[*]}" >&2
  exit 1
fi

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

mysql -u root "-p${MYSQL_ROOT_PASSWORD}" <<SQL
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
