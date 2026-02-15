# Architecture Audit Guide

Instructions for analyzing project architecture during Gate 1. Dispatch the `architecture-auditor` agent with these patterns.

## Step 1: Detect Stack

Check project root for framework indicators:

| File | Stack Signal |
|------|-------------|
| `package.json` + `nest-cli.json` | NestJS |
| `package.json` + `@nestjs/core` in deps | NestJS |
| `package.json` + `next.config.*` | Next.js |
| `package.json` + `vite.config.*` | Vite (React/Vue/Svelte) |
| `package.json` + `nuxt.config.*` | Nuxt |
| `pyproject.toml` or `requirements.txt` | Python |
| `go.mod` | Go |
| `Cargo.toml` | Rust |

Read main config for: framework version, key dependencies (ORM, auth, queue), TypeScript strict mode, build tool.

## Step 2: Detect Architecture Pattern

Scan `src/` (or equivalent) directory structure:

| Pattern | Directory Indicators |
|---------|---------------------|
| Clean Architecture | `domain/`, `infrastructure/`, `application/`, `interface/` |
| Modular Monolith | `modules/` with controller+service+entity per module |
| FSD (Feature-Sliced) | `routes/` or `pages/` + `features/` + `entities/` + `shared/` |
| MVC | `controllers/` + `services/` + `models/` |
| Flat | No clear structure |

## Step 3: Map Directories to Layers

**Clean Architecture:**

| Layer | Typical Path | Contains |
|-------|-------------|----------|
| Domain | `src/domain/` | Entities, abstract repositories, events, value objects |
| Application | `src/application/` | CQRS handlers, services, event handlers |
| Infrastructure | `src/infrastructure/` | Repository implementations, external adapters |
| Interface | `src/interface/` | Controllers, DTOs, guards, middleware |

**FSD:**

| Layer | Typical Path | Contains |
|-------|-------------|----------|
| Routes/Pages | `src/routes/` or `src/pages/` | Page components, layouts |
| Widgets | `src/widgets/` | Composite UI blocks |
| Features | `src/features/` | Business logic + UI |
| Entities | `src/entities/` | Data models + base UI |
| Shared | `src/shared/` | UI kit, utilities, API client |

For unrecognized patterns: scan tree, present findings, let user confirm.

## Step 4: Detect Existing .claude/ Setup

Check for:
- `.claude/skills/*/SKILL.md` — existing skills (list names)
- `.claude/agents/*.md` — existing agents (list names)
- `.claude/commands/*.md` — existing commands (list names)
- `.claude/hooks/hooks.json` — hooks configured
- `CLAUDE.md` — project instructions (note presence + size)

## Step 4.5: Detect Worktree Ecosystem

Check if the project uses dev-worktree plugin for parallel development:

```bash
# Active worktree state
cat .claude/dev-worktree.local.md 2>/dev/null

# Worktree directories
ls -d .worktrees/ worktrees/ 2>/dev/null
git worktree list 2>/dev/null | wc -l

# Docker Compose (worktree-capable project)
ls docker-compose.yml docker-compose.yaml compose.yml compose.yaml 2>/dev/null

# Running compose stacks (warm pools, active stacks)
docker compose ls --format json 2>/dev/null | jq -r '.[].Name' | wc -l
```

| Detection | Impact on Audit |
|-----------|----------------|
| `.claude/dev-worktree.local.md` exists | Project actively uses worktrees — parallel score +1 |
| Multiple worktrees listed | Team is already doing parallel work |
| Docker Compose + `.worktrees/` in `.gitignore` | Worktree-ready project |
| No worktree indicators | Worktrees not yet set up |

Include in output:

```
Worktree ecosystem:
  Active worktrees: {count}
  Docker stacks: {count} running
  Worktree-ready: {yes/no}
```

This information helps Gate 2 (pipeline mode) recommend parallel workflows when worktree infrastructure is already in place.

## Step 5: Detect Conflict Zones

Shared directories where parallel streams would conflict:

    # Find shared imports (TypeScript example)
    grep -r "from.*shared/" src/ --include="*.ts" -l 2>/dev/null | wc -l
    grep -r "from.*common/" src/ --include="*.ts" -l 2>/dev/null | wc -l

Flag:
- `shared/` or `common/` directories (shared types, utilities)
- Barrel exports (`index.ts` aggregating multiple modules)
- DI container registration files
- Migration files with sequential numbering

## Step 6: Parallel Readiness Score

| Criteria | Points |
|----------|--------|
| Clear layer separation | +2 |
| No circular dependencies between layers | +2 |
| Few shared files (<10) | +1 |
| Strong typing (TypeScript strict) | +1 |
| Existing test infrastructure | +1 |
| Worktree-ready (Docker Compose + .worktrees in .gitignore) | +1 |
| Many shared files (>20) | -2 |
| Circular dependencies detected | -3 |
| No clear layer separation | -3 |

- Score >= 5: recommend parallel
- Score 3-4: parallel with restrictions (serialize conflict zones)
- Score < 3: recommend sequential

## Output Format

    📊 Architecture Audit Results

    Stack: {framework} {version} + {ORM} + {language}
    Architecture: {pattern} ({layer_count} layers)
    ORM: {orm} ({database})

    Layers:
      {layer}: {path} ({module_count} modules)
      ...

    Existing .claude/:
      Skills: {list or "none"}
      Agents: {list or "none"}

    Worktree ecosystem:
      Active worktrees: {count or "none"}
      Docker stacks: {count or "none"}
      Worktree-ready: {yes/no}

    Conflict zones: {paths} ({file_count} files)
    Parallel readiness: {score}/10 — {recommendation}
