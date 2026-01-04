# Docker Compose Server Stack

A reproducible multi-app server stack for:
- Nginx reverse proxy (HTTP/HTTPS)
- ACME HTTP-01 + Certbot
- Laravel (PHP-FPM) for dev and prod (separate runtimes)
- Separate Node builder containers (Vite build) for dev/prod
- MySQL + Postgres
- n8n (optional, included)

## Goals
- Reproducible on a new server: clone → run installer → up.
- Versioned images (no `latest`).
- Same service set for local/dev/prod; differences via `.env` + compose overrides.
- App code lives in separate repos; this repo only mounts app folders from the host.

## Requirements
- Ubuntu 24.04
- DNS A records pointing to this server (prod/dev, optional n8n)
- Public app repo (recommended) to avoid SSH keys

## Quick start (minimal interaction)

### 1) Clone the stack repo
```bash
sudo mkdir -p /srv/docker
sudo chown -R $USER:$USER /srv/docker
cd /srv/docker
git clone https://github.com/YOUR_ORG/YOUR_STACK_REPO.git
cd YOUR_STACK_REPO
chmod +x scripts/*.sh
```

### 2) Provide settings (one file, no wizard)
```bash
cp .env.example .env.dev
nano .env.dev
```

### 3) Run installer (non-interactive)
```bash
./scripts/install.sh --env-file .env.dev
```

The installer will:
- install packages + Docker + Compose plugin (if missing)
- configure UFW (22/80/443)
- create required folders under `/srv`
- clone app repo to `/srv/apps/...` (if missing)
- render Nginx vhosts from templates (HTTP-only until certs exist)
- bring the stack up
- initialize MySQL dev/prod databases and users
- request certificates with Certbot, re-render HTTPS vhosts, and reload Nginx

## Deploy
```bash
./scripts/deploy.sh dev
./scripts/deploy.sh prod
```

## Health check
```bash
./scripts/health-check.sh --env-file .env.dev
```

## PHP + Composer images
- PHP-FPM is built locally from `docker/php-fpm/Dockerfile` (extensions: gd, intl, zip; base PHP 8.4.16).
- Composer runs in a separate container built from `docker/composer/Dockerfile` (same extensions as PHP-FPM).

## Optional: n8n
- Set `DOMAIN_N8N` to a real DNS name to enable the n8n vhost and certificate.
- Keep `N8N_BASIC_AUTH_*` enabled for initial access; installer generates secrets if left as `change-me`.
- Set `N8N_HOST`/`N8N_PROTOCOL` to match the public n8n URL (used for webhooks).

## Notes
- `.env.*` files are not committed; only `.env.example` is tracked.
- `nginx/sites` is generated at render time; example vhosts live as `*.conf.example`.
- MySQL uses one container; dev/prod databases and users are created from `MYSQL_*_DEV/PROD` in `scripts/init-mysql.sh`.
