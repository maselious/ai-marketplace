#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook: detect active worktree and remind agent to cd into it.
# Reads state file from $CLAUDE_PROJECT_DIR/.claude/dev-worktree.local.md
# Outputs JSON systemMessage if active worktree found.

# Consume stdin (hook input JSON) — we only need CLAUDE_PROJECT_DIR env var
cat > /dev/null

project_dir="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$project_dir" ]; then
  exit 0
fi

STATE_FILE="$project_dir/.claude/dev-worktree.local.md"

# No state file → nothing to do
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# Parse YAML frontmatter (between first and second ---)
frontmatter=$(sed -n '2,/^---$/p' "$STATE_FILE" | head -n -1)

worktree_path=$(echo "$frontmatter" | grep '^active_worktree:' | sed 's/^active_worktree: *//' || true)
branch=$(echo "$frontmatter" | grep '^branch:' | sed 's/^branch: *//' || true)

# No worktree path → corrupted file, clean up
if [ -z "$worktree_path" ]; then
  rm -f "$STATE_FILE"
  exit 0
fi

# Worktree directory gone → clean up state file
if [ ! -d "$worktree_path" ]; then
  rm -f "$STATE_FILE"
  exit 0
fi

# Build systemMessage
branch_info=""
if [ -n "$branch" ]; then
  branch_info=" (branch: $branch)"
fi

# Output JSON for Claude Code
printf '{"systemMessage":"ACTIVE WORKTREE: You have an active worktree at %s%s. You MUST cd to this directory before running any commands. Run: cd %s"}\n' \
  "$worktree_path" "$branch_info" "$worktree_path"
