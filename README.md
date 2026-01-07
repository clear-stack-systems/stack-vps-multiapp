# Docker Compose Server Stack

A reproducible multi-app server stack for:
- Nginx reverse proxy (HTTP/HTTPS)
- ACME HTTP-01 + Certbot
- Laravel (PHP-FPM) for dev and prod (separate runtimes)
- Separate Node builder containers (Vite build) for dev/prod
- MySQL + Postgres
- n8n (optional, included)

## ⚠️ IMPORTANT: Using Docker Compose

**ALWAYS use the helper script** for docker compose commands:
```bash
./scripts/dc.sh [commands]
```

See [DOCKER_USAGE.md](./DOCKER_USAGE.md) for details and common commands.

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
- PHP-FPM is built locally from `docker/php-fpm/Dockerfile` (extensions: gd, intl, pdo_mysql, zip; base PHP 8.5.1).
- Composer runs in a separate container built from `docker/composer/Dockerfile` (same extensions as PHP-FPM).

## Optional: n8n
- Set `DOMAIN_N8N` to a real DNS name to enable the n8n vhost and certificate.
- Keep `N8N_BASIC_AUTH_*` enabled for initial access; installer generates secrets if left as `change-me`.
- Set `N8N_HOST`/`N8N_PROTOCOL` to match the public n8n URL (used for webhooks).

## Claude CLI Container

The stack includes a Claude CLI container for AI-assisted development and operations.

### Initial Setup

1. Set your Anthropic API key:
   ```bash
   docker exec -it claude_cli bash
   export ANTHROPIC_API_KEY="your-key-here"
   # Or add to ~/.bashrc for persistence
   echo 'export ANTHROPIC_API_KEY="your-key"' >> ~/.bashrc
   ```

2. Verify installation:
   ```bash
   docker exec -it claude_cli claude --version
   ```

### Usage

**Interactive Shell**:
```bash
docker exec -it claude_cli bash
```

**Direct Commands**:
```bash
docker exec -it claude_cli claude chat
```

**Using Helper Script**:
```bash
./scripts/claude.sh              # Open shell
./scripts/claude.sh chat         # Start chat
```

### Capabilities

The Claude CLI container can:
- Access all app code in `/srv/apps`
- Control other containers via docker socket
- Exec into other containers for inspection/modification
- Communicate with stack services via network
- Read compose configuration in `/stack`

### Common Workflows

**Inspect running services**:
```bash
docker exec -it claude_cli bash
docker ps
docker logs nginx
```

**Modify app code**:
```bash
docker exec -it claude_cli bash
cd /srv/apps/wwerp/dev/current
# Use claude CLI to make changes
```

**Exec into other containers**:
```bash
docker exec -it claude_cli bash
docker exec -it wwerp_php_dev bash
```

### Security Notes

- The Claude CLI container has Docker socket access (`/var/run/docker.sock`), providing root-equivalent access to the host
- Only authorized users with SSH/sudo access should use this container
- API keys should be set per-session; do not store them in .env files
- Changes to app code should be committed and reviewed

## Notes
- `.env.*` files are not committed; only `.env.example` is tracked.
- `nginx/sites` is generated at render time; example vhosts live as `*.conf.example`.
- MySQL uses one container; dev/prod databases and users are created from `MYSQL_*_DEV/PROD` in `scripts/init-mysql.sh`.
- Nginx serves static assets from host-mounted app paths (`APP_PATH_DEV` -> `/var/www/app_dev`, `APP_PATH_PROD` -> `/var/www/app_prod`), while PHP-FPM reads code from `/var/www/app`.
