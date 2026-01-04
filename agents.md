# agents.md

This repository is a Docker Compose "server stack" used to run multiple applications on a single host.
It is designed to be reproducible: clone → configure env → install → run.

## Repository purpose
- Infrastructure only: Docker Compose, Nginx, Certbot, databases, optional n8n.
- Application code lives outside this repo and is mounted from the host.
- Separate dev and prod runtimes.
- Everything is version-pinned (no `latest`).

## Non-goals
- No application source code.
- No secrets committed.
- No full CI/CD platform.

## Key paths
- Stack repo: `/srv/docker/<stack-repo>`
- Apps: `/srv/apps/<app>/<env>/current`
- Let's Encrypt:
  - webroot: `/srv/letsencrypt/www`
  - certs: `/srv/letsencrypt/conf`

## Environments
- `.env.example` = documentation only
- `.env.dev`, `.env.prod` = real values, never committed
- Differences handled only via:
  - env files
  - compose overrides
  - generated nginx vhosts

## Scripts contracts
### install.sh
- Non-interactive
- Reads everything from `--env-file`
- Idempotent
- Installs system deps, Docker, firewall
- Creates `/srv` structure
- Clones public app repo via HTTPS
- Renders nginx configs
- Starts stack
- Requests initial TLS certs

### render-nginx.sh
- Deterministic template rendering
- Overwrites generated configs

### first-time-certbot.sh
- Requests certs for prod/dev (+ optional n8n)

### deploy.sh
- `deploy.sh dev|prod`
- Updates host-side repo
- Builds frontend via node builder
- Runs composer, migrations
- Fixes permissions

## Security rules
- Never commit secrets
- Keep ports minimal (22/80/443)
- Pin image versions

## Coding rules
- English only
- Shell scripts: `set -euo pipefail`
- Small, single-purpose scripts

## Acceptance checklist
- `docker compose config` works with `.env.example`
- Installer runs without prompts
- No secrets added to git
- Nginx vhosts generated correctly

## Codex playbook
- Summarize intent before changes
- Prefer minimal diffs
- Update README if behavior changes
- List verification commands
