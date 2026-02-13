# YAGNI Environment Minimization — Design

## Problem

When creating worktrees, the `.env` file is copied from the main project with only port offsets applied. All feature toggles, external service integrations, and API keys remain active. This causes:

- **Resource conflicts** — multiple worktrees competing for the same external APIs (webhooks, S3 buckets)
- **Unnecessary services** — modules/integrations that aren't relevant to the current task consume memory and ports
- **Startup failures** — missing or shared API keys cause errors in non-essential modules
- **Inter-worktree interference** — webhook callbacks hit the wrong worktree instance

## Solution: Pattern-Based Toggle Kill

### Principle

**Disable everything by default. Enable only when needed.**

The agent automatically minimizes the worktree `.env` after copying and applying port offsets. No user interaction required.

### Algorithm

After copying `.env` and applying port offsets (existing Step 5):

**Step A: Disable feature toggles**

Scan for variables matching these patterns and set to `false`:

| Pattern | Examples |
|---------|----------|
| `ENABLE_*=true\|1\|yes` | `ENABLE_STRIPE`, `ENABLE_WEBHOOKS` |
| `FEATURE_*=true\|1\|yes` | `FEATURE_DARK_MODE`, `FEATURE_V2_API` |
| `USE_*=true\|1\|yes` | `USE_REDIS_CACHE`, `USE_S3_STORAGE` |
| `*_ENABLED=true\|1\|yes` | `CORS_ENABLED`, `RATE_LIMIT_ENABLED` |
| `*_MODULE=true\|1\|yes` | `PAYMENT_MODULE`, `ANALYTICS_MODULE` |

**Step B: Comment out external secrets**

Prefix with `# [YAGNI] ` for easy search and re-enable:

| Pattern | Examples |
|---------|----------|
| `*_API_KEY=*` | `STRIPE_API_KEY`, `SENDGRID_API_KEY` |
| `*_SECRET=*` (external) | `STRIPE_WEBHOOK_SECRET`, `OAUTH_CLIENT_SECRET` |
| `*_SECRET_KEY=*` | `AWS_SECRET_KEY` |
| `*_TOKEN=*` | `SLACK_BOT_TOKEN`, `GITHUB_TOKEN` |
| `*_WEBHOOK_URL=*` | `SLACK_WEBHOOK_URL` |
| `*_WEBHOOK_SECRET=*` | `STRIPE_WEBHOOK_SECRET` |

**Step C: Add YAGNI header**

Insert at the top of the worktree `.env`:

```
# ⚠ YAGNI MODE: Features disabled, external keys commented out.
# Search for "# [YAGNI]" to find commented-out secrets.
# To re-enable a feature: set ENABLE_X=true and uncomment related keys.
```

### Exclusions — DO NOT touch

These variables are needed for basic app startup:

| Category | Patterns |
|----------|----------|
| Database | `DATABASE_*`, `DB_*`, `POSTGRES_*`, `MYSQL_*`, `MONGO_*` |
| Cache/queue | `REDIS_*`, `RABBITMQ_*`, `AMQP_*` |
| App secrets | `JWT_SECRET`, `SESSION_SECRET`, `APP_SECRET`, `APP_KEY`, `SECRET_KEY_BASE` |
| Core config | `PORT`, `HOST`, `NODE_ENV`, `APP_ENV`, `DEBUG`, `LOG_LEVEL` |
| Ports (offset) | `*_PORT` (already handled by port offset logic) |

### File Changes

| File | Action |
|------|--------|
| `references/env-configuration.md` | **Edit** — add "Feature Minimization" section |
| `skills/dev-worktree/SKILL.md` | **Edit** — add YAGNI step reference in Phase 3 Step 5 and F3 |
| `.claude-plugin/plugin.json` | **Edit** — bump version to 0.5.0 |
