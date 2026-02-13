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

## Feature Minimization (YAGNI Mode)

After copying `.env` and applying port offsets, minimize the worktree environment by disabling features and commenting out external service credentials.

### Why

- Prevents resource conflicts between worktrees (shared webhooks, S3, queues)
- Reduces startup failures from missing/shared API keys in non-essential modules
- Keeps worktree environment focused on the current task

### Step 1: Add YAGNI header

Insert at the top of the worktree `.env`:

```
# ⚠ YAGNI MODE: Features disabled, external keys commented out.
# Search for "# [YAGNI]" to find commented-out secrets.
# To re-enable a feature: set ENABLE_X=true and uncomment related keys.
```

### Step 2: Disable feature toggles

Scan the `.env` for boolean toggle variables and set them to `false`:

```bash
# Match patterns: ENABLE_*, FEATURE_*, USE_*, *_ENABLED, *_MODULE
# Only change if current value is true, 1, or yes (case-insensitive)
grep -iE '^(ENABLE_|FEATURE_|USE_)\w+=\s*(true|1|yes)' .env
grep -iE '^\w+_(ENABLED|MODULE)=\s*(true|1|yes)' .env
```

For each match, set the value to `false`.

**Example:**
```
ENABLE_STRIPE=true        →  ENABLE_STRIPE=false
FEATURE_WEBHOOKS=1        →  FEATURE_WEBHOOKS=false
USE_REDIS_CACHE=yes       →  USE_REDIS_CACHE=false
CORS_ENABLED=true         →  CORS_ENABLED=false
PAYMENT_MODULE=true       →  PAYMENT_MODULE=false
```

### Step 3: Comment out external secrets

Prefix matching lines with `# [YAGNI] ` — keeps the original value visible for easy re-enable:

```bash
# Match patterns: *_API_KEY, *_SECRET (external), *_SECRET_KEY, *_TOKEN, *_WEBHOOK_URL, *_WEBHOOK_SECRET
grep -E '^\w+_(API_KEY|SECRET_KEY|TOKEN|WEBHOOK_URL|WEBHOOK_SECRET)=' .env
grep -E '^\w+_SECRET=' .env  # But exclude infrastructure secrets (see exclusions)
```

For each match (that isn't in the exclusion list), comment out by prepending `# [YAGNI] `.

**Example:**
```
STRIPE_API_KEY=sk_test_abc      →  # [YAGNI] STRIPE_API_KEY=sk_test_abc
STRIPE_WEBHOOK_SECRET=whsec_x   →  # [YAGNI] STRIPE_WEBHOOK_SECRET=whsec_x
SENDGRID_API_KEY=SG.xxx         →  # [YAGNI] SENDGRID_API_KEY=SG.xxx
SLACK_BOT_TOKEN=xoxb-...        →  # [YAGNI] SLACK_BOT_TOKEN=xoxb-...
GITHUB_TOKEN=ghp_...            →  # [YAGNI] GITHUB_TOKEN=ghp_...
```

### Exclusions — DO NOT modify

These variables are needed for basic app startup. **Never disable or comment out:**

| Category | Patterns / Names |
|----------|------------------|
| Database | `DATABASE_*`, `DB_*`, `POSTGRES_*`, `MYSQL_*`, `MONGO_*`, `PGHOST`, `PGPORT` |
| Cache / Queue | `REDIS_*`, `RABBITMQ_*`, `AMQP_*` |
| App secrets | `JWT_SECRET`, `SESSION_SECRET`, `APP_SECRET`, `APP_KEY`, `SECRET_KEY_BASE`, `ENCRYPTION_KEY` |
| Core config | `PORT`, `HOST`, `NODE_ENV`, `APP_ENV`, `DEBUG`, `LOG_LEVEL`, `TZ` |
| Ports | `*_PORT` — already handled by port offset logic |
| Compose | `COMPOSE_*` |
| Docker internal | `*_URL_DOCKER` — container-to-container URLs |

**Rule of thumb:** If the variable name contains `DATABASE`, `DB_`, `REDIS`, `POSTGRES`, `JWT`, `SESSION`, or `APP_SECRET` → leave it alone.

### Full example

**Input (copied from main `.env` with ports already offset):**
```bash
NODE_ENV=development
API_EXTERNAL_PORT=5100
DATABASE_URL=postgresql://postgres:postgres@localhost:5532/myapp_wt1
REDIS_EXTERNAL_PORT=6479
JWT_SECRET=my-jwt-secret
ENABLE_STRIPE=true
ENABLE_WEBHOOKS=true
ENABLE_EMAIL_NOTIFICATIONS=true
STRIPE_API_KEY=sk_test_abc123
STRIPE_WEBHOOK_SECRET=whsec_xyz
SENDGRID_API_KEY=SG.xxx
SLACK_WEBHOOK_URL=https://hooks.slack.com/xxx
```

**Output (after YAGNI minimization):**
```bash
# ⚠ YAGNI MODE: Features disabled, external keys commented out.
# Search for "# [YAGNI]" to find commented-out secrets.
# To re-enable a feature: set ENABLE_X=true and uncomment related keys.

NODE_ENV=development
API_EXTERNAL_PORT=5100
DATABASE_URL=postgresql://postgres:postgres@localhost:5532/myapp_wt1
REDIS_EXTERNAL_PORT=6479
JWT_SECRET=my-jwt-secret
ENABLE_STRIPE=false
ENABLE_WEBHOOKS=false
ENABLE_EMAIL_NOTIFICATIONS=false
# [YAGNI] STRIPE_API_KEY=sk_test_abc123
# [YAGNI] STRIPE_WEBHOOK_SECRET=whsec_xyz
# [YAGNI] SENDGRID_API_KEY=SG.xxx
# [YAGNI] SLACK_WEBHOOK_URL=https://hooks.slack.com/xxx
```

### Re-enabling features

When a disabled feature is needed:

1. Set the toggle: `ENABLE_STRIPE=true`
2. Find and uncomment its secrets: search for `# [YAGNI]` + the service name
3. Restart the Docker stack

The agent should do this automatically if Docker health checks fail due to a missing required feature.
