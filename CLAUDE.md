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
2. Add entry to `.claude-plugin/marketplace.json` -> `plugins` array
3. Bump marketplace `metadata.version` on any change

### Plugin Manifest (plugin.json)
- `name`: kebab-case, must match directory name and marketplace entry
- `version`: semver, bump on any change to plugin contents
- `skills`/`agents`/`commands`: arrays of relative paths to component directories

### Marketplace Catalog (marketplace.json)
- `metadata.pluginRoot`: `"./plugins"` -- all plugin sources are relative to this
- Each plugin `source` is relative to `pluginRoot`

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
