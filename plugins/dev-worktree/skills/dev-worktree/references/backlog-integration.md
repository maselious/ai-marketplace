# Backlog Integration

Detect a project's backlog file, match a user-specified task, and update its status when a worktree is created.

## Backlog Detection

Scan the **current working directory** (the original repo, NOT the worktree) for backlog files.

### Detection order

1. **Dedicated backlog files** — check root for these names (case-insensitive):
   ```
   BACKLOG.md, backlog.md, TODO.md, todo.md, TASKS.md, tasks.md
   ```

2. **CLAUDE.md sections** — if no dedicated file found, scan `CLAUDE.md` for sections:
   ```
   ## Backlog, ## TODO, ## Tasks, ## Задачи, ## Бэклог
   ```

3. **Not found** — no backlog detected. Skip backlog integration silently.

### Detection command

```bash
# Check for dedicated files
ls BACKLOG.md backlog.md TODO.md todo.md TASKS.md tasks.md 2>/dev/null | head -1

# If none found, check CLAUDE.md for backlog section
grep -n -i '^## \(backlog\|todo\|tasks\|задачи\|бэклог\)' CLAUDE.md 2>/dev/null
```

**Result:** path to backlog file + optionally the line number of the section start.

## Supported Formats

The backlog can use any of these task formats:

### Checkbox list (most common)

```markdown
- [ ] Add user authentication
- [ ] Implement payment gateway
- [x] Set up CI/CD pipeline
```

### Checkbox list with categories

```markdown
## Features
- [ ] Add user authentication
- [ ] Implement payment gateway

## Bugs
- [ ] Fix login redirect loop
```

### Numbered list

```markdown
1. [ ] Add user authentication
2. [ ] Implement payment gateway
3. [x] Set up CI/CD pipeline
```

### Inline section in CLAUDE.md

```markdown
## Backlog
- [ ] Add user authentication
- [ ] Implement payment gateway

## Other Section
...
```

**When backlog is a section inside CLAUDE.md:** only modify lines within that section (up to the next `##` heading or end of file).

## Task Matching

The user explicitly specifies which task to link. Match using **substring search** (case-insensitive).

### Matching rules

1. **Exact line match** — user's text is a substring of a backlog line
2. **Fuzzy match** — if no exact match, find lines where most words from user's query appear
3. **Multiple matches** — present options and ask user to pick one
4. **No match** — inform user, offer to add the task to the backlog or skip

### Example matching

User says: "create worktree for 'payment gateway'"

Backlog contains:
```markdown
- [ ] Add user authentication
- [ ] Implement payment gateway integration
- [x] Set up CI/CD pipeline
```

Match: line 2 ("payment gateway" is a substring of "Implement payment gateway integration").

### Adding a task (when not found)

If the user wants to add the task to the backlog:

1. **Dedicated file** — append `- [ ] <task text>` at the end of the file (or at the end of the relevant category section if the file uses headings)
2. **CLAUDE.md section** — append to the end of the backlog section (before the next `##` heading)
3. Then proceed with the normal matching and update flow

### Already in progress

If the matched task already has a `🔄` marker or `[-]` status:
```
Task "Implement payment gateway" is already marked as in progress.
Update the branch/worktree info? (y/n)
```

### Already completed

If the matched task has `[x]` status:
```
Task "Set up CI/CD pipeline" is already completed.
Create worktree anyway without backlog update? (y/n)
```

## Status Update Format

Transform the matched task line to indicate "in progress" status.

### Format

**Before:**
```markdown
- [ ] Implement payment gateway integration
```

**After:**
```markdown
- [-] Implement payment gateway integration (🔄 branch: feat/payment-gateway, worktree: .worktrees/feat-payment-gateway)
```

### Rules

| Element | Format |
|---------|--------|
| Checkbox | `[ ]` → `[-]` |
| Original text | Preserved exactly |
| Status suffix | `(🔄 branch: <name>, worktree: <path>)` |

### For numbered lists

**Before:**
```markdown
1. [ ] Implement payment gateway
```

**After:**
```markdown
1. [-] Implement payment gateway (🔄 branch: feat/payment-gateway, worktree: .worktrees/feat-payment-gateway)
```

### For CLAUDE.md sections

Edit only the matched line within the backlog section. Do not touch other parts of the file.

## Update Mechanics

### When to update

Update the backlog **after** the worktree environment is fully ready (after Phase 4 for backend, after F4 for frontend) but **before** the final report.

### Where to update

Edit the file in the **original repo directory** (not inside the worktree). The current working directory should still be the original repo root at this point.

### How to update

1. Read the backlog file
2. Find the matched task line
3. Replace the line with the updated version
4. Save the file — do NOT commit

```bash
# The file is in the original working tree, e.g.:
# /path/to/repo/BACKLOG.md       ← original branch
# /path/to/repo/.worktrees/feat/ ← worktree (do NOT edit here)
```

### Report the update

Include in the final report:

```
Backlog updated:
  File:   BACKLOG.md
  Task:   "Implement payment gateway integration"
  Status: [-] in progress
  Branch: feat/payment-gateway
  Worktree: .worktrees/feat-payment-gateway

  ⚠ Change is uncommitted — commit when ready.
```

## Teardown Integration

When tearing down a worktree, **optionally** revert the backlog status:

1. Detect which task was linked to this worktree (search for `🔄.*worktree: <path>` pattern)
2. Ask user:
   ```
   Task "Implement payment gateway" is linked to this worktree.
   What should happen to the backlog entry?
     1. Mark as completed [x]
     2. Revert to pending [ ]
     3. Leave as-is [-]
   ```
3. Update accordingly in the original repo directory

## Edge Cases

| Situation | Handling |
|-----------|----------|
| Backlog file not found | Skip silently, proceed with normal worktree flow |
| User didn't mention a task | Skip backlog integration |
| Task not found in backlog | Ask: add it or skip? |
| Multiple matches | Show matches, ask user to pick |
| Task already in progress | Offer to update branch/worktree info |
| Task already completed | Ask if worktree still needed, skip update |
| Backlog in CLAUDE.md | Edit only within the backlog section |
| Backlog has unusual format | Attempt best-effort match; warn if format unclear |
| File is read-only | Warn user, skip update |
