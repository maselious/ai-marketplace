---
name: worktree
description: Create, manage, or tear down isolated git worktrees (Docker backends and frontend projects)
argument-hint: "[setup|teardown|list] [branch-name] [--task \"task description\"]"
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

Entry point for git worktree lifecycle management — Docker backends and frontend projects. Supports backlog integration for task tracking.

## Argument Parsing

Parse the command arguments:

| Pattern | Intent | Action |
|---------|--------|--------|
| No arguments | Ambiguous | Ask: setup or teardown? |
| `setup <branch>` or `create <branch>` | Create new worktree | Load dev-worktree skill → Phase 0 (auto-detects project type) |
| `setup <branch> --task "<text>"` | Create worktree for backlog task | Load dev-worktree skill → Phase 0 with backlog matching |
| `teardown [slug]` or `cleanup [slug]` or `remove [slug]` | Remove worktree | Load dev-worktree skill → Teardown mode |
| `list` or `ls` or `status` | List worktrees | Show all worktrees with status |
| `<branch-name>` (no keyword) | Create new worktree | Load dev-worktree skill → Phase 0 |

### Task linking

The `--task` flag (or natural language like "for task: ...", "для задачи: ...") links the new worktree to a backlog entry. The skill will:

1. Detect the project's backlog file (BACKLOG.md, TODO.md, etc.)
2. Match the specified task by substring search
3. After worktree creation, mark the task as in progress with branch and worktree info

If `--task` is not specified but a backlog exists, the skill may ask if the worktree is for a specific task.

## Execution

### For setup/teardown

Load and follow the `dev-worktree` skill. Pass the parsed intent, branch name, and task reference (if any). The skill auto-detects whether this is a Docker backend or frontend project.

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
/worktree setup feat/auth-refactor                          → Create worktree (auto-detect type)
/worktree feat/payment-fix                                  → Same (setup is default)
/worktree setup feat/auth --task "Add user authentication"  → Create worktree + link backlog task
/worktree feat/payments --task "payment gateway"            → Short form with task
/worktree teardown feat-auth-refactor                       → Stop Docker + remove worktree + update backlog
/worktree list                                              → Show all worktrees with status
/worktree                                                   → Ask what to do
```
