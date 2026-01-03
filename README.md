# Server Stack (Docker Compose)

A reproducible multi-app server stack for:
- Nginx reverse proxy + ACME HTTP-01 + Certbot
- Laravel (PHP-FPM)
- Separate Node builder container (Vite build)
- MySQL + Postgres
- n8n (optional, included)

## Goals
- Reproducible on a new server: clone → fill `.env` → bootstrap → up.
- Versioned images (no `latest`).
- Same service set for local/dev/prod; differences via `.env` + compose overrides.
- App code lives in separate repos; this repo only mounts app folders from the host.

## Non-goals
- This repo does not contain application source code.
- This repo does not implement a full CI/CD system (v1 focuses on reliability and simplicity).

## Design decisions (ours)
- Separate Node builder service (no Node inside PHP runtime).
- Explicit image tags; consider digest pinning if you need immutability.
- Server filesystem convention under `/srv`.

## Inspired by common patterns
- "Base compose + environment overrides" layout.
- Nginx + Certbot + ACME well-known mount.
- Idempotent bootstrap scripts.

## Quick start (new server)
1. Create folders:
   - `/srv/docker/server-stack` (this repo)
   - `/srv/apps/<app>/<env>/current` (your app repos)
2. Copy `.env.example` → `.env.dev` or `.env.prod` and edit values.
3. Bring up services:
   ```bash
   docker compose --env-file .env.dev -f docker-compose.yml -f docker-compose.server.yml up -d
   ```
4. First-time certificate issuance:
   ```bash
   ./scripts/first-time-certbot.sh
   ```

## Local run
```bash
docker compose --env-file .env.local -f docker-compose.yml -f docker-compose.local.yml up
```

## Deploy (dev)
```bash
./scripts/deploy-dev.sh exampleapp
```

## Notes
- Replace placeholder domains in `nginx/sites/*.conf`.
- Ensure `storage/` and `bootstrap/cache/` are writable by the PHP-FPM user inside the container.
