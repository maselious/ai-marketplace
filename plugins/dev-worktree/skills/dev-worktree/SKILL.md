---
name: dev-worktree
description: Use when creating isolated git worktrees for Docker-based or frontend projects, setting up parallel development environments, tearing down worktree stacks, or linking worktree creation to backlog tasks. Triggers on 'dev worktree', 'create worktree', 'parallel environment', 'isolated workspace', 'teardown worktree', 'docker worktree', 'worktree cleanup', 'frontend worktree', 'worktree for task', 'backlog worktree', 'link task to worktree'.
---

# Docker-Aware Git Worktree Lifecycle

## Overview

Manage the full lifecycle of git worktrees for both Docker-based backends and frontend projects: assess readiness, configure isolated environments, deploy stacks, connect frontends to correct backends, and tear down cleanly.

**Core principle:** Each worktree gets its own isolated environment — Docker backends get unique ports/containers/volumes, frontends get correct backend URLs and dependency installs.

**Two modes:**
- **Backend (Docker):** Full Docker Compose isolation with port offsets
- **Frontend:** Package install + backend URL configuration + codegen

**Announce at start:** "I'm using the dev-worktree skill to [set up / tear down] an isolated [Docker / frontend] workspace."

## Process Overview

```
Phase 0: Guard + Classify + Backlog Detect
         │
         ├─ Backend (Docker) ──► Phase 1: Readiness
         │                       │
         │                       ├─ Ready ──► Phase 3: Worktree + Env
         │                       │            GATE: port mappings
         │                       │            │
         │                       │            Phase 4: Deploy Docker
         │                       │            Backlog Update (if detected)
         │                       │            Phase 5: Report
         │                       │
         │                       └─ Not Ready ──► Phase 2: Setup Guide
         │                                        GATE → re-assess
         │
         ├─ Frontend ──► Frontend Mode (F1–F5)
         │               F1: Worktree + Install
         │               F2: Backend Discovery
         │               F3: Configure .env
         │               F4: Codegen + Verify
         │               Backlog Update (if detected)
         │               F5: Report + Save Learnings
         │
         ├─ Already in worktree? → Teardown mode
         │
         └─ Not a project? → STOP
```

## Phase 0: Guard + Classify

Determine project type and intent before proceeding.

### Worktree detection

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
git worktree list
```

**If current directory is a worktree (not the main working tree):**
- Ask: "You're inside a worktree. Do you want to tear down this environment?"
- If yes → jump to Teardown Mode

### Project type classification

Classify the current project:

```bash
# Check for Docker Compose (backend indicator)
ls docker-compose.yml docker-compose.yaml compose.yml compose.yaml 2>/dev/null

# Check for frontend frameworks
ls next.config.* nuxt.config.* vite.config.* app.config.* angular.json 2>/dev/null

# Check package.json for framework indicators
grep -E '"(react|vue|svelte|angular|next|nuxt|@tanstack)"' package.json 2>/dev/null
```

| Detection | Project type | Flow |
|-----------|-------------|------|
| Docker Compose + backend service (API/DB) | **Backend (Docker)** | → Phase 1 (Readiness) |
| Frontend framework, no Docker Compose (or Docker for prod only) | **Frontend** | → Frontend Mode |
| Docker Compose + frontend framework (hybrid like Strapi, Medusa) | **Backend (Docker)** | → Phase 1 (hybrid treated as backend) |
| No git repo / no package.json | **Unknown** | STOP — ask user |

### Mode selection

Determine intent from user's request:

| Signal | Mode |
|--------|------|
| "create", "setup", "new worktree", "start feature" | **Setup** → Phase 1 or Frontend Mode |
| "teardown", "cleanup", "remove", "destroy", "done with" | **Teardown** → Teardown Mode |
| Ambiguous | Ask user |

### Backlog detection (Setup mode only)

When creating a worktree, detect if the project has a backlog and if the user linked a task.

Load `references/backlog-integration.md` for detection rules and supported formats.

1. **Scan for backlog file** — check root for `BACKLOG.md`, `TODO.md`, `TASKS.md` (case-insensitive), or a backlog section in `CLAUDE.md` (see reference file for full list of supported section names)
2. **Check if user mentioned a task** — look for task references in the user's request (e.g., "create worktree for 'payment gateway'", "worktree for task: add auth")
3. **Match task** — find the task line in the backlog using substring search

| Backlog found? | Task mentioned? | Action |
|----------------|----------------|--------|
| Yes | Yes | Match task, remember for update after worktree creation |
| Yes | No | Ask: "Backlog found. Create worktree for a specific task?" |
| No | Yes | Inform: "No backlog file found. Skipping backlog update." |
| No | No | Skip silently |

**Store matched task info for later update** (file path, line number, original line text, branch name, worktree path). The actual update happens after worktree creation — see "Backlog Update" section below.

## Phase 1: Readiness Assessment

Load `references/readiness-checklist.md` and evaluate the project's Docker configuration.

Run ALL checks from the checklist. Classify results:

| Result | Action |
|--------|--------|
| All checks PASS | → Phase 3 |
| Some checks FAIL | → Phase 2 |
| Critical failures only | → Phase 2, highlight blockers |

**GATE:** Present readiness report to user.

```
Readiness Assessment:
  ✅ Ports parameterized via env vars
  ✅ .env.example exists
  ❌ container_name hardcoded (4 services)
  ❌ .worktrees/ not in .gitignore

2 issues must be fixed before creating worktrees.
Loading setup guide...
```

## Phase 2: Setup Guide

Load `references/docker-setup-guide.md`.

Present the **specific changes needed** for THIS project based on Phase 1 findings. The guide is a reference — apply it to the concrete issues found.

**GATE:** User must apply changes (or approve you to apply them). After changes:
- Re-run readiness checks
- If all pass → Phase 3
- If still failing → show remaining issues

## Phase 3: Create Worktree + Configure Environment

Load `references/worktree-lifecycle.md` and `references/env-configuration.md`.

### Step 1: Determine worktree directory

Check in priority order:
1. Existing `.worktrees/` or `worktrees/` directory
2. CLAUDE.md preference
3. Ask user

Verify directory is in `.gitignore`. If not — add it.

### Step 2: Determine branch name

From user's request or ask:
```
What branch name for this worktree?
Example: feat/auth-refactor, fix/payment-bug
```

### Step 3: Create git worktree

```bash
git worktree add .worktrees/<branch-slug> -b <branch-name>
```

### Step 4: Calculate port offsets

Follow `references/env-configuration.md` for port allocation strategy.

Count existing worktrees to determine index:
```bash
git worktree list | grep -v "$(git rev-parse --show-toplevel)$" | wc -l
```

Index = count + 1. Offset = index * 100.

### Step 5: Generate environment files

In the worktree directory:
1. Copy `.env` (or `.env.example`) → worktree `.env` with offset ports
2. Recalculate `DATABASE_URL` and similar compound variables
3. Generate `docker-compose.worktree.yml` override if needed (for container_name or other overrides)

### Step 6: Install dependencies

If `package.json` exists and Docker mounts source code:
- Dependencies install inside the container (via compose command)
- No host-side `npm install` needed in most Docker setups

If the project runs outside Docker for development:
```bash
cd .worktrees/<branch-slug> && npm install  # or pnpm, yarn, bun
```

**GATE:** Present port mapping table to user before deploying.

```
Worktree: .worktrees/feat-auth (index: 1, offset: +100)

Port Mapping:
  API:            5000 → 5100
  PostgreSQL:     5432 → 5532
  Redis:          6379 → 6479
  Redis Dashboard: 8001 → 8101
  MinIO API:      9002 → 9102
  MinIO Console:  9001 → 9101

DATABASE_URL: postgresql://postgres:postgres@localhost:5532/gmapi_wt1

Proceed with Docker deployment?
```

## Phase 4: Deploy Docker Stack

### Step 1: Read project setup instructions

Before deploying, check for setup instructions:

```bash
# Check CLAUDE.md, README, docs/
grep -il "setup\|install\|getting.started\|quick.start" CLAUDE.md README.md docs/*.md 2>/dev/null
```

Follow project-specific instructions if they exist. They override the generic patterns below.

### Step 2: Start Docker Compose

```bash
cd .worktrees/<branch-slug>
docker compose -p <project-name> up -d
```

Where `<project-name>` = slugified worktree identifier (e.g., `gm-wt1` or `gm-feat-auth`).

If a `docker-compose.worktree.yml` override was generated:
```bash
docker compose -f docker-compose.yml -f docker-compose.worktree.yml -p <project-name> up -d
```

### Step 3: Wait for health

```bash
docker compose -p <project-name> ps --format json
```

Wait until all services are healthy (up to 60 seconds). If any service fails:
- Show logs: `docker compose -p <project-name> logs <service> --tail 30`
- Ask user how to proceed

### Step 4: Run migrations and seeds

Load `references/migration-patterns.md` to detect the project's migration tool.

Priority order for determining migration commands:
1. **CLAUDE.md instructions** (highest priority)
2. **README / docs** setup sections
3. **Auto-detection** from project files (Prisma, TypeORM, Knex, etc.)
4. **Ask user** if unclear

Run migrations inside the container (if services run in Docker):
```bash
docker compose -p <project-name> exec <api-service> <migrate-command>
docker compose -p <project-name> exec <api-service> <seed-command>
```

Or from host if the app runs locally:
```bash
cd .worktrees/<branch-slug> && <migrate-command>
```

### Step 5: Verify

Hit the health endpoint (if the project has one):
```bash
curl -s http://localhost:<api-port>/health || curl -s http://localhost:<api-port>/api/health
```

## Session State

After the worktree is created and verified, write a state file so the SessionStart hook can detect the active worktree on session restore.

### Write state file

Create `.claude/dev-worktree.local.md` in the **original project root** (not the worktree):

```bash
PROJECT_ROOT="$(git worktree list | head -1 | awk '{print $1}')"
mkdir -p "$PROJECT_ROOT/.claude"
cat > "$PROJECT_ROOT/.claude/dev-worktree.local.md" << EOF
---
active_worktree: $(pwd)
branch: <branch-name>
compose_project: <compose-project-name-or-empty>
created: $(date +%Y-%m-%d)
---
Active worktree session. Managed by dev-worktree plugin.
EOF
```

**Frontend mode:** Same step, but `compose_project` is empty.

**Why:** On session restore, the SessionStart hook reads this file and reminds the agent to cd back into the worktree.

## Backlog Update

**Trigger:** A backlog task was matched during Phase 0 backlog detection.

**When:** After worktree is created and environment is ready (after Phase 4 for backend, after F4 for frontend), but before the final report.

Load `references/backlog-integration.md` for format details and edge cases.

### Steps

1. **Edit the backlog file** in the original repo directory (NOT in the worktree):
   - Replace `- [ ]` with `- [-]` on the matched task line
   - Append status suffix: `(🔄 branch: <branch-name>, worktree: <worktree-path>)`

2. **Do NOT commit** — leave the change uncommitted. User decides when to commit.

3. **Include in the report:**
   ```
   Backlog updated:
     File:     <backlog-file>
     Task:     "<task text>"
     Status:   [-] in progress
     Branch:   <branch-name>
     Worktree: <worktree-path>
     ⚠ Change is uncommitted.
   ```

**Skip if:** no backlog detected, no task matched, or user declined linking.

## Phase 5: Report

Present the final summary:

```
Docker Worktree Ready!

  Location:   .worktrees/<branch-slug>
  Branch:     <branch-name>
  Project:    <compose-project-name>

  Services:
    API:       http://localhost:<api-port>
    Database:  localhost:<db-port> (DB: <db-name>)
    Redis:     localhost:<redis-port>
    [other services...]

  To work in this worktree:
    cd .worktrees/<branch-slug>

  To tear down when done:
    Invoke this skill with "teardown worktree <branch-slug>"
    Or: docker compose -p <project-name> down -v && git worktree remove .worktrees/<branch-slug>
```

### Save learnings (optional)

If the setup required non-obvious steps:
- Suggest updating CLAUDE.md with worktree setup notes
- Or save to a project-local reference file

## Frontend Worktree Mode

For frontend projects that connect to a backend service. No Docker stack needed — focus on dependencies, backend URL, and codegen.

Load `references/frontend-worktree.md` and `references/project-connections.md`.

### F1: Create Worktree + Install Dependencies

Create worktree (same as Phase 3, Steps 1-3).

Detect and run the correct package manager:

```bash
# Detect from lock files
if [ -f bun.lockb ] || [ -f bun.lock ]; then bun install
elif [ -f pnpm-lock.yaml ]; then pnpm install
elif [ -f yarn.lock ]; then yarn install
elif [ -f package-lock.json ]; then npm install
fi
```

Check `packageManager` field in `package.json` for Corepack-managed versions.

### F2: Backend Discovery

Load `references/project-connections.md`.

Find which backend this frontend connects to:

```bash
# Scan env files for API URLs
grep -rn 'API_URL\|BACKEND_URL\|STRAPI_URL\|SERVER_URL' .env* 2>/dev/null
```

Detect running backends:

```bash
# Docker Compose projects (may include worktree backends)
docker compose ls 2>/dev/null

# Check common backend ports
ss -tlnp 2>/dev/null | grep -E ':(1337|3000|5000|8000|9000)\s'
```

**GATE:** Present backend options to user:

```
Available backends:
  1. Main backend (default): http://localhost:5000
  2. Worktree backend (gm-wt1): http://localhost:5100
  3. Custom URL

Which backend should this frontend connect to?
Recommended: main backend (unless testing worktree-specific changes)
```

### F3: Configure Environment

Create `.env.local` (preferred) or update `.env` in the worktree:

```bash
# Prefer .env.local (gitignored, doesn't dirty working tree)
echo "API_URL=http://localhost:<chosen-port>" >> .worktrees/<slug>/.env.local
```

If the dev server port conflicts, assign a new one:
```bash
# Check if default port is taken
PORT=$(grep -E '^PORT=' .env 2>/dev/null | cut -d= -f2)
ss -tlnp | grep -q ":${PORT:-3000} " && echo "Port conflict — use PORT=$((PORT + 10))"
```

### F4: Post-Install + Codegen

Check for required post-install steps:

1. **CLAUDE.md / README** — read setup instructions (highest priority)
2. **package.json scripts** — look for `generate`, `codegen`, `build:types`, `postinstall`, `prepare`
3. **Auto-detect** — GraphQL codegen configs, OpenAPI specs, TanStack Router (auto-generates)

Run detected codegen commands. If none found, skip.

Quick verification:
```bash
# TypeScript type check (if applicable)
npx tsc --noEmit 2>&1 | head -10
```

### Backlog Update (Frontend)

After F4 codegen and verification succeeds, if a backlog task was matched in Phase 0 — apply the Backlog Update steps from the "Backlog Update" section above. Edit the backlog file in the original repo directory, mark the task as `[-]` with branch and worktree info, do not commit. Edit the file in the original repo directory, do not commit.

### F5: Report + Save Learnings

```
Frontend Worktree Ready!

  Location:    .worktrees/<branch-slug>
  Branch:      <branch-name>
  Pkg Manager: <pnpm|yarn|npm|bun>
  Backend:     http://localhost:<port> (<main|worktree-name>)
  Dev Server:  <start command> (port <port>)

  To start:
    cd .worktrees/<branch-slug> && <dev-command>

  To tear down:
    git worktree remove .worktrees/<branch-slug>
```

**Session state:** Write the state file (see "Session State" section above). Use the same format, with empty `compose_project`.

**Save learnings:** If the project's CLAUDE.md lacks worktree setup info, suggest adding:

```markdown
## Worktree Setup
Package manager: <name> (lock file: <file>)
Backend: API_URL=http://localhost:5000 in .env.local
Post-install: <any codegen commands>
```

## Teardown Mode

Invoked when user wants to remove a worktree and its Docker environment (backend) or worktree directory (frontend).

### Step 1: Identify target

If not specified, list available worktrees:
```bash
git worktree list
```

Ask user which one to tear down.

### Step 2: Confirm

```
This will permanently remove:
  - Docker containers + volumes (compose project: <name>)
  - Worktree at .worktrees/<slug>
  - Branch <branch-name> (if not merged)

  Data in the database WILL BE LOST.

Type 'teardown' to confirm.
```

Wait for explicit confirmation.

### Step 3: Escape to main tree root

**Critical — do this BEFORE any destructive operations.** If CWD is inside the worktree
being deleted, the shell breaks (Linux cannot resolve `.` for a deleted inode).

```bash
cd "$(git worktree list | head -1 | awk '{print $1}')"
```

### Step 4: Stop Docker (backend worktrees only)

If this worktree has an associated Docker stack, stop it **from outside** using `-f`:

```bash
docker compose -p <project-name> -f .worktrees/<slug>/docker-compose.yml down -v --remove-orphans
```

If compose project name is unknown, detect it without cd-ing into worktree:
```bash
docker compose ls --format json  # find matching project by name
```

For **frontend worktrees** — skip this step (no Docker to stop).

### Step 5: Remove worktree

```bash
git worktree remove .worktrees/<slug> --force
git worktree prune
```

### Step 5.5: Clear session state

Remove the state file if it points to the worktree being torn down:

```bash
STATE_FILE="$(git worktree list | head -1 | awk '{print $1}')/.claude/dev-worktree.local.md"
if [ -f "$STATE_FILE" ] && grep -q ".worktrees/<slug>" "$STATE_FILE"; then
  rm "$STATE_FILE"
fi
```

### Step 6: Update backlog (if linked)

Search the backlog for a task linked to this worktree:

```bash
grep -ni "🔄.*worktree: .worktrees/<slug>" BACKLOG.md backlog.md TODO.md todo.md TASKS.md tasks.md CLAUDE.md 2>/dev/null
```

If found, ask user:
```
Task "Implement payment gateway" is linked to this worktree.
What should happen to the backlog entry?
  1. Mark as completed [x]
  2. Revert to pending [ ]
  3. Leave as-is [-]
```

Update the line accordingly and remove the `(🔄 ...)` suffix if marking as completed or pending.

### Step 7: Clean up branch (optional)

Ask user:
```
Branch <name> still exists. What to do?
1. Delete it (not merged)
2. Keep it
```

If delete: `git branch -D <branch-name>`

### Step 8: Report

```
Teardown complete:
  ✅ Docker containers stopped and removed
  ✅ Docker volumes removed
  ✅ Worktree removed
  ✅ Branch deleted (or kept)
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| Docker Compose + backend services | Backend mode → Phase 1 |
| Frontend framework, no Docker | Frontend mode → F1 |
| Hybrid (Strapi, Medusa) | Backend mode → Phase 1 |
| container_name hardcoded | Phase 2: Setup Guide |
| Ports not parameterized | Phase 2: Setup Guide |
| All readiness checks pass | Skip to Phase 3 |
| Inside a worktree already | Offer teardown |
| Migration tool unknown | Check CLAUDE.md → README → auto-detect → ask |
| Health check fails | Show logs, ask user |
| Port conflict detected | Increment index, recalculate |
| Unknown package manager | Check `packageManager` in package.json → ask user |
| Frontend backend URL unknown | Scan .env files → check running services → ask |
| Backlog file found | Detect format, match user-specified task, update after worktree created |
| Backlog not found | Skip silently |
| Task not found in backlog | Ask: add it or skip? |
| Tearing down linked task | Ask: mark completed, revert to pending, or leave as-is |

## Common Mistakes

### Forgetting compose project name

- **Problem:** `docker compose down` without `-p` targets the wrong project
- **Fix:** Always use `-p <project-name>` for all compose commands in worktrees

### Sharing database between worktrees

- **Problem:** Migration conflicts, data corruption
- **Fix:** Each worktree gets its own DB container with unique port and name

### Running npm install on host

- **Problem:** node_modules built for host OS, incompatible with container
- **Fix:** If Docker mounts source code, let the container handle dependency installation

### Not verifying .gitignore

- **Problem:** Worktree directory tracked by git, pollutes status
- **Fix:** Always verify `.worktrees/` is ignored before creating

## Checklist

### Backend (Docker) Mode
- [ ] Docker Compose detected (Phase 0)
- [ ] Readiness assessment run (Phase 1)
- [ ] All readiness issues resolved (Phase 2, if needed)
- [ ] Worktree directory in .gitignore
- [ ] Port offsets calculated and unique
- [ ] .env generated with correct ports
- [ ] Docker stack running and healthy
- [ ] Migrations applied
- [ ] API accessible at worktree port
- [ ] Backlog updated (if task linked)
- [ ] Teardown instructions provided

### Frontend Mode
- [ ] Project type classified as frontend (Phase 0)
- [ ] Worktree created
- [ ] Package manager detected correctly
- [ ] Dependencies installed
- [ ] Backend URL identified and configured
- [ ] Codegen/post-install steps run (if any)
- [ ] Dev server port checked for conflicts
- [ ] Backlog updated (if task linked)
- [ ] Learnings saved to CLAUDE.md (if first time)

## Self-Improvement Protocol

After each use:
1. **New Docker Compose pattern not handled?** → Update `references/readiness-checklist.md` with the new check
2. **Migration tool not recognized?** → Add to `references/migration-patterns.md`
3. **Port conflict strategy failed?** → Update `references/env-configuration.md` with better allocation
4. **New frontend framework or package manager?** → Update `references/frontend-worktree.md`
5. **New project connection discovered?** → Update `references/project-connections.md` with detection pattern
6. **Project setup had non-obvious steps?** → Suggest updating project's CLAUDE.md
7. **New backlog format not recognized?** → Update `references/backlog-integration.md` with the new format
8. **Structural issue with this skill?** → Invoke `skill-forge` in IMPROVE mode
