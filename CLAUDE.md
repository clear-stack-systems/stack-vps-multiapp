# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Docker Compose-based infrastructure stack for hosting multiple applications (dev + prod) on a single VPS. It provides:
- Nginx reverse proxy with automatic HTTPS via Let's Encrypt
- PHP-FPM runtimes (separate dev/prod containers)
- Node.js builders for frontend assets (Vite)
- MySQL and PostgreSQL databases
- Optional n8n workflow automation
- Claude CLI container for AI-assisted operations

**Critical**: This repo contains infrastructure only. Application code lives in separate repositories and is mounted from `/srv/apps/<app>/<env>/current`.

## Essential Commands

### Docker Compose Operations

**ALWAYS use the helper script** - never run `docker compose` directly:
```bash
./scripts/dc.sh up -d              # Start all services
./scripts/dc.sh restart app_dev     # Restart a service
./scripts/dc.sh logs -f app_dev     # View logs
./scripts/dc.sh exec app_dev bash   # Shell into container
./scripts/dc.sh down                # Stop all services
```

The helper script (`scripts/dc.sh`) automatically includes:
- `.env.dev` environment file
- `docker-compose.yml` (base services)
- `docker-compose.server.yml` (server-specific overrides)

Running `docker compose` directly will recreate containers without volume mounts, causing 502 errors.

### Deployment

```bash
./scripts/deploy.sh dev   # Deploy dev environment
./scripts/deploy.sh prod  # Deploy prod environment
```

Deploy script performs:
1. Git pull on host-side app repo
2. Build frontend assets via Node builder container
3. Install PHP dependencies via Composer container
4. Run Laravel migrations
5. Clear Laravel caches
6. Fix storage permissions

### Nginx Configuration

```bash
./scripts/render-nginx.sh .env.dev   # Regenerate nginx vhosts
./scripts/reload-nginx.sh            # Reload nginx config
```

Nginx vhosts are generated from templates in `nginx/templates/` based on:
- Environment variables (domains, app names)
- Certificate availability (switches between HTTP-only and HTTPS templates)

Generated configs land in `nginx/sites/*.conf` (gitignored).

### Claude CLI Container

```bash
./scripts/claude.sh              # Interactive shell
./scripts/claude.sh chat         # Start Claude chat
docker exec -it claude_cli bash  # Direct access
```

The Claude CLI container has:
- Docker socket access (can control all containers)
- Access to all app code in `/srv/apps`
- Network access to all stack services

### Health Checks

```bash
docker ps                                    # Check container health status
./scripts/health-check.sh --env-file .env.dev
```

PHP containers have healthchecks that verify Laravel files are mounted (`artisan` file check).

## Architecture

### Multi-Environment Design

The stack runs **separate containers** for dev and prod environments:
- `app_dev` / `app_prod` - PHP-FPM runtimes
- `node_builder_dev` / `node_builder_prod` - Node.js build containers
- `composer_dev` / `composer_prod` - Composer containers

Each environment mounts its own host path:
- Dev: `APP_PATH_DEV` → `/srv/apps/<app>/dev/current`
- Prod: `APP_PATH_PROD` → `/srv/apps/<app>/prod/current`

### Nginx Volume Mapping

Nginx has a **dual mount strategy**:
- **PHP-FPM** reads code from `/var/www/app` (single path)
- **Nginx** serves static files from `/var/www/app_dev` and `/var/www/app_prod` (separate paths)

This allows PHP-FPM containers to have identical configs while Nginx serves the correct static assets per environment.

FastCGI configuration explicitly sets `DOCUMENT_ROOT` parameter:
```nginx
fastcgi_param DOCUMENT_ROOT /var/www/app/public;
fastcgi_param SCRIPT_FILENAME /var/www/app/public$fastcgi_script_name;
```

### Certificate Lifecycle

1. Initial deployment uses HTTP-only vhosts
2. `scripts/first-time-certbot.sh` requests certificates
3. `scripts/render-nginx.sh` detects certificates and switches to HTTPS templates
4. Nginx reloaded to apply HTTPS configs

Certificates stored in `/srv/letsencrypt/conf`, webroot in `/srv/letsencrypt/www`.

### Custom Images

Three images are built locally:
- **PHP-FPM** (`docker/php-fpm/Dockerfile`): PHP 8.5.1 + extensions (gd, intl, pdo_mysql, zip)
- **Composer** (`docker/composer/Dockerfile`): Composer 2.8.7 with same PHP extensions
- **Claude CLI** (`docker/claude-cli/Dockerfile`): Debian + Docker CLI + Claude CLI

All images are version-pinned (no `latest` tags).

## Key Paths

```
/srv/docker/<stack-repo>/           Stack repository (this repo)
/srv/apps/<app>/<env>/current/      Application code (separate repos)
/srv/letsencrypt/www/               ACME challenge webroot
/srv/letsencrypt/conf/              Certificate storage
```

## Environment Configuration

- `.env.example` - Template with documentation
- `.env.dev`, `.env.prod` - Real values (gitignored)
- All differences between environments handled via env files + compose overrides

Critical environment variables:
- `APP_PATH_DEV`, `APP_PATH_PROD` - Host paths to application code
- `DOMAIN_DEV`, `DOMAIN_PROD` - Public domains
- `APP_NAME` - Used for container naming (e.g., `wwerp_php_dev`)

## Scripts Reference

- `install.sh` - Non-interactive server setup (system packages, Docker, firewall, folders, certs)
- `deploy.sh` - Application deployment (git pull, build, migrate)
- `dc.sh` - Docker Compose wrapper with correct files
- `render-nginx.sh` - Generate nginx vhosts from templates
- `reload-nginx.sh` - Reload nginx config without downtime
- `first-time-certbot.sh` - Request initial Let's Encrypt certificates
- `health-check.sh` - Verify stack health
- `claude.sh` - Access Claude CLI container

## Coding Standards

- Shell scripts: `set -euo pipefail` (fail fast)
- English only for code and comments
- Never commit secrets (use `.env.example` for documentation)
- Pin all image versions
- Prefer idempotent scripts (safe to re-run)

## Troubleshooting

### 502 Bad Gateway

Most common cause: Containers recreated without volume mounts.

Check if Laravel files are mounted:
```bash
docker exec wwerp_php_dev ls /var/www/app/artisan
```

If not found, recreate containers properly:
```bash
./scripts/dc.sh up -d app_dev app_prod
docker restart nginx
```

### Container Health Status

```bash
docker ps  # Look for (healthy) or (unhealthy) status
```

Unhealthy PHP containers mean volume mounts failed.

### Nginx Configuration Issues

After modifying templates or env vars:
```bash
./scripts/render-nginx.sh .env.dev
./scripts/reload-nginx.sh
```

Check generated configs in `nginx/sites/*.conf`.

### Certificate Problems

Verify certificates exist:
```bash
ls -l /srv/letsencrypt/conf/live/<domain>/
```

Re-render nginx to switch to HTTPS template:
```bash
./scripts/render-nginx.sh .env.dev
```
