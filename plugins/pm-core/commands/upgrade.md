---
name: upgrade
description: Analyze project changes and update generated dev-skills (Phase Beta)
argument-hint: "[--check | --apply]"
---

# /pm:upgrade — Update Generated Skills

> **Phase Beta** — This command is a stub. Full implementation in a future pm-core version.

When implemented, upgrade will:
1. Compare current project state with generated skills
2. Detect: new patterns, convention drift, missing rules
3. Propose updates with reasoning
4. Apply approved changes (preserving user customizations)

For now, manually update generated files in `.claude/` when the project evolves.
