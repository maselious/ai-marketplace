# Methodology: TDD (Audit / Discipline Skills)

Use this methodology when creating skills that verify, review, or enforce rules.
Examples: `audit-security`, `audit-psychology`, safety checks, code review checklists.

## Core Principle

"Watch the test fail before writing the fix." Document what goes wrong WITHOUT the skill before writing the skill.

## Process

### Step 1: RED — Baseline Failures

Document what happens when this audit/check is NOT performed:

```markdown
## Baseline Failures
- [Failure 1]: Agent did X instead of Y
- [Failure 2]: Step Z was skipped because...
- [Missed check]: Security vulnerability not caught because...
```

Sources for baseline:
- Past incidents in the project
- Known anti-patterns from CLAUDE.md
- Common mistakes in the domain

### Step 2: GREEN — Write Minimal Skill

Write the skill with the minimum rules needed to catch all baseline failures:

1. **Checklist** — one item per baseline failure
2. **Report template** — structured output with status columns:
   ```markdown
   | Category | Status | Notes |
   |----------|--------|-------|
   | Auth     | ✅/⚠️/❌ | ... |
   ```
3. **Critical Violations (Block Merge)** — if any failure is safety-critical:
   ```markdown
   ## Critical Violations (Block Merge)
   1. **[Violation name]** — [Why it blocks]
   2. ...
   ```

### Step 3: REFACTOR — Harden

1. **Add BLOCKER/WARNING/INFO classification:**
   ```markdown
   | Level | Meaning | Action |
   |-------|---------|--------|
   | BLOCKER | Must fix now | Block merge |
   | WARNING | Should fix | User decides |
   | INFO | Nice to have | Add to backlog |
   ```

2. **Add scenario test cases** (if verifiable):
   ```markdown
   ## Test Scenarios
   | # | Scenario | Expected | Check |
   |---|----------|----------|-------|
   | 1 | User submits empty form | Validation error | ✅/❌ |
   ```

3. **Add rationalization table** (optional, for discipline skills):
   ```markdown
   | Excuse | Reality |
   |--------|---------|
   | "Too simple to check" | Simple things break. Run the checklist. |
   ```

## Structural Pattern

```markdown
# Skill Name

## Overview
## When to Use
## Context (if domain background needed)

## Process
### Step 0: Dispatch (if parallel subagent needed)
### Step 1: Identify scope
### Step 2: Run checks (checklist)
### Step 3: Classify findings (BLOCKER/WARNING/INFO)
### Step 4: Generate report

## Critical Violations (Block Merge)
## Test Scenarios (if applicable)
## Checklist
## Self-Improvement Protocol
```
