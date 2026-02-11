---
name: worktree
description: Create, manage, or tear down isolated git worktrees (Docker backends and frontend projects)
argument-hint: "[setup|teardown|list] [branch-name]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
  - Task
---

# /worktree Command

Entry point for git worktree lifecycle management — Docker backends and frontend projects.

## Argument Parsing

Parse the command arguments:

| Pattern | Intent | Action |
|---------|--------|--------|
| No arguments | Ambiguous | Ask: setup or teardown? |
| `setup <branch>` or `create <branch>` | Create new worktree | Load dev-worktree skill → Phase 0 (auto-detects project type) |
| `teardown [slug]` or `cleanup [slug]` or `remove [slug]` | Remove worktree | Load dev-worktree skill → Teardown mode |
| `list` or `ls` or `status` | List worktrees | Show all worktrees with status |
| `<branch-name>` (no keyword) | Create new worktree | Load dev-worktree skill → Phase 0 |

## Execution

### For setup/teardown

Load and follow the `dev-worktree` skill. Pass the parsed intent and branch name. The skill auto-detects whether this is a Docker backend or frontend project.

### For list

Show all worktrees and their status:

```bash
# List git worktrees
git worktree list

# Check Docker Compose projects (for backend worktrees)
docker compose ls --format "table {{.Name}}\t{{.Status}}\t{{.ConfigFiles}}" 2>/dev/null
```

Present as:

```
Git Worktrees:
  main         /path/to/repo              (main working tree)
  feat-auth    .worktrees/feat-auth       Docker: running (gm-wt1) — API :5100, DB :5532
  fix-bug      .worktrees/fix-bug         Frontend — backend: localhost:5000
```

## Examples

```
/worktree setup feat/auth-refactor     → Create worktree (auto-detect: Docker or frontend)
/worktree feat/payment-fix             → Same (setup is default)
/worktree teardown feat-auth-refactor  → Stop Docker + remove worktree
/worktree list                         → Show all worktrees with status
/worktree                              → Ask what to do
```
