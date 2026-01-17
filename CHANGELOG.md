# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Generatemedia File Uploads** - Increase nginx upload limit to 10MB
  - Added `client_max_body_size 10M;` to generatemedia nginx vhost
  - Previously limited to 1MB (nginx default) despite app supporting 10MB
  - Aligns nginx configuration with application upload limits

### Planned
- Automated backup script for databases
- Health check dashboard
- Log aggregation solution

## [1.3.0] - 2026-01-17

### Added
- **Generatemedia App Support** - Complete integration for Next.js + BullMQ application
  - Docker Compose services: `generatemedia_web`, `generatemedia_worker`
  - Redis service for BullMQ job queue
  - Dedicated PostgreSQL database for generatemedia
  - Nginx vhost template for generatemedia subdomain
  - Custom Next.js Dockerfile with standalone output support
  - Deployment script: `scripts/deploy-generatemedia.sh`

- **Documentation**
  - CHANGELOG.md (this file)
  - Comprehensive generatemedia integration guide in README.md
  - Troubleshooting section for Next.js + Prisma issues

### Fixed
- **Next.js Dockerfile** - Fixed multiple critical issues for production builds:
  - Ensure `public` directory exists even if empty (Next.js requires it)
  - Copy `src` directory and `node_modules` for worker process (tsx runtime needs source files)
  - Remove invalid shell redirection syntax from COPY commands

- **Prisma Compatibility**
  - Switch from Alpine to Debian-based Node image (Prisma requires glibc)
  - Install OpenSSL in Debian image (Prisma requires libssl)
  - Add Prisma schema to Docker image for migrations
  - Fix OpenSSL 1.1 compatibility issues on Alpine Linux

- **Nginx Certificate Detection**
  - Check certificates via nginx container instead of host filesystem
  - Fixes issue where cert detection failed in containerized environment

- **Environment Configuration**
  - Use app-specific `.env` file for application API keys
  - Infrastructure variables stay in stack `.env.dev`
  - Prevents secrets from being committed to stack repo

### Changed
- **Next.js Image Strategy**
  - Moved from Alpine to Debian-based Node 20 for full Prisma compatibility
  - Multi-stage build with standalone output (optimized for production)
  - Separate web and worker containers using same image (different commands)

### Removed
- Obsolete `nginx/sites/00-acme.conf` (replaced by template-based generation)

### Lessons Learned

**For Future App Integrations:**

1. **Next.js Applications**
   - Always create `public` directory in Dockerfile, even if empty
   - Use `output: "standalone"` in `next.config.js` for production
   - For workers: Copy `src` and `node_modules` (tsx needs source files)
   - Multi-stage build: deps → builder → runner pattern

2. **Prisma ORM**
   - Requires Debian-based image (Alpine lacks glibc)
   - Must install OpenSSL in runtime image
   - Copy `prisma/schema.prisma` to image for migrations
   - Run `prisma generate` during build
   - Prisma warns about OpenSSL but works with manual install

3. **BullMQ Workers**
   - Run as separate container with same image
   - Command: `npm run worker` (defined in package.json)
   - Needs Redis connection
   - Monitor with `docker logs generatemedia_worker`

4. **Environment Variables**
   - Stack variables: Infrastructure (DB, Redis URLs)
   - App variables: API keys, app-specific config
   - Use `env_file` in compose to load app `.env`
   - Never commit secrets to either repo

5. **Nginx Certificate Detection**
   - Check certs from inside nginx container, not host
   - Path: `/etc/letsencrypt/live/${DOMAIN}/fullchain.pem`
   - Host filesystem may differ from container view

6. **Docker Build Context**
   - Build from app directory, reference Dockerfile in stack repo
   - Example: `docker build -f /srv/docker/stack/docker/nextjs/Dockerfile .`
   - Ensures correct paths for COPY commands

## [1.2.0] - 2026-01-11

### Added
- **Claude CLI Container** - AI-assisted development container
  - Debian-based image with Docker CLI
  - Access to all app code via volume mounts
  - Docker socket access for container control
  - Helper script: `scripts/claude.sh`
  - Documentation in CLAUDE.md

- **Todomap Database** - PostgreSQL database for todomap app
  - Environment variables for todomap DB configuration
  - Database initialization in Postgres init script

### Security
- Claude CLI container has privileged access (Docker socket)
- Only for authorized developers with SSH access
- API keys should be set per-session, not in .env files

## [1.1.0] - 2026-01-07

### Added
- Docker Compose wrapper script: `scripts/dc.sh`
- Ensures correct env files and compose files are used
- Prevents accidental container recreation without volumes

### Changed
- **CRITICAL:** All Docker Compose commands must use `./scripts/dc.sh`
- Running `docker compose` directly will cause 502 errors (volume mounts missing)

### Documentation
- Added DOCKER_USAGE.md with common commands
- Updated README with Docker Compose usage warnings

## [1.0.0] - 2026-01-04

### Added
- Initial release of multi-app Docker Compose stack
- **Services:**
  - Nginx reverse proxy with automatic HTTPS
  - Certbot for Let's Encrypt certificates
  - PHP-FPM for Laravel (separate dev/prod containers)
  - Node.js builders for Vite (separate dev/prod)
  - MySQL database
  - PostgreSQL database
  - n8n workflow automation (optional)

- **Infrastructure Scripts:**
  - `install.sh` - Non-interactive server setup
  - `deploy.sh` - Application deployment
  - `render-nginx.sh` - Nginx vhost generation from templates
  - `reload-nginx.sh` - Graceful nginx reload
  - `first-time-certbot.sh` - Initial certificate request
  - `health-check.sh` - Stack health verification

- **Custom Docker Images:**
  - PHP-FPM 8.5.1 with extensions (gd, intl, pdo_mysql, zip)
  - Composer 2.8.7 with same PHP extensions
  - All images version-pinned

- **Security:**
  - UFW firewall (ports 22/80/443)
  - Separate databases for dev/prod environments
  - Certificate storage with restricted permissions

- **Documentation:**
  - Comprehensive README.md
  - agents.md for development guidelines
  - CONTRIBUTING.md
  - .env.example with all configuration options

### Architecture
- Multi-environment design (dev + prod)
- App code lives outside stack repo
- Volume mounts from `/srv/apps/<app>/<env>/current`
- Generated nginx configs (not committed)
- Environment-specific overrides via compose files

---

## Version History Format

Each version entry should include:

### [Version] - YYYY-MM-DD

#### Added
- New features or functionality

#### Changed
- Changes to existing functionality

#### Deprecated
- Features that will be removed in future versions

#### Removed
- Features that have been removed

#### Fixed
- Bug fixes

#### Security
- Security vulnerability fixes

#### Lessons Learned
- Important insights for future development

---

**Note:** This changelog documents the infrastructure stack. Individual applications (wwerp, generatemedia, todomap) have their own changelogs in their respective repositories.

**Maintenance:** When making changes to the stack, always update this changelog under `[Unreleased]`. Before releasing, move changes to a new version section with the release date.
