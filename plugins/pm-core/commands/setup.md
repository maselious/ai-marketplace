---
name: setup
description: Launch pm-core project setup wizard
argument-hint: "[--resume | --reset]"
---

# /pm:setup — Project Setup Wizard

Launch the project-setup wizard to generate customized dev-skills ecosystem.

## Execution

Invoke the `project-setup` skill. It manages all wizard gates interactively.

## Arguments

| Argument | Action |
|----------|--------|
| (none) | Start fresh or auto-resume if state file exists |
| `--resume` | Force resume from saved state |
| `--reset` | Delete state file and start fresh |

## Requirements

- `git` and `bash` must be available
- `gh` CLI recommended for GitHub integration (optional)
- Run in the target project root directory
