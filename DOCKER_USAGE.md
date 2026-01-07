# Docker Compose Usage Guide

## ⚠️ CRITICAL: Always Use the Helper Script

**DO NOT** run `docker compose` directly. **ALWAYS** use the helper script:

```bash
./scripts/dc.sh [commands]
```

### Why?

Running `docker compose` without the correct flags will recreate containers **without volumes**, causing the Laravel app to break (502 errors).

## Common Commands

### Start services
```bash
./scripts/dc.sh up -d
```

### Restart a service
```bash
./scripts/dc.sh restart app_dev
```

### View logs
```bash
./scripts/dc.sh logs -f app_dev
```

### Stop services
```bash
./scripts/dc.sh down
```

### Execute commands in containers
```bash
./scripts/dc.sh exec app_dev php artisan migrate
```

## If You Accidentally Run Without the Script

If you ran `docker compose up` directly and the site shows 502 errors:

1. Check if volumes are mounted:
   ```bash
   docker exec wwerp_php_dev ls /var/www/app/artisan
   ```

2. If file not found, recreate containers properly:
   ```bash
   ./scripts/dc.sh up -d app_dev app_prod
   docker restart nginx
   ```

## Healthcheck

The PHP containers now have a healthcheck that verifies the Laravel files are mounted:
```bash
docker ps
```

Look for `(healthy)` or `(unhealthy)` status. If unhealthy, volumes aren't mounted correctly.
