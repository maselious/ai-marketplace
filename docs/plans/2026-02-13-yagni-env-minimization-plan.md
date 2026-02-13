# YAGNI Env Minimization — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically disable feature toggles and comment out external service secrets when generating worktree `.env` files, following YAGNI principle.

**Architecture:** New section in `references/env-configuration.md` with pattern-matching rules for toggle vars and external secrets. SKILL.md references this section during env generation (Phase 3 Step 5 and F3).

**Tech Stack:** Markdown (skill documentation), no code — purely instructional changes to the skill.

---

### Task 1: Add "Feature Minimization" section to env-configuration.md

**Files:**
- Modify: `plugins/dev-worktree/skills/dev-worktree/references/env-configuration.md`

**Step 1: Add the new section at the end of the file (before closing)**

Insert after the "## File Summary" section (line 165+). The full content to append:

````markdown
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
| Database | `DATABASE_*`, `DB_*`, `POSTGRES_*`, `MYSQL_*`, `MONGO_*`, `PGHOST`, `PGPORT`, etc. |
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
````

**Step 2: Commit**

```bash
git add plugins/dev-worktree/skills/dev-worktree/references/env-configuration.md
git commit -m "📝 Add YAGNI feature minimization to env-configuration reference"
```

---

### Task 2: Add YAGNI step to SKILL.md Phase 3

**Files:**
- Modify: `plugins/dev-worktree/skills/dev-worktree/SKILL.md`

**Step 1: Extend Phase 3 Step 5 description**

Current text at SKILL.md ~line 190-195:
```markdown
### Step 5: Generate environment files

In the worktree directory:
1. Copy `.env` (or `.env.example`) → worktree `.env` with offset ports
2. Recalculate `DATABASE_URL` and similar compound variables
3. Generate `docker-compose.worktree.yml` override if needed (for container_name or other overrides)
```

Replace with:
```markdown
### Step 5: Generate environment files

In the worktree directory:
1. Copy `.env` (or `.env.example`) → worktree `.env` with offset ports
2. Recalculate `DATABASE_URL` and similar compound variables
3. Apply YAGNI minimization (see `references/env-configuration.md` → "Feature Minimization" section):
   - Disable all feature toggles (`ENABLE_*`, `FEATURE_*`, `USE_*`, `*_ENABLED` → `false`)
   - Comment out external service secrets with `# [YAGNI]` prefix
   - Add YAGNI header comment to `.env`
4. Generate `docker-compose.worktree.yml` override if needed (for container_name or other overrides)
```

**Step 2: Add YAGNI note to F3 (Frontend Configure Environment)**

In the "### F3: Configure Environment" section, after the `.env.local` creation, add:

```markdown
**YAGNI minimization:** If the frontend `.env` contains feature toggles or external service keys, apply the same YAGNI rules as backend (see `references/env-configuration.md` → "Feature Minimization").
```

**Step 3: Commit**

```bash
git add plugins/dev-worktree/skills/dev-worktree/SKILL.md
git commit -m "📝 Add YAGNI env minimization steps to worktree skill"
```

---

### Task 3: Bump version and commit

**Files:**
- Modify: `plugins/dev-worktree/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Bump plugin.json version**

Change `"version": "0.4.0"` to `"version": "0.5.0"`.

**Step 2: Bump marketplace.json version**

Change `"version": "0.4.0"` to `"version": "0.5.0"` in the dev-worktree entry.

**Step 3: Commit**

```bash
git add plugins/dev-worktree/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "🔖 Bump dev-worktree to v0.5.0 (YAGNI env minimization)"
```
