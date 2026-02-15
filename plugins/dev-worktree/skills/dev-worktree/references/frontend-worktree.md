# Frontend Worktree Setup

Guide for creating worktrees for frontend projects that connect to backend services.

## Key Difference from Backend Worktrees

Frontend worktrees typically do NOT need their own Docker stack. They need:
1. Correct package manager detection and dependency install
2. Backend URL configuration (point to the right backend — main or worktree)
3. Post-install codegen (if any)
4. Dev server port adjustment (if needed)

## Package Manager Detection

Detect from lock files in priority order:

| Lock file | Package manager | Install command |
|-----------|----------------|-----------------|
| `bun.lockb` or `bun.lock` | bun | `bun install` |
| `pnpm-lock.yaml` | pnpm | `pnpm install` |
| `yarn.lock` | yarn | `yarn install` |
| `package-lock.json` | npm | `npm install` |

Additional checks:
- `packageManager` field in `package.json` specifies exact version (e.g., `yarn@4.6.0`)
- If `packageManager` field exists, use it. Some projects with Corepack require the exact version.

```bash
# Detection
if [ -f bun.lockb ] || [ -f bun.lock ]; then PKG="bun"
elif [ -f pnpm-lock.yaml ]; then PKG="pnpm"
elif [ -f yarn.lock ]; then PKG="yarn"
elif [ -f package-lock.json ]; then PKG="npm"
else PKG="unknown"  # Ask user
fi

# Corepack check (Yarn 2+, pnpm via Corepack)
grep -q '"packageManager"' package.json && corepack enable 2>/dev/null
```

## Backend URL Configuration

### Step 1: Identify Backend Connection

Check environment files for API URLs:

```bash
grep -rn 'API_URL\|BACKEND_URL\|STRAPI_URL\|SERVER_URL\|BASE_URL' \
  .env .env.example .env.local .env.template .env.development 2>/dev/null
```

Also check config files:
```bash
grep -rn 'apiUrl\|baseUrl\|serverUrl' \
  src/config/ next.config.* nuxt.config.* vite.config.* app.config.* 2>/dev/null
```

### Step 2: Detect Running Backends

Find what backends are available:

```bash
# Check common backend ports
for port in 3000 3001 4000 5000 5100 5200 8000 8080 9000 1337; do
  ss -tlnp | grep -q ":${port} " && echo "Port $port: ACTIVE"
done

# Check Docker Compose projects
docker compose ls --format "table {{.Name}}\t{{.Status}}\t{{.ConfigFiles}}"
```

### Step 3: Choose Backend

Present options to user:

```
Available backends for this project:
  1. Main backend (default): http://localhost:5000
  2. Worktree backend (<project>-wt1): http://localhost:5100
  3. Custom URL: ___

Which backend should this frontend connect to?
Default: main backend (recommended unless testing worktree-specific changes)
```

### Step 4: Apply Configuration

Create or update `.env.local` (or appropriate env file) in the worktree:

```bash
# For Next.js projects
echo "API_URL=http://localhost:5100" >> .env.local

# For Vite/TanStack projects
echo "API_URL=http://localhost:5100" >> .env
```

**Important:** Prefer `.env.local` for local overrides — it's typically in `.gitignore` and won't dirty the working tree.

## Dev Server Port

If the frontend dev server port might conflict with the main project:

```bash
# Check if default port is in use
PORT=$(grep -E '^PORT=' .env 2>/dev/null | cut -d= -f2)
PORT=${PORT:-3000}  # Default

if ss -tlnp | grep -q ":${PORT} "; then
  NEW_PORT=$((PORT + 10))
  echo "Port $PORT in use. Using $NEW_PORT"
fi
```

Common patterns for different frameworks:
```bash
# Next.js: -p flag or PORT env
PORT=3010 next dev
next dev -p 3010

# Vite/TanStack: --port flag or server.port config
vite --port 3010

# Nuxt
PORT=3010 nuxt dev
```

## Post-Install Steps

### Codegen Detection

```bash
# Check package.json scripts for codegen
grep -E '"(generate|codegen|build:types|build:graphql|postinstall|prepare)"' package.json
```

Common codegen tools:

| Tool | Detection | Command |
|------|-----------|---------|
| GraphQL Codegen | `graphql-codegen` in deps, `codegen.yml` | `npm run codegen` / `npx graphql-codegen` |
| OpenAPI Generator | `openapi` in scripts | `npm run generate:api` |
| TanStack Router | `@tanstack/router` in deps | Auto-generates during `dev`/`build` |
| tRPC | `@trpc/client` in deps | No explicit codegen needed |
| Prisma Client (fullstack) | `prisma/schema.prisma` | `npx prisma generate` |

### Build Verification

After install and codegen, verify the project builds:

```bash
# Quick type check (if TypeScript)
npx tsc --noEmit 2>&1 | head -20

# Or just run dev to verify
# (show user how to run dev, don't run it automatically)
```

## Setup Instructions Discovery

Before running generic steps, check for project-specific instructions:

1. **CLAUDE.md** — highest priority
   ```bash
   grep -il 'setup\|install\|getting.started\|quick.start' CLAUDE.md 2>/dev/null
   ```

2. **README.md** — setup/install sections
   ```bash
   grep -A20 -E '^#{1,3}\s*(Setup|Install|Getting Started|Quick Start|Development)' README.md 2>/dev/null
   ```

3. **package.json scripts** — look for `setup`, `dev:setup`, `prepare`, `postinstall`

If project instructions exist, follow them. If not, use the generic flow above.

## Saving Learnings

After setting up a frontend worktree for the first time in a project:

Suggest adding to the project's CLAUDE.md:

```markdown
## Worktree Setup

### Package Manager
Use [pnpm|yarn|npm|bun] (lock file: [filename])

### Backend Connection
Set `API_URL=http://localhost:<port>` in `.env.local`
Default backend: http://localhost:5000
Worktree backends: http://localhost:5100, 5200, ...

### Post-Install
1. [yarn|pnpm|npm|bun] install
2. [any codegen commands]
3. [any other setup commands]
```

This ensures the next worktree setup is faster and doesn't require re-discovery.
