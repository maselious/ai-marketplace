# Worktree Session Guard — Design

## Problem

When Claude Code sessions restore (via `/resume` or auto-restore), the CWD resets to the main repository directory. If the agent was working inside a git worktree, it loses track of the active worktree and continues working in the main tree.

### Affected Scenarios

| Scenario | Impact |
|----------|--------|
| Session restore (`/resume`) | CWD resets to main repo |
| New session in same project | No knowledge of active worktree |

### Out of Scope (this iteration)

- Plan mode exit (same session, no SessionStart trigger)
- Agent forgetting to return after cd-ing out (no trigger)

## Solution: SessionStart Hook + State File

### Architecture

```
[Skill: create worktree] ──writes──► .claude/dev-worktree.local.md (state file)
                                           │
[SessionStart hook] ────reads──────────────┘
         │
         ├─ state file exists + dir valid → systemMessage: "cd to worktree"
         ├─ state file exists + dir gone  → clean up state file
         └─ no state file                 → exit 0 (no-op)

[Skill: teardown worktree] ──clears──► .claude/dev-worktree.local.md
```

### Component 1: State File

**Location:** `$CLAUDE_PROJECT_DIR/.claude/dev-worktree.local.md`

Follows the plugin settings convention (`.local.md` files are gitignored).

**Format (YAML frontmatter):**

```yaml
---
active_worktree: /absolute/path/to/.worktrees/feat-auth
branch: feat/auth
compose_project: gm-wt1
created: 2026-02-13
---
Active worktree session. Managed by dev-worktree plugin.
```

### Component 2: SessionStart Hook Script

**Location:** `hooks/scripts/check-active-worktree.sh`

**Logic:**

```
1. Read state file from $CLAUDE_PROJECT_DIR/.claude/dev-worktree.local.md
2. If file doesn't exist → exit 0
3. Parse active_worktree path from YAML frontmatter
4. If directory doesn't exist → remove state file, exit 0
5. Output JSON with systemMessage reminder
```

**Output on match:**

```json
{
  "systemMessage": "ACTIVE WORKTREE: You have an active worktree at /path/.worktrees/feat-auth (branch: feat/auth). You MUST cd to this directory before running any commands. Run: cd /path/.worktrees/feat-auth"
}
```

### Component 3: hooks.json

**Location:** `plugins/dev-worktree/hooks/hooks.json`

```json
{
  "description": "Detects active worktree on session start and reminds agent to cd into it",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/check-active-worktree.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

### Component 4: Skill Modifications

**On worktree creation (Phase 3 / F1):**
- After creating the worktree and cd-ing into it, write the state file
- Include: absolute worktree path, branch name, compose project (if backend), date

**On teardown (Teardown Step 5):**
- After removing the worktree, delete the state file
- Search for state file by worktree path match (in case multiple worktrees exist)

## Edge Cases

| Case | Handling |
|------|----------|
| Worktree deleted outside plugin | Hook detects missing dir, cleans state file |
| Multiple worktrees | State file tracks the LAST created/entered one |
| Session started from different project | State file is per-project, no conflict |
| State file corrupted | Hook fails gracefully (exit 0), no crash |

## File Changes Summary

| File | Action |
|------|--------|
| `hooks/hooks.json` | **Create** — register SessionStart hook |
| `hooks/scripts/check-active-worktree.sh` | **Create** — hook script |
| `skills/dev-worktree/SKILL.md` | **Edit** — add state file write/clear steps |
| `.claude-plugin/plugin.json` | **Edit** — bump version to 0.4.0 |
