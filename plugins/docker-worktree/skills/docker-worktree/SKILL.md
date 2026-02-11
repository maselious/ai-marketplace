---
name: docker-worktree
description: Use when creating isolated git worktrees for Docker-based projects, setting up parallel development environments, or tearing down worktree Docker stacks. Triggers on 'docker worktree', 'create worktree', 'parallel environment', 'isolated workspace', 'teardown worktree', 'worktree docker', 'worktree cleanup'.
---

# Docker-Aware Git Worktree Lifecycle

## Overview

Manage the full lifecycle of git worktrees in Docker-based projects: assess readiness, configure isolated environments with unique ports, deploy Docker stacks, and tear down cleanly.

**Core principle:** Each worktree gets its own Docker Compose project with isolated ports, containers, volumes, and database — zero conflicts with the main workspace or other worktrees.

**Announce at start:** "I'm using the docker-worktree skill to [set up / tear down] an isolated Docker workspace."

## Process Overview

```
Phase 0: Guard ──► Not Docker? STOP
                   Already in worktree? → Teardown mode
         │
Phase 1: Readiness Assessment ──► Load readiness-checklist.md
         │
         ├─ Ready ────────────────► Phase 3
         │
         └─ Not Ready ──► Phase 2: Setup Guide (docker-setup-guide.md)
                          GATE: user applies changes
                          Re-assess → Phase 3
         │
Phase 3: Create Worktree + Configure Env
         Load env-configuration.md + worktree-lifecycle.md
         GATE: confirm port mappings
         │
Phase 4: Deploy Docker Stack
         Load migration-patterns.md + project CLAUDE.md
         │
Phase 5: Report
         Ports, URLs, teardown instructions
```

## Phase 0: Guard

Determine context before proceeding.

### Docker detection

```bash
ls docker-compose.yml docker-compose.yaml compose.yml compose.yaml Dockerfile 2>/dev/null
```

**If no Docker files found:**
> This project doesn't appear to use Docker Compose. The docker-worktree skill requires a Docker Compose configuration. Would you like to:
> 1. Create a Docker Compose setup for this project
> 2. Use plain git worktrees without Docker (use `using-git-worktrees` skill instead)

STOP. Do not proceed without Docker Compose.

### Worktree detection

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
git worktree list
```

**If current directory is a worktree (not the main working tree):**
- Ask: "You're inside a worktree. Do you want to tear down this environment?"
- If yes → jump to Teardown Mode

### Mode selection

Determine intent from user's request:

| Signal | Mode |
|--------|------|
| "create", "setup", "new worktree", "start feature" | **Setup** → Phase 1 |
| "teardown", "cleanup", "remove", "destroy", "done with" | **Teardown** → Teardown Mode |
| Ambiguous | Ask user |

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

## Teardown Mode

Invoked when user wants to remove a worktree and its Docker environment.

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

### Step 3: Stop Docker

```bash
docker compose -p <project-name> down -v --remove-orphans
```

If compose project name is unknown, detect from the worktree:
```bash
cd .worktrees/<slug>
docker compose ls --format json  # find matching project
```

### Step 4: Remove worktree

```bash
cd <main-repo-root>
git worktree remove .worktrees/<slug>
```

### Step 5: Clean up branch (optional)

Ask user:
```
Branch <name> still exists. What to do?
1. Delete it (not merged)
2. Keep it
```

If delete: `git branch -D <branch-name>`

### Step 6: Report

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
| No Docker files | STOP — suggest plain worktree |
| container_name hardcoded | Phase 2: Setup Guide |
| Ports not parameterized | Phase 2: Setup Guide |
| All checks pass | Skip to Phase 3 |
| Inside a worktree already | Offer teardown |
| Migration tool unknown | Check CLAUDE.md → README → auto-detect → ask |
| Health check fails | Show logs, ask user |
| Port conflict detected | Increment index, recalculate |

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

- [ ] Docker Compose detected (Phase 0)
- [ ] Readiness assessment run (Phase 1)
- [ ] All readiness issues resolved (Phase 2, if needed)
- [ ] Worktree directory in .gitignore
- [ ] Port offsets calculated and unique
- [ ] .env generated with correct ports
- [ ] Docker stack running and healthy
- [ ] Migrations applied
- [ ] API accessible at worktree port
- [ ] Teardown instructions provided

## Self-Improvement Protocol

After each use:
1. **New Docker Compose pattern not handled?** → Update `references/readiness-checklist.md` with the new check
2. **Migration tool not recognized?** → Add to `references/migration-patterns.md`
3. **Port conflict strategy failed?** → Update `references/env-configuration.md` with better allocation
4. **Project setup had non-obvious steps?** → Suggest updating project's CLAUDE.md
5. **Structural issue with this skill?** → Invoke `skill-forge` in IMPROVE mode
