# Shared Docker Mode

Reuse an existing Docker stack instead of deploying a new isolated one. Faster setup, lower resource usage — ideal for parallel features within the same project.

## When to Use

| Scenario | Mode |
|----------|------|
| Two features need isolated data and services | **Isolated** (default) |
| Features share the same backend, just need separate code branches | **Shared** |
| User explicitly requests `--shared` | **Shared** |
| Existing worktree Docker stack is running and user confirms reuse | **Shared** |

**Key trade-off:** Shared mode = faster setup + less resources, but services are shared. If Feature A breaks the API, Feature B is affected. Use isolated mode when features might conflict at runtime.

## Detection

### Step 1: Find running Docker stacks

```bash
# List all compose projects
docker compose ls --format json 2>/dev/null
```

Look for projects matching the current repository:

```bash
project_base="$(basename $(git rev-parse --show-toplevel))"
docker compose ls --format json | jq -r ".[].Name" | grep -i "$project_base"
```

### Step 2: Identify stack origin

For each matching project, determine its origin:

```bash
# Get config file paths
docker compose -p <project-name> config --format json 2>/dev/null | jq -r '.name'
```

Classify:

| Origin | Description |
|--------|-------------|
| Main tree stack | Docker running from the main working tree |
| Worktree stack | Docker running from another worktree |
| Orphan stack | Docker running but worktree was removed |

### Step 3: Get stack details

```bash
# Running services and ports
docker compose -p <project-name> ps --format json

# Extract host port mappings
docker compose -p <project-name> ps --format json | jq -r '.[] | "\(.Service): \(.Publishers)"'
```

### Step 4: Present options

```
Existing Docker stack detected: <project-name>

  Services: api, db, redis (all healthy)
  Ports:    API :5000, DB :5432, Redis :6379

  Options:
    1. Shared mode — reuse this stack, create new database only (fast)
    2. Isolated mode — new Docker stack with port offsets (full isolation)

  Recommended: Shared mode (features don't conflict at service level)
```

## Shared Mode Setup

### Step 1: Create worktree (standard)

Same as isolated mode — `git worktree add .worktrees/<slug> -b <branch>`.

### Step 2: Create database in existing stack

Find the database service and create a new database:

```bash
# Detect database type
db_service=$(docker compose -p <stack-name> ps --format json | jq -r '.[] | select(.Service | test("db|postgres|mysql|mongo")) | .Service' | head -1)

# Get the db port from the running stack
db_port=$(docker compose -p <stack-name> port "$db_service" 5432 2>/dev/null | cut -d: -f2)
```

#### PostgreSQL

```bash
# Derive database name
db_name="${project_base}_wt${index}"

# Create database
docker compose -p <stack-name> exec "$db_service" createdb -U postgres "$db_name"

# Verify
docker compose -p <stack-name> exec "$db_service" psql -U postgres -c "\\l" | grep "$db_name"
```

#### MySQL

```bash
docker compose -p <stack-name> exec "$db_service" mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE ${db_name};"
```

#### MongoDB

```bash
# MongoDB creates databases on first write — just use a unique name
# The app will auto-create it when connecting
```

### Step 3: Generate environment file

Copy `.env` from the stack's source (main tree or donor worktree), then:

1. **Keep all ports unchanged** — they point to the existing stack
2. **Change only the database name:**
   ```
   DATABASE_NAME=myapp_wt2
   ```
3. **Recalculate compound URLs:**
   ```
   DATABASE_URL=postgresql://postgres:postgres@localhost:5432/myapp_wt2
   ```
   Note: port stays at the stack's port (no offset).
4. **Apply YAGNI minimization** as usual (see `env-configuration.md`)

### Step 4: Run migrations

Migrations run against the **new database** via the existing stack:

```bash
# Set DATABASE_URL to point to the new DB
export DATABASE_URL="postgresql://postgres:postgres@localhost:${db_port}/${db_name}"

# Run migrations from the worktree directory (uses its code, not the stack's)
cd .worktrees/<slug>
<migrate-command>
```

Or inside the container:

```bash
docker compose -p <stack-name> exec -e DATABASE_NAME="$db_name" "$api_service" <migrate-command>
```

**Important:** If the migration tool reads `DATABASE_URL` from `.env`, ensure the worktree's `.env` is mounted or the variable is passed via `-e`.

### Step 5: Record shared mode in state

Write `.claude/dev-worktree.local.md` with shared flag:

```yaml
---
active_worktree: /path/to/.worktrees/feat-auth
branch: feat/auth
compose_project: <stack-name>
shared_docker: true
shared_db_name: myapp_wt2
created: 2026-02-15
---
Active worktree session (shared Docker mode). Managed by dev-worktree plugin.
```

**Note:** The state file tracks ONE active worktree per project root. If multiple shared worktrees are active simultaneously, only the most recent is recorded for session restore.

### Step 6: Verify

```bash
# Check the new database has tables
docker compose -p <stack-name> exec "$db_service" psql -U postgres -d "$db_name" -c "\\dt"

# Hit API health endpoint (same port as existing stack)
curl -s http://localhost:<api-port>/health
```

## Shared Mode Teardown

When tearing down a shared-mode worktree:

1. **Drop the database** (not the whole stack):
   ```bash
   docker compose -p <stack-name> exec "$db_service" dropdb -U postgres "$db_name"
   ```

2. **Remove worktree** (standard):
   ```bash
   git worktree remove .worktrees/<slug> --force
   git worktree prune
   ```

3. **Do NOT stop Docker** — other worktrees or the main tree may use it.

4. **Check if other worktrees still use this stack:**
   ```bash
   # Check state file for remaining references
   STATE_FILE="$(git worktree list | head -1 | awk '{print $1}')/.claude/dev-worktree.local.md"
   # Also check if any remaining worktrees have .env pointing to this stack's ports
   git worktree list | tail -n +2 | awk '{print $1}' | while read wt; do
     grep -q "compose_project.*<stack-name>" "$wt/../.claude/dev-worktree.local.md" 2>/dev/null && echo "$wt"
   done
   ```
   **Note:** State file tracks only the most recent worktree. Use `docker compose ls` + worktree list cross-check for best-effort detection.
   If no remaining consumers and the stack was not started from the main tree, ask:
   ```
   No worktrees are using Docker stack "<stack-name>".
   Keep it running (warm standby) or stop it?
   ```

## Limitations

- **Service-level conflicts:** If Feature A adds a new API endpoint that crashes the server, Feature B is affected. Use isolated mode for risky changes.
- **Schema conflicts:** If both features modify the same database tables with incompatible migrations, shared mode won't work. Each has its own DB, but the app code is shared at the container level.
- **Redis/cache isolation:** Shared Redis means shared cache keys. Features might pollute each other's cache. Consider using key prefixes if this is a concern.

## Detecting Reusable Orphan Stacks

After merging a feature, its worktree may be removed but the Docker stack left running (warm standby). Detect these:

```bash
# Get all compose projects
running_stacks=$(docker compose ls --format json | jq -r '.[].Name')

# Get all active worktrees
active_worktrees=$(git worktree list | tail -n +2 | awk '{print $1}')

# State file (single file per project root)
project_root=$(git worktree list | head -1 | awk '{print $1}')
state_file="$project_root/.claude/dev-worktree.local.md"

# A stack is orphaned if:
# 1. No active worktree's .env references its ports
# 2. It's not the main tree's own stack
for stack in $running_stacks; do
  # Check if it's the main tree's stack
  if docker compose -p "$stack" config --format json 2>/dev/null | grep -q "$project_root"; then
    continue  # Not orphaned — it's the main tree's stack
  fi
  # Check state file
  if [ -f "$state_file" ] && grep -q "compose_project: $stack" "$state_file"; then
    continue  # Active worktree uses it
  fi
  echo "Orphan stack: $stack"
done
```

Offer to reuse orphan stacks for new worktrees — they already have warm containers and might have useful data.
