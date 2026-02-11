# Readiness Checklist

Evaluate whether a project's Docker configuration supports multiple parallel worktrees without conflicts.

## Checks

Run each check and record PASS/FAIL. All must pass before creating a worktree.

### 1. Container Names

**Check:** Are `container_name` values hardcoded in docker-compose?

```bash
grep -n 'container_name:' docker-compose.yml docker-compose.yaml compose.yml compose.yaml 2>/dev/null
```

**PASS:** No `container_name` directives found, OR all use variable interpolation (`${COMPOSE_PROJECT_NAME:-default}-service`).

**FAIL:** Any hardcoded `container_name: some-name` found.

**Why critical:** Docker refuses to start a container if another container with the same name exists. Two worktrees with the same compose file will conflict immediately.

**Fix:** Remove all `container_name:` lines. Docker Compose auto-generates names as `<project>-<service>-<n>`, which are unique per `--project-name`. See `docker-setup-guide.md`.

### 2. Port Parameterization

**Check:** Are host port bindings parameterized via environment variables?

```bash
grep -E 'ports:' -A5 docker-compose.yml | grep -E '"[0-9]+:[0-9]+"'
```

**PASS:** All ports use `"${VAR:-default}:internal"` pattern.

**FAIL:** Any hardcoded `"8080:8080"` port mapping found.

**Why critical:** Two compose stacks cannot bind the same host port. Port parameterization allows each worktree to use different host ports.

**Fix:** Extract each host port to an env variable. See `env-configuration.md`.

### 3. Environment File

**Check:** Does `.env.example` or `.env.template` exist?

```bash
ls .env.example .env.template 2>/dev/null
```

**PASS:** `.env.example` exists with all port variables documented.

**FAIL:** No example env file, or port variables missing from it.

**Why:** The worktree setup copies and modifies this file. Without it, port allocation cannot be automated.

**Fix:** Create `.env.example` listing all env vars used in docker-compose, especially port variables.

### 4. Gitignore for Worktree Directory

**Check:** Is the worktree directory ignored?

```bash
git check-ignore -q .worktrees 2>/dev/null && echo "PASS" || echo "FAIL"
```

**PASS:** `.worktrees/` (or configured directory) is in `.gitignore`.

**FAIL:** Directory not ignored.

**Why:** Worktree contents must not pollute git status of the main repo.

**Fix:** Auto-fix — add `.worktrees/` to `.gitignore`. This can be done without user confirmation.

### 5. Volume Names

**Check:** Are named volumes using default (non-prefixed) names?

```bash
grep -A1 '^volumes:' docker-compose.yml | grep -v '^volumes:' | grep -v '^\s*$'
```

**PASS:** Named volumes use simple names (e.g., `db-data:`). Docker Compose automatically prefixes with project name.

**FAIL:** Volumes use absolute paths or external volumes that would be shared.

**Why:** Docker Compose with `--project-name` prefixes named volumes automatically (`project_volume-name`), ensuring isolation. But external or host-path volumes are shared.

**Fix:** Convert external/host-path volumes to named volumes, or document the shared state.

### 6. Compound URL Variables

**Check:** Do environment variables like `DATABASE_URL` reference port variables?

```bash
grep -E '(DATABASE_URL|REDIS_URL|MONGO_URI)' .env.example 2>/dev/null
```

**PASS:** URLs are constructed from individual variables (`${DATABASE_HOST}:${DATABASE_PORT}`) OR use the Docker-internal port (container-to-container traffic doesn't use host ports).

**INFO:** If URLs use hardcoded ports, they need recalculation in worktree setup. This is handled in `env-configuration.md` — not a blocker, just extra work.

### 7. Network Configuration

**Check:** Does docker-compose define custom external networks?

```bash
grep -A2 '^networks:' docker-compose.yml | grep 'external: true'
```

**PASS:** No external networks, or only internal networks defined.

**FAIL:** External networks that would be shared between compose stacks.

**Why:** External networks can cause unexpected cross-communication between worktree stacks.

**Fix:** Remove `external: true` or use project-scoped network names.

## Report Template

Present results as:

```
Docker Worktree Readiness:

  ✅ Container names: [no hardcoded names / parameterized]
  ✅ Port parameterization: [N port variables found]
  ✅ Environment file: .env.example exists
  ✅ Gitignore: .worktrees/ ignored
  ✅ Volume names: all named (auto-prefixed)
  ℹ️  Compound URLs: DATABASE_URL needs recalculation (handled automatically)
  ✅ Networks: no external networks

  Result: READY / N ISSUES FOUND
```

## Auto-Fixable Issues

These can be fixed without user confirmation:
- **Gitignore:** Add `.worktrees/` to `.gitignore`

These require user confirmation (they modify tracked files):
- **Container names:** Remove `container_name:` from docker-compose
- **Port parameterization:** Add env variables to docker-compose
- **Volume conversion:** Change external volumes to named
- **Network changes:** Remove `external: true`
