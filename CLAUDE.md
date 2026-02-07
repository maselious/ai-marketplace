# AI Marketplace

Personal Claude Code plugin marketplace. Distributed via GitHub, installed on any machine.

## Project Structure

```
.claude-plugin/marketplace.json    <- Plugin catalog (name: marisko-skills)
plugins/{plugin-name}/
  .claude-plugin/plugin.json       <- Plugin manifest (name, version, components)
  skills/{skill}/SKILL.md          <- Skills (+ reference .md files in same dir)
  agents/*.md                      <- Subagent definitions
  commands/*.md                    <- Slash commands
  hooks/hooks.json                 <- Hooks (if any)
```

## Critical Rules

### Adding a Plugin
1. Create `plugins/{name}/` with `.claude-plugin/plugin.json`
2. Add entry to `.claude-plugin/marketplace.json` -> `plugins` array with `"source": "./plugins/{name}"`

### Plugin Manifest (plugin.json)
- `name`: kebab-case, must match directory name and marketplace entry
- `version`: semver, bump on any change to plugin contents
- Components (`skills/`, `agents/`, `commands/`) are auto-discovered — do NOT list them in plugin.json

### Marketplace Catalog (marketplace.json)
- Each plugin `source` is a relative path from repo root: `"./plugins/{name}"`
- Must include `$schema` field for validation

### Skills Convention
- Controller pattern: `SKILL.md` is the entry point, reference files are lazy-loaded
- Reference files: additional `.md` files in skill directory, read on demand by the skill
- Follow `skill-forge` conventions: frontmatter with `name`+`description`, mandatory sections (Overview, Process, Checklist, Self-Improvement Protocol)

### Installation (for users)
```bash
/plugin marketplace add maselious/ai-marketplace
/plugin install {plugin-name}@marisko-skills
```

## Naming
- Plugin names: kebab-case (`skill-forge`, `code-audit`)
- Skill names: kebab-case, pragmatic (verb-first when natural)
- Marketplace name: `marisko-skills` (referenced in install commands)

## Git
- Branch: `main`
- Commit format: emoji prefix + short summary
- No AI co-author attribution
