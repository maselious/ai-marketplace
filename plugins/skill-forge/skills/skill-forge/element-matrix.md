# Element Matrix

Which structural elements to include based on skill type.

## Decision Table

| Element | Audit/Discipline | Scaffold/Reference | Orchestrator | Research/Synthesis |
|---------|-----------------|-------------------|-------------|-------------------|
| Flowchart (dot) | - | - | always | optional |
| Gates (user confirmation) | - | - | always | optional |
| Baseline test (RED phase) | always | - | optional | - |
| Report template | always | - | - | optional |
| BLOCKER/WARN/INFO classification | always | - | optional | - |
| Critical Violations (Block Merge) | if safety-related | - | - | - |
| Rationalization table | optional | - | - | - |
| Code templates | - | always | - | - |
| Naming conventions table | - | if generates files | - | - |
| Quick reference table | - | always | - | - |
| TodoWrite upfront | - | - | always | optional |
| Skill dispatch table | - | - | if invokes skills | - |
| Step 0: parallel dispatch | - | - | if uses subagents | if uses subagents |
| Scenario test cases | if verifiable | - | - | - |
| Docker verification | if produces code | if produces code | always | - |
| Sources catalog | - | - | - | always |
| Analysis framework | - | - | - | always |
| Quality criteria | - | - | - | always |
| Output spec | - | - | - | always |

## How to Read This Table

- **always**: Include this element, it's essential for the type
- **optional**: Include if the specific skill needs it
- **if [condition]**: Include only when condition applies
- **-**: Do not include, not relevant for this type

## Adding New Types

To add a new skill type:
1. Add a column to this table
2. Mark each element as always / optional / conditional / -
3. Create a `methodology-{type}.md` file
4. Update the classification table in `SKILL.md` Phase 1
