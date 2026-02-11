---
name: worktree
description: Create, manage, or tear down Docker-isolated git worktrees
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

Entry point for Docker-aware git worktree management.

## Argument Parsing

Parse the command arguments:

| Pattern | Intent | Action |
|---------|--------|--------|
| No arguments | Ambiguous | Ask: setup or teardown? |
| `setup <branch>` or `create <branch>` | Create new worktree | Load docker-worktree skill → Setup mode |
| `teardown [slug]` or `cleanup [slug]` or `remove [slug]` | Remove worktree | Load docker-worktree skill → Teardown mode |
| `list` or `ls` or `status` | List worktrees | Show all worktrees with Docker status |
| `<branch-name>` (no keyword) | Create new worktree | Load docker-worktree skill → Setup mode |

## Execution

### For setup/teardown

Load and follow the `docker-worktree` skill. Pass the parsed intent and branch name.

### For list

Show all worktrees and their Docker stack status:

```bash
# List git worktrees
git worktree list

# For each non-main worktree, check Docker status
docker compose ls --format "table {{.Name}}\t{{.Status}}\t{{.ConfigFiles}}"
```

Present as:

```
Git Worktrees:
  main     /path/to/repo              (main working tree)
  feat-auth  .worktrees/feat-auth     Docker: running (gm-wt1) — API :5100, DB :5532
  fix-bug    .worktrees/fix-bug       Docker: stopped (gm-wt2)
```

## Examples

```
/worktree setup feat/auth-refactor     → Create worktree + Docker stack
/worktree feat/payment-fix             → Same (setup is default)
/worktree teardown feat-auth-refactor  → Stop Docker + remove worktree
/worktree list                         → Show all worktrees with status
/worktree                              → Ask what to do
```
