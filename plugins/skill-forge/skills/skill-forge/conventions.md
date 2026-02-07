# Skill Conventions

Rules that apply to ALL skills regardless of type. Read this file ALWAYS before creating or improving a skill.

## Frontmatter

Every skill MUST have YAML frontmatter:

```yaml
---
name: kebab-case-name
description: Use when [conditions]. Triggers on 'keyword1', 'keyword2', 'keyword3'.
---
```

- `name`: kebab-case, pragmatic naming (verb-first when natural, domain terms OK: `migration`, `cqrs-scaffold`)
- `description`: starts with "Use when..." or "Use after...", ends with `Triggers on '...'`
- Triggers: single-quoted, comma-separated, 3-7 phrases

## Mandatory Sections

Every skill MUST include:

1. **H1 Title** — descriptive, not just the skill name
2. **Overview** — 1-3 sentences: what + core principle
3. **Process / Workflow** — the main body (steps or phases)
4. **Checklist** — `- [ ]` verification items
5. **Self-Improvement Protocol** — ALWAYS the last section

## Self-Improvement Protocol Format

Use **concrete project actions**, not generic meta-skill invocations:

```markdown
## Self-Improvement Protocol

After each [use/audit/generation]:
1. **[Specific discovery]?** → [Concrete action: update specific file, add to specific list]
2. **[Gap type]?** → [Concrete action]
3. **Structural issue with this skill?** → Invoke `skill-forge` in IMPROVE mode
```

Only reference `skill-forge` for structural issues with the skill itself. All other improvements should describe the actual artifact to update.

## Heading Hierarchy

- Use heading hierarchy for visual separation (H1 → H2 → H3)
- Do NOT use horizontal rules (`---`) as section separators
- Steps: `### Step N: Title` (H3 under `## Process`)
- Phases: `## Phase N: Title` (H2) — only for orchestrator-type skills

## Naming

- Skill directory: kebab-case (`audit-security`, `migration`)
- No transliterations from Russian
- Project-specific naming rules (file casing, DTO style) belong in the skill itself, not here

## Tables

Preferred format for:
- Decision matrices ("when to use X vs Y")
- Naming conventions (artifact → file → class)
- Report templates (Category | Status | Notes)
- Element selection (type → elements)

## Code Examples

- Include as many templates as the domain requires (no artificial "one example" limit)
- Keep each example < 10 lines
- Use for: templates, naming patterns, verification commands

## Docker Verification

Skills that produce code changes SHOULD end with verification:

```bash
docker exec <container> <lint-command>
docker logs <container> --tail 50
```

Replace `<container>` and `<lint-command>` with project-specific values.
Skip for skills that don't produce runnable code (pure reference, pure analysis).

## CLAUDE.md Registration

After creating a skill, check if it should be registered:

| Condition | Action |
|-----------|--------|
| Skill prevents bugs, data loss, or security issues | Add to "Mandatory Skill Usage" table in project CLAUDE.md |
| Skill is part of feature pipeline | Add to pipeline ordering |
| Skill is optional/convenience | Do NOT modify CLAUDE.md |

## Word Count

No hard limit. Prioritize completeness over brevity. Typical ranges:

| Type | Typical size |
|------|-------------|
| Scaffold/Reference | 100-200 lines |
| Audit/Discipline | 150-300 lines |
| Orchestrator | 200-350 lines |

## Bilingual Context

- Skill instructions: English
- Test scenarios and examples: may include Russian where domain requires it
- Russian psychological terms: keep original, don't translate
