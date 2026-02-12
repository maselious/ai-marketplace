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
cd "$(git worktree list | head -1 | awk '{print $1}')"

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

### Partial Teardown Options

| Option | Command | Use when |
|--------|---------|----------|
| Stop containers only | `docker compose -p $name stop` | Pausing work, want to resume later |
| Remove containers, keep volumes | `docker compose -p $name down` | Rebuild containers, keep data |
| Full removal | `docker compose -p $name down -v` | Done with this worktree |

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
