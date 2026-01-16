#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  POSTGRES_TODOMAP_DB
  POSTGRES_TODOMAP_USER
  POSTGRES_TODOMAP_PASSWORD
  GENERATEMEDIA_DB_NAME
  GENERATEMEDIA_DB_USER
  GENERATEMEDIA_DB_PASS
)

missing=()
for k in "${required_vars[@]}"; do
  if [[ -z "${!k:-}" ]]; then
    missing+=("$k")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Missing required env vars for Postgres init: ${missing[*]}" >&2
  exit 1
fi

# Escape single quotes in strings for SQL
sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

# Escape identifiers (database names, usernames)
id_escape() {
  printf "%s" "$1" | sed 's/"/""/g'
}

db_todomap="$(id_escape "${POSTGRES_TODOMAP_DB}")"
user_todomap="$(sql_escape "${POSTGRES_TODOMAP_USER}")"
pass_todomap="$(sql_escape "${POSTGRES_TODOMAP_PASSWORD}")"

db_generatemedia="$(id_escape "${GENERATEMEDIA_DB_NAME}")"
user_generatemedia="$(sql_escape "${GENERATEMEDIA_DB_USER}")"
pass_generatemedia="$(sql_escape "${GENERATEMEDIA_DB_PASS}")"

# Run SQL commands as postgres superuser
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-SQL
	-- Create todomap database if not exists
	SELECT 'CREATE DATABASE "${db_todomap}"'
	WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${POSTGRES_TODOMAP_DB}')\gexec

	-- Create todomap user if not exists
	DO \$\$
	BEGIN
	  IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '${user_todomap}') THEN
	    CREATE USER "${user_todomap}" WITH PASSWORD '${pass_todomap}';
	  ELSE
	    ALTER USER "${user_todomap}" WITH PASSWORD '${pass_todomap}';
	  END IF;
	END
	\$\$;

	-- Grant privileges
	GRANT ALL PRIVILEGES ON DATABASE "${db_todomap}" TO "${user_todomap}";

	-- Create generatemedia database if not exists
	SELECT 'CREATE DATABASE "${db_generatemedia}"'
	WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${GENERATEMEDIA_DB_NAME}')\gexec

	-- Create generatemedia user if not exists
	DO \$\$
	BEGIN
	  IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '${user_generatemedia}') THEN
	    CREATE USER "${user_generatemedia}" WITH PASSWORD '${pass_generatemedia}';
	  ELSE
	    ALTER USER "${user_generatemedia}" WITH PASSWORD '${pass_generatemedia}';
	  END IF;
	END
	\$\$;

	-- Grant privileges
	GRANT ALL PRIVILEGES ON DATABASE "${db_generatemedia}" TO "${user_generatemedia}";
SQL

echo "PostgreSQL initialization completed: todomap and generatemedia databases and users created"
