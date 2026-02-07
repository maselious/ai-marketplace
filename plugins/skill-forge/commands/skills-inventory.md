---
name: skills-inventory
description: List all installed skills across projects and user level with health status.
---

# /skills-inventory — Skills Overview

Scan all skill locations and produce a health report.

## Process

### Step 1: Discover Skills

Search these locations:
1. **Current project:** `.claude/skills/*/SKILL.md`
2. **User level:** `~/.claude/skills/*/SKILL.md`
3. **Installed plugins:** check `~/.claude/settings.json` for `enabledPlugins`

### Step 2: Quick Health Check

For each skill, perform a lightweight check (NOT full audit):

| Check | How |
|-------|-----|
| Frontmatter present | YAML `---` block at top |
| Has `name` field | In frontmatter |
| Has `description` field | In frontmatter |
| Has Checklist section | `## Checklist` heading exists |
| Has Self-Improvement Protocol | `## Self-Improvement` heading exists |
| Has reference files | Count of non-SKILL.md files in skill directory |

### Step 3: Classify Type

Quick heuristic (don't read full file):
- Contains "audit", "review", "check" in name/description → **Audit**
- Contains "scaffold", "template", "generate", "migration" → **Scaffold**
- Contains "implement", "workflow", "phase", "orchestrat" → **Orchestrator**
- Otherwise → **Unknown** (flag for review)

### Step 4: Output Report

```markdown
## Skills Inventory

### Project: {project-name} ({count} skills)

| Skill | Type | Health | Refs | Notes |
|-------|------|--------|------|-------|
| migration | Scaffold | ✅ | 0 | |
| cqrs-scaffold | Scaffold | ✅ | 0 | |
| audit-psychology | Audit | ✅ | 0 | |
| audit-security | Audit | ✅ | 0 | |
| ai-prompt-test | Audit | ⚠️ | 0 | Missing Self-Improvement Protocol |
| implement-feature | Orchestrator | ✅ | 0 | |

### User Level ({count} skills)

| Skill | Type | Health | Refs | Notes |
|-------|------|--------|------|-------|
| skill-forge | Orchestrator | ✅ | 6 | conventions, element-matrix, 4 methodologies |

### Summary
- Total: {N} skills ({project} project + {user} user-level)
- Healthy: {N} ✅
- Warnings: {N} ⚠️
- To fix: run `/forge audit` for detailed analysis
```

## Notes

- This is a quick scan, not a deep audit
- For detailed review, use `/forge audit`
- Health = structure check only, not content quality
