# Worktree Lifecycle

Detailed procedures for creating, managing, and tearing down Docker-backed worktrees.

## Creation

### Directory Selection

Priority order:
1. **Existing directory:** Check for `.worktrees/` or `worktrees/`
2. **CLAUDE.md preference:** `grep -i 'worktree.*director' CLAUDE.md`
3. **Ask user** with options:
   - `.worktrees/` (project-local, hidden) — recommended
   - Custom path

### Branch Naming

Derive from user's intent:
- Feature: `feat/<slug>`
- Bugfix: `fix/<slug>`
- Experiment: `exp/<slug>`

Slug the branch name for directory use:
```bash
slug=$(echo "$branch" | sed 's|/|-|g')
# feat/auth-refactor → feat-auth-refactor
```

### Similar Worktree Check

Before creating, scan for existing worktrees with overlapping branches:

```bash
# Get all worktree branches
existing_branches=$(git worktree list --porcelain | grep '^branch' | sed 's|branch refs/heads/||')

# Check for exact match (branch already has a worktree)
echo "$existing_branches" | grep -Fx "$branch" && echo "ERROR: branch already checked out in a worktree"

# Check for prefix overlap (e.g., feat/auth vs feat/auth-v2)
branch_prefix=$(echo "$branch" | sed 's|-[^-]*$||')  # feat/auth-v2 → feat/auth
echo "$existing_branches" | grep "^${branch_prefix}" | grep -v "^${branch}$"

# Check for keyword overlap (split on / and -)
keywords=$(echo "$branch" | tr '/-' '\n' | grep -v -E '^(feat|fix|exp|chore)$')
for kw in $keywords; do
  echo "$existing_branches" | grep -i "$kw" | grep -v "^${branch}$"
done
```

If matches found — present options to user (continue / switch / replace) before proceeding.

### Create Command

```bash
# From the main working tree root
git worktree add .worktrees/$slug -b $branch
```

If the branch already exists (e.g., remote branch):
```bash
git worktree add .worktrees/$slug $branch
```

### Post-Create Verification

```bash
# Verify worktree was created
git worktree list | grep $slug

# Verify we can cd into it
ls .worktrees/$slug/docker-compose.yml
```

## Docker Stack Startup

### Compose Command

Always use `--project-name` (`-p`) for isolation:

```bash
cd .worktrees/$slug
docker compose -p $project_name up -d
```

### Health Monitoring

Wait for all services to be healthy:

```bash
# Check all services
docker compose -p $project_name ps

# Wait loop (up to 90 seconds)
for i in $(seq 1 18); do
  unhealthy=$(docker compose -p $project_name ps --format json | jq -r '.[] | select(.Health != "healthy" and .Health != "") | .Service')
  if [ -z "$unhealthy" ]; then
    echo "All services healthy"
    break
  fi
  echo "Waiting for: $unhealthy"
  sleep 5
done
```

### Startup Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Port already in use | Another worktree or service on that port | Check `ss -tlnp \| grep <port>`, increment index |
| Container exits immediately | Missing env vars or bad config | `docker compose -p $name logs <service>` |
| Health check timeout | Service slow to start | Increase wait time, check resource limits |
| Volume permission denied | Host/container UID mismatch | Check volume mount permissions |

## Teardown

### Full Teardown (default)

Removes everything: containers, volumes, network, worktree directory, branch.

**Critical:** Always `cd` to main tree root FIRST — before any destructive operations.
Running `git worktree remove` or `rm -rf` while CWD is inside the target directory
breaks the shell (Linux cannot resolve `.` for a deleted inode).

```bash
# 0. FIRST — escape to main tree root (prevents broken CWD)
main_root="$(git worktree list | head -1 | awk '{print $1}')"
cd "$main_root"

# 0.5. SAFETY — verify target is NOT the main tree's stack
if [ "$(realpath .worktrees/$slug)" = "$(realpath $main_root)" ]; then
  echo "⛔ Refusing to tear down main tree's Docker stack"
  exit 1
fi

# 1. Stop and remove Docker resources (from OUTSIDE, using -f)
docker compose -p $project_name -f .worktrees/$slug/docker-compose.yml down -v --remove-orphans

# 2. Remove worktree
git worktree remove .worktrees/$slug --force

# 3. Prune stale worktree refs
git worktree prune

# 4. Optionally delete branch
git branch -D $branch  # Only if not merged
```

> **Why `-f` flag?** Docker Compose can target any compose file via `-f` without requiring
> `cd` into its directory. This avoids the CWD-inside-deleted-directory problem entirely.

### Smart Teardown Options

| Option | Action | Use when |
|--------|--------|----------|
| **Full removal** | `docker compose -p $name down -v` + remove worktree | Done, no reuse planned |
| **Warm standby** | Remove worktree, keep Docker running | Planning another feature soon |
| **Stop only** | `docker compose -p $name stop` | Pausing work, want to resume later |
| **Shared mode cleanup** | Drop database, remove worktree, keep stack | Worktree was in shared Docker mode |

### Warm Standby

Keep the Docker stack running after worktree removal. Next worktree creation is instant — just create worktree, generate `.env`, run migrations.

```bash
# Remove worktree but keep Docker
cd "$(git worktree list | head -1 | awk '{print $1}')"
git worktree remove .worktrees/$slug --force
git worktree prune
# Docker stack stays running
echo "Stack $project_name kept in warm standby"
```

**Present the choice to user during teardown:**

```
Teardown options for .worktrees/<slug>:

  1. Full teardown — remove everything (Docker + data + worktree)
  2. Warm standby — remove worktree, keep Docker running for future use
  3. Stop only — pause Docker, keep worktree (resume later)

  Recommended: Warm standby (if you plan to create another worktree soon)
```

### Shared Mode Teardown

When the worktree used shared Docker mode (check state file for `shared_docker: true`):

```bash
# 1. Drop the worktree's database (not the whole stack!)
docker compose -p $shared_stack exec db dropdb -U postgres $shared_db_name

# 2. Remove worktree
cd "$(git worktree list | head -1 | awk '{print $1}')"
git worktree remove .worktrees/$slug --force
git worktree prune

# 3. Do NOT touch Docker — other consumers may exist
```

### Warm Stack Management

Detect warm (orphaned) stacks — running Docker stacks with no active worktree:

```bash
# All compose projects
running=$(docker compose ls --format json | jq -r '.[].Name')

# All worktree directories
worktrees=$(git worktree list | tail -n +2 | awk '{print $1}')

# See shared-docker.md → "Detecting Reusable Orphan Stacks" for full algorithm
# Match: stack is warm if no worktree references it and it's not the main tree stack
```

**Offer reuse** when creating a new worktree:

```
Warm Docker stack detected: <project>-wt1

  Services: api, db, redis (all healthy)
  Last used: 3 days ago
  Data: database with existing migrations

  Reuse this stack? (shared mode)
```

**Cleanup command:** When user runs `/worktree cleanup`:

```bash
main_root="$(git worktree list | head -1 | awk '{print $1}')"

# List all warm stacks (EXCLUDING main tree's stack)
for stack in $running; do
  # Skip main tree's stack — never offer to remove it
  if docker compose -p "$stack" config --format json 2>/dev/null | grep -q "$main_root"; then
    continue
  fi
  # Show last activity, disk usage
  # Ask: keep or remove?
  docker compose -p $stack down -v --remove-orphans
done
```

### Orphan Detection

After teardown, check for leftover resources:

```bash
# Orphan containers
docker ps -a --filter "label=com.docker.compose.project=$project_name"

# Orphan volumes
docker volume ls --filter "label=com.docker.compose.project=$project_name"

# Orphan networks
docker network ls --filter "label=com.docker.compose.project=$project_name"
```

If found: `docker compose -p $project_name down -v --remove-orphans`

### Stale Worktree Cleanup

Detect worktrees whose Docker stacks are already gone:

```bash
# List all worktrees
git worktree list

# For each non-main worktree, check if compose project exists
docker compose ls --format json | jq -r '.[].Name'
```

Worktrees without running compose projects may be stale — offer to remove them.

## Working with the Worktree

### Switching Context

```bash
# From main tree
cd .worktrees/$slug

# From worktree back to main
cd $(git worktree list | head -1 | awk '{print $1}')
```

### Running Commands in Worktree Containers

```bash
# Execute inside a container
docker compose -p $project_name exec api <command>

# View logs
docker compose -p $project_name logs -f api

# Restart a service
docker compose -p $project_name restart api
```

### Sharing Code Between Worktrees

Git worktrees share the same `.git` directory. Commits made in one worktree are visible in all others (same repo). But:
- Working trees are independent (different branches, different changes)
- Docker stacks are independent (different containers, different data)
- `.env` files are independent (different ports)
