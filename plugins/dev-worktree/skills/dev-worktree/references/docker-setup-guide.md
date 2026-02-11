# Docker Setup Guide for Worktree Compatibility

Declarative guide for making a Docker Compose project compatible with git worktrees. Apply only the sections relevant to the issues found in the readiness assessment.

## Principle

A worktree-compatible Docker config must produce **zero name or port collisions** when multiple instances run simultaneously via `docker compose -p <unique-name>`.

## Fix: Hardcoded Container Names

### Problem

```yaml
services:
  api:
    container_name: my-api    # Blocks parallel instances
  db:
    container_name: my-db     # Same problem
```

### Solution: Remove container_name

```yaml
services:
  api:
    # container_name removed — Compose auto-names as <project>-api-<n>
    build: ...
  db:
    # container_name removed
    image: postgres:17-alpine
```

**How it works:** Docker Compose generates container names as `<project_name>-<service>-<instance>`. With `--project-name wt1`, the API container becomes `wt1-api-1`. No collisions.

**Impact on existing workflows:**
- `docker exec my-api ...` → `docker compose exec api ...` (use service name, not container name)
- `docker logs my-api` → `docker compose logs api`
- Scripts referencing `container_name` must be updated to use `docker compose` commands instead

### Alternative: Parameterize (if container names are needed)

```yaml
services:
  api:
    container_name: ${COMPOSE_PROJECT_NAME:-my}-api
```

Add to `.env`: `COMPOSE_PROJECT_NAME=my`

**Downside:** More env vars to manage, easy to forget.

## Fix: Hardcoded Ports

### Problem

```yaml
services:
  api:
    ports:
      - "3000:3000"    # Collides with other worktrees
```

### Solution: Parameterize host ports

```yaml
services:
  api:
    ports:
      - "${API_PORT:-3000}:3000"    # Host port from env, container port fixed
```

Add to `.env.example`:
```bash
API_PORT=3000
```

**Rule:** Only the LEFT side (host port) needs parameterization. The RIGHT side (container port) stays fixed — it's internal to the container network.

### Common port variables pattern

```yaml
services:
  api:
    ports:
      - "${API_EXTERNAL_PORT:-3000}:3000"
  db:
    ports:
      - "${DATABASE_EXTERNAL_PORT:-5432}:5432"
  redis:
    ports:
      - "${REDIS_EXTERNAL_PORT:-6379}:6379"
```

## Fix: Missing .env.example

### Create .env.example

Extract all env var references from docker-compose:

```bash
grep -oP '\$\{(\w+)' docker-compose.yml | sort -u | sed 's/\${//'
```

Create `.env.example` with all variables and sensible defaults:

```bash
# Ports (change these for worktree isolation)
API_EXTERNAL_PORT=3000
DATABASE_EXTERNAL_PORT=5432
REDIS_EXTERNAL_PORT=6379

# Database
DATABASE_USER=postgres
DATABASE_PASSWORD=postgres
DATABASE_NAME=myapp
DATABASE_URL="postgresql://${DATABASE_USER}:${DATABASE_PASSWORD}@localhost:${DATABASE_EXTERNAL_PORT}/${DATABASE_NAME}"

# Other config...
```

**Group port variables together** with a comment noting they're for worktree isolation.

## Fix: External Volumes

### Problem

```yaml
volumes:
  db-data:
    external: true    # Shared across all compose projects
```

### Solution: Remove external flag

```yaml
volumes:
  db-data:    # Compose auto-prefixes: <project>_db-data
```

Each worktree's compose project creates its own volume: `wt1_db-data`, `wt2_db-data`.

## Fix: External Networks

### Problem

```yaml
networks:
  shared:
    external: true    # Allows cross-communication
```

### Solution: Remove external flag or scope the name

```yaml
networks:
  app-net:    # Each compose project gets its own isolated network
```

## Fix: Host-Path Volume Mounts

### Problem

```yaml
services:
  api:
    volumes:
      - /absolute/path/to/data:/data    # Same path for all worktrees
```

### Solution: Use relative paths

```yaml
services:
  api:
    volumes:
      - .:/app    # Relative to compose file location (worktree root)
      - ./data:/data
```

Relative paths resolve from the docker-compose.yml location, which is different per worktree.

## Verification

After applying fixes, verify:

```bash
# 1. No hardcoded container names
grep 'container_name:' docker-compose.yml  # Should return nothing

# 2. All ports parameterized
grep -E '"[0-9]+:' docker-compose.yml  # Should return nothing (all use ${VAR})

# 3. No external volumes/networks
grep 'external: true' docker-compose.yml  # Should return nothing

# 4. .env.example has port vars
grep 'PORT' .env.example  # Should list all port variables
```

## Applying Changes

When presenting changes to user, show a diff-style summary:

```
Changes needed in docker-compose.yml:
  - Remove container_name: my-api (line 4)
  - Remove container_name: my-db (line 15)
  - Remove container_name: my-redis (line 25)

Changes needed in .env.example:
  + Add API_EXTERNAL_PORT=3000
  + Add note about worktree isolation

Shall I apply these changes?
```

Always get user confirmation before modifying tracked files.
