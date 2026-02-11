# Environment Configuration for Worktrees

How to generate isolated `.env` files for each worktree with unique ports and database names.

## Port Allocation Strategy

### Offset-Based Allocation

Each worktree gets an **index** (1, 2, 3...) and a corresponding **port offset**.

```
Index = (number of existing worktrees) + 1
Offset = Index * 100
Worktree port = Base port + Offset
```

### Example

Given base ports in `.env.example`:
```
API_EXTERNAL_PORT=5000
DATABASE_EXTERNAL_PORT=5432
REDIS_EXTERNAL_PORT=6379
REDIS_DASHBOARD_PORT=8001
```

| Env | Main | WT-1 (+100) | WT-2 (+200) |
|-----|------|-------------|-------------|
| API_EXTERNAL_PORT | 5000 | 5100 | 5200 |
| DATABASE_EXTERNAL_PORT | 5432 | 5532 | 5632 |
| REDIS_EXTERNAL_PORT | 6379 | 6479 | 6579 |
| REDIS_DASHBOARD_PORT | 8001 | 8101 | 8201 |

### Determining the Index

```bash
# Count non-main worktrees
existing=$(git worktree list | grep -cv "$(git rev-parse --show-toplevel)$")
index=$((existing + 1))
offset=$((index * 100))
```

### Port Conflict Detection

Before applying offsets, verify no conflicts:

```bash
# Check if port is already in use
ss -tlnp | grep :<port> || echo "Port <port> available"
```

If a conflict is found, increment the index and recalculate.

## Generating the .env File

### Step 1: Identify port variables

Scan `.env` or `.env.example` for variables containing `PORT`:

```bash
grep -E '^[A-Z_]*PORT[A-Z_]*=' .env.example
```

### Step 2: Copy and modify

```bash
cp .env .worktrees/<slug>/.env
```

For each port variable, calculate the new value:
```
new_value = original_value + offset
```

Apply replacements in the worktree's `.env`.

### Step 3: Recalculate compound variables

Variables that embed ports (like `DATABASE_URL`) need recalculation.

**Identify compound variables:**

```bash
grep -E '(localhost|127\.0\.0\.1):[0-9]+' .env.example
```

Common patterns:
```
DATABASE_URL="postgresql://user:pass@localhost:${DATABASE_EXTERNAL_PORT}/dbname"
REDIS_URL="redis://localhost:${REDIS_EXTERNAL_PORT}"
```

If the URL is constructed from individual variables (using `${VAR}` syntax), changing the port variable is sufficient. If the URL has a hardcoded port, replace it directly.

### Step 4: Database name isolation

Change the database name to prevent sharing:

```
DATABASE_NAME=myapp → DATABASE_NAME=myapp_wt<index>
```

Rebuild `DATABASE_URL` if it contains the database name.

## Docker-Internal vs Host Ports

**Important distinction:**

- **Host ports** (left side of port mapping) → MUST be unique per worktree
- **Container-internal ports** (right side) → stay the same, no conflicts
- **Container-to-container URLs** (e.g., `DATABASE_URL_DOCKER`) → use service names and internal ports, NOT host ports

Example:
```bash
# Host access (from your terminal, IDE, etc.)
DATABASE_URL="postgresql://postgres:postgres@localhost:5532/myapp_wt1"

# Container-to-container (used inside Docker network)
DATABASE_URL_DOCKER="postgresql://postgres:postgres@db:5432/myapp_wt1"
```

Only the **database name** changes in container-to-container URLs. The port stays at the internal default because containers communicate through Docker's internal network.

## Compose Project Name

Set a unique project name for each worktree:

```bash
# Derive from branch slug
project_name="$(basename $(git rev-parse --show-toplevel))-wt${index}"
# Example: gm-platform-api-wt1
```

Or use a shorter form:
```bash
project_name="gm-wt${index}"
```

The project name is used in ALL compose commands:
```bash
docker compose -p gm-wt1 up -d
docker compose -p gm-wt1 logs api
docker compose -p gm-wt1 down -v
```

## Override File (if needed)

If the readiness assessment passed but some overrides are still needed per-worktree, generate `docker-compose.worktree.yml`:

```yaml
# Auto-generated for worktree isolation. Do not commit.
services:
  api:
    environment:
      - WORKTREE_INDEX=1
```

Usage:
```bash
docker compose -f docker-compose.yml -f docker-compose.worktree.yml -p gm-wt1 up -d
```

Add `docker-compose.worktree.yml` to `.gitignore`.

## File Summary

For each worktree, generate:

| File | Location | Purpose |
|------|----------|---------|
| `.env` | Worktree root | Port-adjusted env vars |
| `docker-compose.worktree.yml` | Worktree root (optional) | Additional overrides |

Both files are untracked (in `.gitignore`) and removed during teardown.
