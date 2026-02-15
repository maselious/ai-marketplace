---
name: worktree
description: Create, manage, or tear down isolated git worktrees (Docker backends and frontend projects)
argument-hint: "[setup|teardown|list|cleanup] [branch-name] [--shared] [--task \"task description\"]"
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

Entry point for git worktree lifecycle management — Docker backends and frontend projects. Supports shared Docker mode, smart teardown, warm standby, and backlog integration.

## Argument Parsing

Parse the command arguments:

| Pattern | Intent | Action |
|---------|--------|--------|
| No arguments | Ambiguous | Ask: setup or teardown? |
| `setup <branch>` or `create <branch>` | Create new worktree | Load dev-worktree skill → Phase 0 |
| `setup <branch> --shared` | Create worktree reusing existing Docker | Load skill → Phase 0, force shared mode at Phase 1.5 |
| `setup <branch> --task "<text>"` | Create worktree for backlog task | Load skill → Phase 0 with backlog matching |
| `teardown [slug]` or `remove [slug]` | Remove worktree | Load skill → Teardown mode (smart options) |
| `cleanup` or `prune` | Clean up warm stacks + orphan resources | Load skill → Cleanup Command |
| `list` or `ls` or `status` | List worktrees | Show all worktrees with status |
| `<branch-name>` (no keyword) | Create new worktree | Load skill → Phase 0 |

### Flags

| Flag | Effect |
|------|--------|
| `--shared` | Reuse existing Docker stack (skip stack detection prompt) |
| `--task "<text>"` | Link worktree to a backlog entry |

### Task linking

The `--task` flag (or natural language like "for task: ...", "для задачи: ...") links the new worktree to a backlog entry. The skill will:

1. Detect the project's backlog file (BACKLOG.md, TODO.md, etc.)
2. Match the specified task by substring search
3. After worktree creation, mark the task as in progress with branch and worktree info

If `--task` is not specified but a backlog exists, the skill may ask if the worktree is for a specific task.

## Execution

### For setup/teardown

Load and follow the `dev-worktree` skill. Pass the parsed intent, branch name, flags, and task reference (if any). The skill auto-detects whether this is a Docker backend or frontend project.

### For cleanup

Load the `dev-worktree` skill → Cleanup Command section. Lists warm standby stacks and orphan Docker resources, offers removal.

### For list

Show all worktrees and their status:

```bash
# List git worktrees
git worktree list

# Check Docker Compose projects (for backend worktrees)
docker compose ls --format "table {{.Name}}\t{{.Status}}\t{{.ConfigFiles}}" 2>/dev/null

# Check for warm standby stacks (running but no active worktree)
```

Present as:

```
Git Worktrees:
  main         /path/to/repo              (main working tree)
  feat-auth    .worktrees/feat-auth       Docker: running (<project>-wt1) — API :5100, DB :5532
  fix-bug      .worktrees/fix-bug         Shared: <project>-wt1 — DB: myapp_wt2
  fix-style    .worktrees/fix-style       Frontend — backend: localhost:5000

Warm Standby:
  <project>-wt2   — running, no active worktree (3 days idle)
```

## Examples

```
/worktree setup feat/auth-refactor                          → Create worktree (auto-detect type + mode)
/worktree feat/payment-fix                                  → Same (setup is default)
/worktree setup feat/auth --shared                          → Reuse existing Docker stack
/worktree setup feat/auth --task "Add user authentication"  → Create worktree + link backlog task
/worktree feat/payments --shared --task "payment gateway"   → Shared mode + task linking
/worktree teardown feat-auth-refactor                       → Smart teardown (full / warm standby / stop)
/worktree cleanup                                           → List and remove warm stacks + orphans
/worktree list                                              → Show all worktrees + warm stacks
/worktree                                                   → Ask what to do
```
