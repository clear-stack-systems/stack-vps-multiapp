# AGENTS.MD

Guidelines for AI agents (like Claude Code) working on this Docker Compose stack infrastructure.

## Overview

This repository is a Docker Compose-based server stack for hosting multiple applications on a single VPS. It provides infrastructure only - application code lives in separate repositories and is mounted from the host.

**Key Principle:** Infrastructure as code - reproducible, version-pinned, environment-agnostic.

## Repository Purpose

### What This Repo Contains
- Docker Compose configuration
- Nginx reverse proxy setup
- Certbot for automatic HTTPS
- Database services (MySQL, PostgreSQL)
- Custom Docker images (PHP-FPM, Composer, Claude CLI)
- Deployment and management scripts
- Nginx vhost templates
- Documentation

### What This Repo Does NOT Contain
- Application source code (lives in `/srv/apps/`)
- Secrets or credentials (use `.env` files, never committed)
- Application-specific logic
- CI/CD pipelines

## Core Principles

1. **Reproducible Setup** - Clone → Configure → Install → Run
2. **Version Pinning** - No `latest` tags, all images version-pinned
3. **Environment Separation** - Dev and prod use same services, different configs
4. **App Code Outside** - Apps are git repos mounted from host
5. **Generated Configs** - Nginx vhosts generated from templates
6. **No Committed Secrets** - All secrets in `.env` files (gitignored)

## Key Paths

```
/srv/docker/stack-vps-multiapp/    # This repo
/srv/apps/<app>/<env>/current/     # App code
/srv/letsencrypt/www/              # ACME challenge webroot
/srv/letsencrypt/conf/             # Certificate storage
```

## Before Starting Any Task

### 1. Understand the Current State

```bash
# Read the README
cat README.md

# Check recent changes
git log --oneline -10

# Review changelog
cat CHANGELOG.md

# Check current environment
cat .env.dev

# Verify docker compose config
./scripts/dc.sh config
```

### 2. Identify Scope

- Is this infrastructure change or app change?
- Which environment (dev/prod/both)?
- Does it require new containers or just config?
- Will it affect certificates?
- Does it need database changes?

### 3. Plan Changes

- Use TodoWrite tool for multi-step tasks
- Identify which files need changes
- Consider rollback strategy
- Plan testing approach

## Making Infrastructure Changes

### Docker Compose Changes

**When modifying `docker-compose.yml`:**

1. **Test configuration:**
   ```bash
   ./scripts/dc.sh config
   ```

2. **Check for syntax errors:**
   ```bash
   docker compose -f docker-compose.yml config
   ```

3. **Verify services start:**
   ```bash
   ./scripts/dc.sh up -d
   docker ps
   ```

**DO:**
- ✅ Pin all image versions (`nginx:1.29.4-alpine`, not `nginx:latest`)
- ✅ Use environment variables for configuration
- ✅ Add health checks for critical services
- ✅ Use volume mounts for persistent data
- ✅ Set restart policies (`unless-stopped`)
- ✅ Use networks for service isolation

**DON'T:**
- ❌ Use `latest` tags
- ❌ Hardcode values that differ between environments
- ❌ Add secrets directly in compose files
- ❌ Remove volume mounts without understanding impact
- ❌ Change service names (breaks existing deployments)

### Script Changes

**All scripts must:**
- Start with `#!/usr/bin/env bash`
- Use `set -euo pipefail` (fail fast)
- Accept `--env-file` parameter
- Be idempotent (safe to re-run)
- Have clear error messages
- Exit with appropriate codes (0=success, 1=error)

**Example script structure:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Parse arguments
ENV_FILE="${1:-.env.dev}"

# Validate
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_FILE not found"
  exit 1
fi

# Load environment
set -a
source "$ENV_FILE"
set +a

# Main logic
echo "Doing something with $DOMAIN_PROD"

# Success
echo "✓ Done"
exit 0
```

### Nginx Configuration

**When adding new apps:**

1. **Create template** in `nginx/templates/`:
   ```bash
   cp nginx/templates/app.example.com.tmpl nginx/templates/yourapp.example.com.tmpl
   ```

2. **Update template** with app-specific config:
   - Upstream port
   - Domain placeholder
   - Special location blocks
   - WebSocket support (if needed)

3. **Test rendering:**
   ```bash
   ./scripts/render-nginx.sh .env.dev
   cat nginx/sites/yourapp.jenyn.com.conf
   ```

4. **Test nginx config:**
   ```bash
   docker exec nginx nginx -t
   ```

5. **Reload nginx:**
   ```bash
   ./scripts/reload-nginx.sh
   ```

**Important nginx patterns:**

- Use `proxy_pass http://container_name:port` (not localhost)
- Set proper headers for forwarded requests
- Add WebSocket support if app needs it:
  ```nginx
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
  ```

### Database Changes

**Adding new databases:**

1. **Update init scripts:**
   - MySQL: `scripts/init-mysql.sh`
   - PostgreSQL: `scripts/init-postgres.sh`

2. **Add environment variables:**
   ```bash
   MYAPP_DB_NAME=myapp
   MYAPP_DB_USER=myapp
   MYAPP_DB_PASS=change-me
   ```

3. **Restart database to trigger init:**
   ```bash
   ./scripts/dc.sh restart postgres
   # or
   ./scripts/dc.sh restart mysql
   ```

4. **Verify database created:**
   ```bash
   docker exec postgres psql -U app -d app -c "\l"
   docker exec mysql mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SHOW DATABASES;"
   ```

### Custom Docker Images

**When modifying Dockerfiles:**

1. **Build locally:**
   ```bash
   docker build -t stack-myimage:1.0.0 -f docker/myimage/Dockerfile docker/myimage/
   ```

2. **Test the image:**
   ```bash
   docker run --rm -it stack-myimage:1.0.0 bash
   ```

3. **Update compose file** with new image name/tag

4. **Document the change** in CHANGELOG.md

**Version pinning rules:**
- Base images: Use specific versions (`FROM node:20.11.0-alpine3.19`)
- Packages: Pin versions where possible (`RUN apk add --no-cache openssl=3.1.4-r0`)
- Update `.env.example` with new image variables

## Adding New Applications

### Lessons Learned from Generatemedia Integration

Follow these steps when adding a new application to the stack:

#### 1. Identify App Requirements

- **Runtime:** Node.js? PHP? Python?
- **Database:** PostgreSQL? MySQL? Both?
- **Queue:** Redis + BullMQ? Other?
- **Build process:** Next.js? Vite? Webpack?
- **Workers:** Background jobs? Separate container?

#### 2. Create Dockerfile (If Custom)

**For Next.js apps:**

```dockerfile
# Multi-stage build
FROM node:20-slim AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --production=false

FROM node:20-slim AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# ⚠️ IMPORTANT: Create public directory even if empty
RUN mkdir -p /app/public

FROM node:20-slim AS runner
WORKDIR /app
ENV NODE_ENV=production

# ⚠️ For Prisma: Install OpenSSL
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

# Copy built application
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

# ⚠️ For workers: Copy source files and node_modules (tsx needs them)
COPY --from=builder /app/src ./src
COPY --from=builder /app/node_modules ./node_modules

# ⚠️ For Prisma: Copy schema for migrations
COPY --from=builder /app/prisma ./prisma

CMD ["node", "server.js"]
```

**Key lessons:**
1. **Always create public directory** - Next.js fails without it
2. **Use Debian-based Node image** - Prisma requires glibc (Alpine uses musl)
3. **Install OpenSSL** - Prisma needs libssl
4. **Copy src + node_modules** - Workers using tsx need source files
5. **Copy Prisma schema** - Needed for running migrations in production

#### 3. Add to Docker Compose

```yaml
services:
  myapp_web:
    build:
      context: ${MYAPP_PATH}
      dockerfile: /srv/docker/stack-vps-multiapp/docker/myframework/Dockerfile
    image: ${MYAPP_IMAGE}
    container_name: myapp_web
    restart: unless-stopped
    env_file:
      - ${MYAPP_PATH}/.env
    environment:
      TZ: ${TZ}
      DATABASE_URL: postgresql://${MYAPP_DB_USER}:${MYAPP_DB_PASS}@postgres:5432/${MYAPP_DB_NAME}
    depends_on:
      - postgres
    expose:
      - "3000"
    networks: [stack]

  # If app needs worker
  myapp_worker:
    image: ${MYAPP_IMAGE}
    container_name: myapp_worker
    restart: unless-stopped
    command: ["npm", "run", "worker"]
    env_file:
      - ${MYAPP_PATH}/.env
    environment:
      TZ: ${TZ}
      DATABASE_URL: postgresql://${MYAPP_DB_USER}:${MYAPP_DB_PASS}@postgres:5432/${MYAPP_DB_NAME}
      REDIS_URL: redis://redis:6379
    depends_on:
      - postgres
      - redis
      - myapp_web
    networks: [stack]
```

**Key points:**
- Use `env_file` to load app-specific `.env` (API keys)
- Use `environment` for infrastructure variables (DB URLs)
- Use `expose` not `ports` (nginx proxies internally)
- Set proper `depends_on` for startup order
- Use container names for service discovery

#### 4. Environment Variable Strategy

**Stack `.env.dev`** (Infrastructure):
```bash
# Domain
DOMAIN_MYAPP=myapp.jenyn.com

# App location
MYAPP_APP_REPO=https://github.com/org/myapp.git
MYAPP_APP_PATH=/srv/apps/myapp/current
MYAPP_IMAGE=stack-myapp:latest

# Database (auto-generated by installer)
MYAPP_DB_NAME=myapp
MYAPP_DB_USER=myapp
MYAPP_DB_PASS=change-me

# Public URL (for webhooks)
MYAPP_PUBLIC_BASE_URL=https://myapp.jenyn.com
```

**App `.env`** (Application-specific):
```bash
# External API keys
EXTERNAL_API_KEY=your-key-here
EXTERNAL_API_MODEL=model-name

# Note: DATABASE_URL, REDIS_URL injected by docker-compose
```

**Why separate:**
- Stack variables: Infrastructure, safe to commit `.env.example`
- App variables: Secrets, never committed anywhere
- Stack can be cloned without exposing app secrets

#### 5. Create Deployment Script

```bash
#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-.env.dev}"

# Load environment
set -a
source "$ENV_FILE"
set +a

echo "Deploying ${MYAPP_APP_REPO} to ${MYAPP_APP_PATH}..."

# Pull latest code
cd "${MYAPP_APP_PATH}"
git pull origin main

# Build Docker image
docker build -t "${MYAPP_IMAGE}" \
  -f /srv/docker/stack-vps-multiapp/docker/myframework/Dockerfile .

# Run migrations (if applicable)
docker run --rm \
  --network stack_net \
  -e DATABASE_URL="postgresql://${MYAPP_DB_USER}:${MYAPP_DB_PASS}@postgres:5432/${MYAPP_DB_NAME}" \
  "${MYAPP_IMAGE}" \
  npx prisma migrate deploy

# Restart services
cd /srv/docker/stack-vps-multiapp
./scripts/dc.sh up -d --force-recreate myapp_web myapp_worker

echo "✓ Deployed ${MYAPP_IMAGE}"
```

#### 6. Update Installer Script

Add to `scripts/install.sh`:

```bash
# Clone myapp repo
if [[ ! -d "${MYAPP_APP_PATH}" ]]; then
  git clone "${MYAPP_APP_REPO}" "${MYAPP_APP_PATH}"
fi

# Create database
docker exec postgres psql -U app -d app -c "
  CREATE DATABASE ${MYAPP_DB_NAME};
  CREATE USER ${MYAPP_DB_USER} WITH PASSWORD '${MYAPP_DB_PASS}';
  GRANT ALL PRIVILEGES ON DATABASE ${MYAPP_DB_NAME} TO ${MYAPP_DB_USER};
"

# Render nginx vhost
./scripts/render-nginx.sh "$ENV_FILE"

# Request certificate
docker compose run --rm certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  --email "${CERTBOT_EMAIL}" \
  --agree-tos \
  --no-eff-email \
  -d "${DOMAIN_MYAPP}"
```

#### 7. Test Checklist

- [ ] Docker Compose config valid: `./scripts/dc.sh config`
- [ ] Services start: `docker ps | grep myapp`
- [ ] Database created: `docker exec postgres psql -U app -c "\l"`
- [ ] Nginx config valid: `docker exec nginx nginx -t`
- [ ] HTTPS works: `curl -I https://myapp.jenyn.com`
- [ ] Application responds: `curl https://myapp.jenyn.com/api/health`
- [ ] Worker processes jobs: Check logs
- [ ] Webhooks work: Test with curl

## Common Patterns

### Adding a New Service

1. Add service definition to `docker-compose.yml`
2. Add environment variables to `.env.example`
3. Update `README.md` with service documentation
4. Update `CHANGELOG.md` under `[Unreleased]`
5. Test with `./scripts/dc.sh up -d`

### Modifying Nginx Config

1. Edit template in `nginx/templates/`
2. Render config: `./scripts/render-nginx.sh .env.dev`
3. Test config: `docker exec nginx nginx -t`
4. Reload nginx: `./scripts/reload-nginx.sh`
5. Test endpoint: `curl -I https://domain.com`

### Updating Docker Images

1. Modify Dockerfile
2. Update version in `.env.example`
3. Build: `docker build -t image:version .`
4. Test: `docker run --rm -it image:version`
5. Update compose file with new tag
6. Restart services: `./scripts/dc.sh up -d`

## Documentation Requirements

### When to Update README.md

Update when you:
- Add new services to Docker Compose
- Add new scripts
- Change deployment procedures
- Add new environment variables
- Change nginx configuration patterns
- Add new dependencies

### When to Update CHANGELOG.md

**ALWAYS** update CHANGELOG.md for infrastructure changes.

Add under `[Unreleased]`:
```markdown
## [Unreleased]

### Added
- New service: myapp_web and myapp_worker containers

### Fixed
- Nginx certificate detection now checks inside container

### Changed
- Switch from Alpine to Debian for Prisma compatibility
```

### When to Update AGENTS.md

Update when:
- Learning new patterns (add to "Lessons Learned")
- Discovering common pitfalls
- Establishing new conventions
- Changing development workflow

## Committing Changes

### Commit Workflow

1. **Review changes:**
   ```bash
   git status
   git diff
   ```

2. **Update documentation:**
   - README.md (if behavior changed)
   - CHANGELOG.md (always for infrastructure changes)
   - AGENTS.md (if lessons learned)

3. **Stage changes:**
   ```bash
   git add docker-compose.yml
   git add README.md
   git add CHANGELOG.md
   ```

4. **Create commit:**
   ```bash
   git commit -m "Brief summary (50 chars)

   Detailed explanation:
   - What changed
   - Why it changed
   - How to use the change
   - Breaking changes (if any)

   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
   ```

### Commit Message Format

**Good:**
```
Add Prisma support to Next.js Dockerfile

- Install OpenSSL in Debian image (Prisma requires libssl)
- Switch from Alpine to Debian-based Node 20 (Prisma needs glibc)
- Copy Prisma schema to image for migrations
- Add npm scripts for database operations

This fixes generation failures where Prisma couldn't connect to
PostgreSQL due to missing system libraries.
```

**Bad:**
```
Fixed stuff
Update docker
WIP
```

## Pushing Changes

### Before Pushing

**ALWAYS ask the user:**

```
I've completed these changes:
- Added myapp integration to docker-compose.yml
- Created deployment script: scripts/deploy-myapp.sh
- Updated README.md with myapp documentation
- Updated CHANGELOG.md with v1.4.0 changes

Commits:
- [abc123] Add myapp integration
- [def456] Update documentation

Would you like me to push these changes to GitHub?
```

**Wait for approval**, then:
```bash
git push origin main
```

## Debugging

### Container Not Starting

```bash
# Check logs
docker logs container_name --tail 100

# Check if port is in use
docker exec container_name netstat -tuln | grep PORT

# Check health status
docker inspect container_name | grep -A 10 Health

# Check environment variables
docker exec container_name env
```

### Database Connection Issues

```bash
# Check database exists
docker exec postgres psql -U app -c "\l"
docker exec mysql mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SHOW DATABASES;"

# Test connection from app container
docker exec myapp_web psql "$DATABASE_URL" -c "SELECT 1;"

# Check network
docker network inspect stack_net
```

### Nginx Issues

```bash
# Test config
docker exec nginx nginx -t

# Check logs
docker logs nginx --tail 50

# Check upstream connectivity
docker exec nginx wget -O- http://myapp_web:3000/health

# Reload config
./scripts/reload-nginx.sh
```

### Certificate Issues

```bash
# Check certificate exists
docker exec nginx ls -la /etc/letsencrypt/live/domain.com/

# Re-request certificate
docker compose run --rm certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  -d domain.com

# Re-render nginx configs
./scripts/render-nginx.sh .env.dev
./scripts/reload-nginx.sh
```

## Emergency Procedures

### Rollback Deployment

```bash
# Check recent commits
git log --oneline -10

# Revert to previous commit
git checkout <commit-hash>

# Rebuild and restart
docker compose build myapp_web
./scripts/dc.sh up -d --force-recreate myapp_web myapp_worker
```

### Restore from Backup

```bash
# Restore database
docker exec -i postgres psql -U app -d myapp < backup.sql

# Restore app files
rsync -av backup/apps/ /srv/apps/
```

## Summary Checklist

Before finishing any work:

- [ ] All changes tested locally
- [ ] Docker Compose config validates
- [ ] Services start successfully
- [ ] Nginx config is valid
- [ ] README.md updated (if needed)
- [ ] CHANGELOG.md updated (always for infra changes)
- [ ] AGENTS.md updated (if lessons learned)
- [ ] Commit messages are clear
- [ ] Asked user for permission to push
- [ ] Changes documented for future reference

---

**Remember:** This is infrastructure code. Bugs here affect ALL applications. Test thoroughly, document well, and ask when uncertain.
