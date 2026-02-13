# Worktree Session Guard — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a SessionStart hook to the dev-worktree plugin that detects active worktrees and reminds the agent to cd back into them on session restore.

**Architecture:** State file (`.claude/dev-worktree.local.md`) written by skill on worktree creation, read by SessionStart bash hook on session start. Hook outputs `systemMessage` if active worktree found.

**Tech Stack:** Bash (hook script), Markdown with YAML frontmatter (state file, skill edits), JSON (hooks.json)

---

### Task 1: Create the hook script

**Files:**
- Create: `plugins/dev-worktree/hooks/scripts/check-active-worktree.sh`

**Step 1: Create the hook script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Read hook input from stdin (contains cwd, session_id, etc.)
input=$(cat)

# Determine project directory from hook input or env
project_dir="${CLAUDE_PROJECT_DIR:-$(echo "$input" | grep -o '"cwd":"[^"]*"' | head -1 | cut -d'"' -f4)}"

STATE_FILE="$project_dir/.claude/dev-worktree.local.md"

# No state file → nothing to do
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# Parse active_worktree from YAML frontmatter
# Frontmatter is between first --- and second ---
worktree_path=$(sed -n '/^---$/,/^---$/p' "$STATE_FILE" | grep '^active_worktree:' | sed 's/^active_worktree: *//')
branch=$(sed -n '/^---$/,/^---$/p' "$STATE_FILE" | grep '^branch:' | sed 's/^branch: *//')

# No worktree path found → corrupted file, clean up silently
if [ -z "$worktree_path" ]; then
  rm -f "$STATE_FILE"
  exit 0
fi

# Worktree directory no longer exists → clean up state file
if [ ! -d "$worktree_path" ]; then
  rm -f "$STATE_FILE"
  exit 0
fi

# Active worktree exists — output systemMessage
branch_info=""
if [ -n "$branch" ]; then
  branch_info=" (branch: $branch)"
fi

cat <<EOF
{"systemMessage": "ACTIVE WORKTREE: You have an active worktree at ${worktree_path}${branch_info}. You MUST cd to this directory before running any commands. Run: cd ${worktree_path}"}
EOF
```

**Step 2: Make script executable**

Run: `chmod +x plugins/dev-worktree/hooks/scripts/check-active-worktree.sh`

**Step 3: Test script manually (no state file)**

Run:
```bash
echo '{"cwd":"/tmp","session_id":"test"}' | CLAUDE_PROJECT_DIR="/tmp" bash plugins/dev-worktree/hooks/scripts/check-active-worktree.sh
echo "Exit code: $?"
```
Expected: empty output, exit code 0

**Step 4: Test script manually (with state file)**

Run:
```bash
mkdir -p /tmp/test-wt/.claude
cat > /tmp/test-wt/.claude/dev-worktree.local.md << 'HEREDOC'
---
active_worktree: /tmp
branch: feat/test
---
Active worktree session.
HEREDOC
echo '{"cwd":"/tmp","session_id":"test"}' | CLAUDE_PROJECT_DIR="/tmp/test-wt" bash plugins/dev-worktree/hooks/scripts/check-active-worktree.sh
```
Expected: JSON with systemMessage containing `/tmp` and `feat/test`

**Step 5: Test script manually (stale worktree — dir gone)**

Run:
```bash
cat > /tmp/test-wt/.claude/dev-worktree.local.md << 'HEREDOC'
---
active_worktree: /tmp/nonexistent-dir-12345
branch: feat/gone
---
Active worktree session.
HEREDOC
echo '{"cwd":"/tmp","session_id":"test"}' | CLAUDE_PROJECT_DIR="/tmp/test-wt" bash plugins/dev-worktree/hooks/scripts/check-active-worktree.sh
echo "Exit code: $?"
ls /tmp/test-wt/.claude/dev-worktree.local.md 2>&1
```
Expected: empty output, exit code 0, state file deleted

**Step 6: Clean up test files**

Run: `rm -rf /tmp/test-wt`

**Step 7: Commit**

```bash
git add plugins/dev-worktree/hooks/scripts/check-active-worktree.sh
git commit -m "✨ Add session guard hook script for worktree detection"
```

---

### Task 2: Create hooks.json

**Files:**
- Create: `plugins/dev-worktree/hooks/hooks.json`

**Step 1: Create hooks.json**

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

**Step 2: Validate JSON syntax**

Run: `cat plugins/dev-worktree/hooks/hooks.json | python3 -m json.tool > /dev/null && echo "Valid JSON"`
Expected: "Valid JSON"

**Step 3: Commit**

```bash
git add plugins/dev-worktree/hooks/hooks.json
git commit -m "✨ Register SessionStart hook in hooks.json"
```

---

### Task 3: Modify SKILL.md — add state file management

**Files:**
- Modify: `plugins/dev-worktree/skills/dev-worktree/SKILL.md`

Three insertions needed:

**Step 1: Add "Session State" section between Phase 4 and Backlog Update**

Insert after the Phase 4 Step 5 (Verify) section, before the "## Backlog Update" heading:

```markdown
## Session State

After the worktree is created and verified, write a state file so the SessionStart hook can detect the active worktree on session restore.

### Write state file

Create `.claude/dev-worktree.local.md` in the **original project root** (not the worktree):

```bash
mkdir -p "$PROJECT_ROOT/.claude"
cat > "$PROJECT_ROOT/.claude/dev-worktree.local.md" << EOF
---
active_worktree: $(pwd)
branch: <branch-name>
compose_project: <compose-project-name-or-empty>
created: $(date +%Y-%m-%d)
---
Active worktree session. Managed by dev-worktree plugin.
EOF
```

Where `$PROJECT_ROOT` is the main working tree root (`git worktree list | head -1 | awk '{print $1}'`).

**Frontend mode:** Same step, but `compose_project` is empty.
```

**Step 2: Add state file clear step in Teardown — between Step 5 and Step 6**

After "### Step 5: Remove worktree", insert:

```markdown
### Step 5.5: Clear session state

Remove the state file if it points to the worktree being torn down:

```bash
STATE_FILE="$(git worktree list | head -1 | awk '{print $1}')/.claude/dev-worktree.local.md"
if [ -f "$STATE_FILE" ] && grep -q ".worktrees/<slug>" "$STATE_FILE"; then
  rm "$STATE_FILE"
fi
```
```

**Step 3: Add Frontend Mode note in F5**

In the "### F5: Report + Save Learnings" section, add before "**Save learnings:**":

```markdown
**Session state:** Write the state file (see "Session State" section above). Use the same format, with empty `compose_project`.
```

**Step 4: Commit**

```bash
git add plugins/dev-worktree/skills/dev-worktree/SKILL.md
git commit -m "📝 Add session state management to worktree skill"
```

---

### Task 4: Bump plugin version

**Files:**
- Modify: `plugins/dev-worktree/.claude-plugin/plugin.json`

**Step 1: Bump version from 0.3.1 to 0.4.0**

Change `"version": "0.3.1"` to `"version": "0.4.0"` (minor bump — new feature).

**Step 2: Commit**

```bash
git add plugins/dev-worktree/.claude-plugin/plugin.json
git commit -m "🔖 Bump dev-worktree to v0.4.0 (session guard hook)"
```

---

### Task 5: End-to-end verification

**Step 1: Verify plugin structure**

Run:
```bash
ls -la plugins/dev-worktree/hooks/hooks.json
ls -la plugins/dev-worktree/hooks/scripts/check-active-worktree.sh
```
Expected: both files exist

**Step 2: Verify hooks.json is valid**

Run: `python3 -m json.tool plugins/dev-worktree/hooks/hooks.json`
Expected: formatted JSON output

**Step 3: Verify hook script is executable**

Run: `test -x plugins/dev-worktree/hooks/scripts/check-active-worktree.sh && echo "Executable"`
Expected: "Executable"

**Step 4: Verify plugin.json version**

Run: `grep version plugins/dev-worktree/.claude-plugin/plugin.json`
Expected: `"version": "0.4.0"`

**Step 5: Run full hook test cycle**

```bash
# Setup: create fake state file
mkdir -p /tmp/e2e-test/.claude
cat > /tmp/e2e-test/.claude/dev-worktree.local.md << 'HEREDOC'
---
active_worktree: /tmp
branch: feat/e2e
compose_project: test-project
created: 2026-02-13
---
Active worktree session.
HEREDOC

# Test: hook detects active worktree
result=$(echo '{}' | CLAUDE_PROJECT_DIR="/tmp/e2e-test" bash plugins/dev-worktree/hooks/scripts/check-active-worktree.sh)
echo "$result" | python3 -m json.tool

# Cleanup
rm -rf /tmp/e2e-test
```

Expected: valid JSON with systemMessage containing `/tmp` and `feat/e2e`
