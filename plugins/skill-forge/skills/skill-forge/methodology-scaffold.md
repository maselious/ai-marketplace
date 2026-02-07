# Methodology: Scaffold (Template / Reference Skills)

Use this methodology when creating skills that generate code, files, or structured artifacts from templates.
Examples: `cqrs-scaffold`, `migration`, API endpoint generators, boilerplate creators.

## Core Principle

"Encode the template, not the process." The skill's value is in the concrete templates and naming rules, not in lengthy workflow descriptions.

## Process

### Step 1: Gather Examples

Find 2-3 existing instances of what this skill will generate:
- Search the codebase for existing patterns
- Identify the common structure
- Note the variations

### Step 2: Extract Templates

For each artifact the skill generates, create a code template:

```markdown
## Templates

### [Artifact Name]
**File:** `path/pattern/{name}.extension`
**Class:** `PascalCaseName`

\```typescript
// template code here
\```
```

Rules for templates:
- Each template < 10 lines (show structure, not implementation)
- Use `{placeholders}` for variable parts
- Include the file path pattern

### Step 3: Define Naming Conventions

Create a naming table:

```markdown
## Naming Conventions

| Artifact | File | Class/Export | Example |
|----------|------|-------------|---------|
| Command | `{name}.command.ts` | `{Name}Command` | `complete-task.command.ts` / `CompleteTaskCommand` |
```

### Step 4: Add Decision Points

If the skill generates different artifacts based on conditions:

```markdown
## Decision Points

| Condition | Generate | Skip |
|-----------|----------|------|
| Has side effects | Event + Workflow | - |
| Read-only | Query handler | Command handler |
```

### Step 5: Quick Reference

Provide a condensed reference for experienced users:

```markdown
## Quick Reference

1. Create file: `path/{name}.ts`
2. Register in: `path/index.ts`
3. Verify: `docker exec ucare-api yarn lint`
```

## Structural Pattern

```markdown
# Skill Name

## Overview
## When to Use
## Decision Points (if branching)

## Process
### Step 1: Determine what to generate
### Step 2: Generate artifacts (templates below)
### Step 3: Register / wire up
### Step 4: Verify

## Templates
### [Artifact 1]
### [Artifact 2]

## Naming Conventions
## Quick Reference
## Checklist
## Self-Improvement Protocol
```
