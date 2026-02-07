---
name: forge
description: Quick entry point for skill-forge. Create, improve, or audit skills.
---

# /forge — Skill Forge Quick Menu

Determine the user's intent from their input or ask:

## Intent Detection

| Input contains | Intent | Action |
|---------------|--------|--------|
| `create`, `new`, no arguments | CREATE | Invoke `skill-forge` skill in CREATE mode |
| `improve`, `fix`, `update` + skill name | IMPROVE | Invoke `skill-forge` skill in IMPROVE mode |
| `audit`, `review`, `check` | AUDIT | Dispatch `skill-reviewer` agent |

## Usage Examples

```
/forge                    → Ask: Create, Improve, or Audit?
/forge create             → Start CREATE flow
/forge improve migration  → Start IMPROVE flow for migration skill
/forge audit              → Run skill-reviewer on all skills
/forge audit cqrs-scaffold → Run skill-reviewer on specific skill
```

## Execution

1. Parse the user's input to determine intent and optional target
2. For CREATE: invoke the `skill-forge` skill — it will handle Phase 0 routing
3. For IMPROVE: invoke the `skill-forge` skill with the target skill name
4. For AUDIT: dispatch the `skill-reviewer` agent with appropriate scope

If no arguments provided, present a quick choice:
- **Create** — new skill from a pattern or requirement
- **Improve** — fix or enhance an existing skill
- **Audit** — review skill quality and consistency
