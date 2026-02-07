---
name: skill-forge
description: Use when creating new skills, improving existing skills, or when Self-Improvement Protocol fires. Triggers on "create skill", "need a skill for", "pattern repeats", "should be a skill", "improve skill", "skill is wrong", "update skill", "skill gap", "fix skill".
---

# Skill Forge

Unified controller for skill lifecycle: creation and improvement. Classifies intent and type, loads the right methodology, applies user conventions.

## Phase 0: Determine Intent

Classify the incoming request:

| Signal | Intent | Next |
|--------|--------|------|
| "create skill", "new skill", "pattern repeats", "should be a skill" | **CREATE** | → Phase 1 |
| "improve skill", "fix skill", "skill gap", "skill missed", "Self-Improvement Protocol fired" | **IMPROVE** | → Phase 4 |

---

## CREATE Flow (Phases 1–3)

### Phase 1: Understand & Classify

1. **Identify the pattern:**
   - What problem does it solve?
   - When does it apply?
   - What goes wrong without it?

2. **Check for duplicates:**
   - Search project `.claude/skills/`
   - Search user `~/.claude/skills/`
   - If exists → switch to IMPROVE intent

3. **Classify skill type:**

| Type | When | Methodology file |
|------|------|-----------------|
| **Audit / Discipline** | Review, verification, safety checks, merge gates | `methodology-tdd.md` |
| **Scaffold / Reference** | Code generation, templates, naming rules, API reference | `methodology-scaffold.md` |
| **Workflow / Orchestrator** | Multi-phase process, skill dispatch, parallel agents, gates | `methodology-orchestrator.md` |

If unclear → ask user to confirm type before proceeding.

### Phase 2: Load & Create

1. **ALWAYS read** from this skill's directory:
   - `conventions.md` — user's style rules, mandatory sections, naming
   - `element-matrix.md` — which elements to include for this type

2. **Read methodology file** based on classified type:
   - Audit/Discipline → `methodology-tdd.md`
   - Scaffold/Reference → `methodology-scaffold.md`
   - Workflow/Orchestrator → `methodology-orchestrator.md`

3. **Write the skill** following loaded methodology + conventions

4. **Determine placement:**
   - Project-specific → `{project}/.claude/skills/{skill-name}/SKILL.md`
   - Cross-project → `~/.claude/skills/{skill-name}/SKILL.md`

### Phase 3: Register

1. **Read target project's CLAUDE.md**
2. **If skill is mandatory** (prevents bugs/data loss/security issues):
   - Add entry to "Mandatory Skill Usage" table
   - Add to pipeline ordering if relevant
3. **If skill is optional** — do NOT modify CLAUDE.md
4. **Inform user:** skill name, location, triggers, type, when to use

---

## IMPROVE Flow (Phases 4–6)

### Phase 4: Identify & Classify

1. **Identify target skill** — which skill needs improvement?
2. **Read the target skill** — understand current structure
3. **Read** `methodology-improving.md` from this skill's directory
4. **Read** `conventions.md` — to verify against current conventions

5. **Classify issue type:**

| Type | Signal |
|------|--------|
| **Gap** | Skill missed a case or scenario |
| **Outdated** | Project conventions changed |
| **New pattern** | Repeated behavior not captured |
| **Wrong output** | Skill produced incorrect result |
| **Structural** | Skill hard to follow |
| **Scope creep** | Skill does too many things |

### Phase 5: Apply Fix

Follow `methodology-improving.md` for fix approach based on issue type.

**GATE:** Concrete evidence required. "I think it could be better" is not evidence.

### Phase 6: Validate

- No contradictions introduced
- Standard structure preserved
- Related skills not broken
- Changes are minimal — didn't rewrite what worked

---

## Self-Improvement Protocol

After each use:
1. **New skill type discovered?** → Add to Phase 1 classification table, create methodology file
2. **Convention gap?** → Update `conventions.md`
3. **Element matrix incomplete?** → Update `element-matrix.md`
4. **Methodology gap?** → Update the specific methodology file
