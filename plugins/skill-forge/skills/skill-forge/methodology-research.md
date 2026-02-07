# Methodology: Research / Synthesis Skills

Use this methodology when creating skills that gather data, analyze it, and produce synthesized output.
Examples: `analytics-report`, `ux-research`, `competitor-analysis`, `content-audit`, `data-migration-plan`.

## Core Principle

"Define sources and quality criteria, not the output template." The output is different every time — the skill's value is in knowing WHERE to look, HOW to analyze, and WHAT makes the result good.

## Process

### Step 1: Map Sources

Identify all data sources the skill needs. Create a sources catalog:

```markdown
## Sources

| Source | Type | What to extract |
|--------|------|-----------------|
| Database tables | DB query | Aggregate metrics, trends |
| Config files | File read | Current settings, thresholds |
| API responses | HTTP/MCP | Live data, status |
| User input | Ask | Goals, constraints, preferences |
| Codebase | Grep/Glob | Patterns, usage counts |
```

Rules:
- Each source must have a concrete extraction method (not "look at stuff")
- Mark sources as **required** vs **optional**
- If a source is unavailable, define a fallback or state it explicitly

### Step 2: Define Analysis Framework

Define the axes along which data will be analyzed:

```markdown
## Analysis Framework

| Axis | Question | Method |
|------|----------|--------|
| Coverage | How much of X is addressed? | Count / percentage |
| Trend | Is it getting better or worse? | Compare over time |
| Risk | What could go wrong? | Pattern matching |
| Impact | How significant is each finding? | Categorize H/M/L |
```

Rules:
- 3-6 axes (fewer = too shallow, more = unfocused)
- Each axis answers one concrete question
- Method must be actionable by an agent (no "use judgment")

### Step 3: Synthesis Rules

Define how findings combine into the output:

```markdown
## Synthesis Rules

1. **Group** findings by [axis / category / severity]
2. **Rank** within groups by [impact / frequency / urgency]
3. **Connect** related findings across groups
4. **Conclude** with [recommendations / action items / summary]
```

Rules:
- Synthesis is not "dump everything" — define grouping and ranking
- If the skill produces recommendations, state what makes a recommendation actionable
- If the skill produces a report, describe sections and their purpose (not rigid templates)

### Step 4: Quality Criteria

Define what makes the output good:

```markdown
## Quality Criteria

- [ ] **Completeness** — all required sources consulted, no gaps acknowledged without reason
- [ ] **Consistency** — no contradictions between sections
- [ ] **Actionability** — reader knows what to do next after reading
- [ ] **Evidence** — every claim traces back to a source
- [ ] **Scope** — stays within defined analysis axes, no tangents
```

Rules:
- 4-6 criteria (always include completeness, consistency, actionability)
- Each criterion must be verifiable (yes/no), not subjective ("is it good?")
- Add domain-specific criteria as needed

## Output Spec

Research skills describe output structure loosely, not as rigid templates:

```markdown
## Output Spec

**Format:** Markdown report / structured list / comparison table
**Sections:**
1. Executive summary (3-5 sentences)
2. Findings by [grouping axis]
3. Recommendations (if applicable)
4. Data appendix (raw data references)

**Length:** [approximate range, e.g. "200-500 lines depending on scope"]
```

The output spec tells the agent what sections to produce and why, but does NOT dictate exact formatting or word counts per section.

## Structural Pattern

```markdown
# Skill Name

## Overview
## Sources
[Sources catalog table]

## Analysis Framework
[Axes table]

## Process
### Step 1: Gather data from sources
### Step 2: Analyze along defined axes
### Step 3: Synthesize findings
### Step 4: Verify against quality criteria

## Output Spec
## Quality Criteria
## Checklist
## Self-Improvement Protocol
```
