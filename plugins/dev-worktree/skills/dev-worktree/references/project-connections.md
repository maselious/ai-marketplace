# Project Connection Map

How to discover and manage relationships between frontend and backend projects in a workspace.

## Discovery

### Step 1: Scan Sibling Projects

Frontend and backend projects typically live in sibling directories:

```bash
# List all project directories at the same level
WORKSPACE=$(dirname "$(pwd)")
ls -d "$WORKSPACE"/*/
```

### Step 2: Classify Each Project

For each sibling directory, determine its type:

| Check | Classification |
|-------|---------------|
| Has `docker-compose.yml` with `api`/`server` service + DB | **Backend (Docker)** |
| Has `src/main.ts` or `src/index.ts` + `nest-cli.json` / `express` / `fastify` | **Backend (Node)** |
| Has `manage.py` + `settings.py` | **Backend (Django)** |
| Has `next.config.*` / `nuxt.config.*` / `vite.config.*` | **Frontend** |
| Has `package.json` with `react`, `vue`, `svelte`, `angular` | **Frontend** |
| Has `strapi` or `medusa` in dependencies | **Backend + Admin UI (hybrid)** |

### Step 3: Map Connections

For each frontend, find which backend it connects to by checking env files:

```bash
# Scan all .env* files for URL patterns
grep -rh 'URL=http' .env* 2>/dev/null | sort -u
```

Match URLs to known backend ports:

| Port pattern | Likely backend |
|-------------|---------------|
| `:1337` | Strapi (CMS) |
| `:3000` | Generic Node/Next.js |
| `:4000` | Generic API / GraphQL |
| `:5000` | NestJS / Flask / Custom API |
| `:8000` | Django / FastAPI |
| `:8080` | Generic HTTP |
| `:9000` | Medusa / MinIO |

### Step 4: Check Running Services

```bash
# Docker Compose projects
docker compose ls 2>/dev/null

# Processes on common ports
ss -tlnp 2>/dev/null | grep -E ':(1337|3000|4000|5000|8000|8080|9000)\s'
```

## Connection Decision Logic

When setting up a frontend worktree, determine the backend URL:

```
1. Is there a backend worktree running?
   → List worktree Docker stacks (docker compose ls)
   → Match by project name / port range

2. Is the main backend running?
   → Check default port from .env.example

3. Neither running?
   → Use default URL from .env.example
   → Warn: "Backend at <url> is not running. Start it first or specify URL."
```

### Default Recommendation

**Usually connect to the main (default) backend** unless:
- The frontend change depends on backend changes in the worktree
- User explicitly requests connection to a worktree backend

Present this as the default choice with ability to override.

## Multi-Backend Scenarios

Some frontends connect to multiple backends:

```
storefront → Strapi (:1337) + MongoDB (:27017)
admin-panel → Medusa (:9000) + PostgreSQL (:5440) + Redis (:6380)
```

For these, list ALL connections and ask which ones to override (if any).

## Env File Patterns by Framework

Where to put the backend URL override:

| Framework | Primary env file | Override file | Notes |
|-----------|-----------------|---------------|-------|
| Next.js | `.env` | `.env.local` | `.env.local` overrides `.env`, auto-gitignored |
| Nuxt | `.env` | `.env` | No built-in override system |
| Vite / TanStack | `.env` | `.env.local` | `.env.local` overrides, auto-gitignored |
| Create React App | `.env` | `.env.local` | `.env.local` overrides |
| Angular | `environment.ts` | `environment.development.ts` | File-based, not env vars |

**Prefer `.env.local`** when the framework supports it — it doesn't dirty git status.

## Recording Connections

After discovering connections for the first time, suggest saving to project's CLAUDE.md:

```markdown
## Connected Services

| Service | URL | Env var | Project |
|---------|-----|---------|---------|
| Backend API | http://localhost:5000 | API_URL | ../backend-api |
| Redis | localhost:6379 | REDIS_HOST | (Docker in backend-api) |
```

This prevents re-discovery in future sessions.
