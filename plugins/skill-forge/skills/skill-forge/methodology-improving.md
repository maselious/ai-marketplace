# Methodology: Improving Existing Skills

Use this methodology when fixing, updating, or enhancing an existing skill based on concrete evidence.

## Core Principle

"Surgical fixes, not rewrites." Change the minimum needed to address the specific issue. Every change must have concrete evidence behind it.

## Process

### Step 1: Classify Issue

| Type | Signal | Typical Scope |
|------|--------|--------------|
| **Gap** | Skill missed a case or scenario | Add decision branch or rule |
| **Outdated** | Project conventions changed | Update rule text |
| **New pattern** | Repeated behavior not captured | Add to workflow or new step |
| **Wrong output** | Skill produced incorrect result | Fix template or decision logic |
| **Structural** | Skill hard to follow/parse | Restructure without changing logic |
| **Scope creep** | Skill does too many things | Split → CREATE new skill for extracted part |

### Step 2: Gather Evidence

Document the specific failure:

```markdown
## Evidence
- **Skill:** [skill-name]
- **Issue type:** [gap/outdated/new-pattern/wrong-output/structural/scope-creep]
- **What happened:** [concrete description]
- **Expected:** [what should have happened]
- **Root cause:** [which section/rule failed or is missing]
```

**GATE:** Do NOT proceed without concrete evidence. "I think it could be better" is not evidence. Wait for a real failure.

### Step 3: Apply Fix

By issue type:

**Gap:**
- Add decision branch to existing step
- Add rule to checklist
- Add anti-pattern if applicable

**Outdated:**
- Update the specific rule text
- Check if other rules reference the changed one
- Update templates if affected

**New pattern:**
- Add to existing step if it fits naturally
- Create new step only if pattern is distinct enough
- Update triggers in frontmatter if new activation phrases needed

**Wrong output:**
- Fix the output template first
- Trace back to the decision that produced wrong output
- Add guard rule to prevent recurrence

**Structural:**
- Restructure for clarity
- Split overly long steps
- Do NOT change logic — only presentation

**Scope creep:**
- Identify the secondary concern
- Switch to CREATE intent (invoke skill-forge) for extracted part
- Simplify original skill to single concern

### Step 4: Validate

- [ ] Standard structure preserved (frontmatter, overview, process, checklist, self-improvement)
- [ ] No contradictions between rules
- [ ] Triggers still accurate after changes
- [ ] Output template reflects updated logic
- [ ] Related skills not broken by changes
- [ ] Changes are minimal — didn't rewrite what worked

## Anti-Patterns

| Mistake | Fix |
|---------|-----|
| Full rewrite for one edge case | Change only the affected section |
| Improving without evidence | GATE: concrete failure required |
| Cascading fixes (A→B→C) | Stop. Rethink the approach. |
| "Improving" working logic | Only fix what actually failed |
| Circular loops (A improves B improves A) | Detect cycle, break it |
