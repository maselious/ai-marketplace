# pm-core — Project Management Meta-Tool

> Design document for a Claude Code plugin that analyzes any project and generates
> a customized ecosystem of dev-skills, agents, commands and quality gates.

**Date:** 2026-02-15
**Status:** Draft — Reviewed, ready for implementation planning
**Plugin location:** `plugins/pm-core/`
**Marketplace:** marisko-skills

---

## Problem Statement

We have excellent project-specific dev-skills (gm-platform-api, ff-api, ucare-api,
gm-platform), but each was created manually. Every new project requires hand-crafting
skills, commands, and agents from scratch. Additionally:

- Development pipeline is strictly sequential — one context, frequent compaction on
  large features
- No formal task management (only BACKLOG.md)
- No mechanism for parallel stream execution
- No self-improvement loop when the project evolves

## Vision

**pm-core is a "compiler" for dev-skills.** It takes "source" (project + user answers)
and "compiles" it into executable skills, commands, and agents in the project's `.claude/`
directory. After compilation, pm-core is not required — generated files are self-sufficient.

Key principle: **generate once, run independently.**

---

## Architecture Overview

### pm-core Plugin Structure

```
plugins/pm-core/
├── .claude-plugin/plugin.json
├── skills/
│   └── project-setup/
│       ├── SKILL.md                        # Wizard controller — 6 gates
│       └── references/
│           ├── architecture-audit.md        # How to analyze project fitness
│           ├── conductor-pattern.md         # Parallel conductor flow template
│           ├── contract-convention.md       # Naming convention template
│           ├── backlog-strategies.md        # Backlog discovery + capabilities
│           ├── backend-nestjs-template.md   # Template for NestJS + Clean Arch
│           ├── backend-generic-template.md  # Template for generic backend
│           ├── frontend-template.md         # Template for frontend (FSD/SPA)
│           ├── pm-commands-template.md      # Templates for /pm:* command generation
│           └── quality-patterns.md          # Library of proven quality checks
├── commands/
│   ├── setup.md                            # /pm:setup — launch wizard
│   └── upgrade.md                          # /pm:upgrade — improve existing skills
├── agents/
│   ├── architecture-auditor.md             # Deep project analysis
│   └── skill-generator.md                  # Generate project-specific files
```

### What Gets Generated in the Target Project

Example output for a NestJS backend with parallel + GitHub:

```
target-project/.claude/
├── CLAUDE.md                             # Updated: architecture, conventions
├── skills/
│   └── dev/
│       ├── SKILL.md                      # Project-specific dev skill (controller)
│       └── references/
│           ├── conductor.md              # How to orchestrate parallel streams
│           ├── contract-convention.md    # Naming: I{F}Repository, {F}Dto...
│           ├── schema-phase.md           # Phase 1: schema + contracts
│           ├── infra-stream.md           # Stream instructions: repositories
│           ├── app-stream.md             # Stream instructions: CQRS handlers
│           ├── interface-stream.md       # Stream instructions: controllers
│           ├── verification.md           # Phase 3: tsc + docker + quality
│           └── quality-gates.md          # Dynamic checklist from Gate 4
├── agents/
│   ├── infra-worker.md                   # Layer-specific: Prisma repos, DI
│   ├── app-worker.md                     # Layer-specific: handlers, events
│   └── interface-worker.md               # Layer-specific: controllers, DTOs
├── commands/
│   ├── dev.md                            # /dev — entry point
│   ├── pm-sync.md                        # /pm:sync — generated per capabilities
│   ├── pm-status.md                      # /pm:status
│   ├── pm-next.md                        # /pm:next
│   └── pm-standup.md                     # /pm:standup
├── hooks/
│   └── hooks.json                        # Self-improvement hook (Stop event)
└── pm/                                   # ← .gitignore!
    └── config.yaml                       # Wizard settings
```

---

## Wizard Flow — 6 Gates

The wizard runs interactively via `/pm:setup`. Each gate is a set of conceptual
questions with trade-offs. The user decides at the pipeline level; technical details
(files, templates) are generated automatically.

### Wizard State Persistence

At startup the wizard creates `.claude/pm-setup-state.yaml` (added to `.gitignore`).
This tracks progress so interrupted sessions can resume. Deleted upon completion.

```yaml
# .claude/pm-setup-state.yaml
---
wizard_version: "1.0"
started: 2026-02-15T12:00:00Z
current_gate: 3
gates:
  1: { completed: true, stack: "NestJS+Prisma", arch: "Clean", existing_skills: true }
  2: { completed: true, mode: "parallel-hybrid", conflict_zones: ["shared/types/"] }
  3: { completed: false }
---
```

### Gate 1: Project Understanding

- Audit stack, framework, ORM, directory structure
- Detect existing `.claude/` skills — reuse, improve, or replace?
- Map directories to architectural layers
- User confirms or corrects analysis

### Gate 2: Development Pipeline

**Default: parallel.** Alternatives offered only when architecture audit finds problems.

- **If architecture is well-separated** (no conflict zones):
  "Your architecture supports parallel development. Schema/Domain sequential,
  then Infra + App + Interface in parallel. Confirm?"

- **If conflict zones detected** (shared files, circular deps):
  Present options with trade-offs:
  - A: Parallel with restrictions (conflict zones serialized)
  - B: Sequential (safe, slower)
  - C: Refactor first, then parallel

### Gate 3: Task Tracking & Integrations

**Step 3.1 — Backlog location:**
- BACKLOG.md in project (default, always available)
- GitHub Issues (technical, via `gh` CLI — built-in support)
- User's choice (Notion, Linear, Jira, etc.)

**Step 3.2 — Tech/business split:**
- "Do you want to separate technical and business tasks?"
- If yes: where to track each?
- Technical → GitHub Issues / BACKLOG.md
- Business → Notion / other

**Step 3.3 — Integration setup:**
- Wizard discovers capabilities for chosen tool:
  - MCP server available?
  - CLI available?
  - API available?
- Sets up connection and verifies access
- GitHub: `gh auth status` + repo detection + label creation
- Other tools: guided setup based on discovered capabilities
- No API: fallback to BACKLOG.md + manual sync instructions

### Gate 4: Quality & Cross-Repo Scope

**Step 4.1 — Project scope:**
- "Do you work with multiple repositories simultaneously?"
  (e.g., backend API + frontend + admin panel)
- If yes: identify connected repos, enable cross-repo impact analysis

**Step 4.2 — Dynamic quality checklist:**
Wizard generates RECOMMENDED checks based on audit results:

| Detection | Recommended Check |
|-----------|------------------|
| NestJS + CASL | Permission guards on endpoints |
| Prisma + multi-tenant | RLS isolation verification |
| Financial domain (Decimal) | Decimal precision instead of Float |
| Event sourcing | Ripple detection: side effects |
| Frontend project | Visual verification: Playwright |
| Frontend + permissions | Permission boundary: admin vs client |
| Docker present | Docker verification: build + migrate + test |
| Cross-repo | Breaking changes analysis |

User confirms / adds / removes. Good practices stored in
`references/quality-patterns.md` inside pm-core as a library.

### Gate 5: Naming Conventions & Contract Audit

**Step 5.1 — Naming audit:**
Scan project for patterns:
- Repositories: `IOrderRepository`? `OrderRepository`? `OrderRepo`?
- Services: `OrderService`? `OrderDomainService`?
- DTOs: `CreateOrderDto`? `OrderCreateRequest`?
- Events: `OrderCreated`? `OrderCreatedEvent`?

Report:
```
✅ Repositories: I{Feature}Repository — consistent (12/12)
✅ Services: {Feature}Service — consistent (8/8)
⚠️ DTOs: mixed — Create{Feature}Dto (5), {Feature}CreateRequest (3)
❌ Events: no unified pattern — 3 different styles
```

**Step 5.2 — Resolve issues:**
- If consistent: show user, get approval
- If problems found: for each issue, recommend a convention with reasoning
  - Option A: Adopt recommended, new code follows it (gradual migration)
  - Option B: Refactor everything to unified style (big PR, risk)
  - Option C: User's own convention

**Step 5.3 — Fix conventions:**
Generate `contract-convention.md` with final rules for the conductor.

### Gate 6: Knowledge Export

**Step 6.1 — Collect insights:**
Everything learned during the wizard: stack, architecture, conventions,
conflict zones, cross-repo dependencies, quality checklist.

**Step 6.2 — Update project documents:**
- If CLAUDE.md exists: check for `revise-claude-md` skill, use it or update manually
- If AGENTS.md exists: add descriptions of generated agents
- Other docs: propose updates where relevant

**Step 6.3 — User confirmation:**
Show what will be changed, get approval before modifying.

---

## Conductor Pattern — Parallel Orchestration

The conductor is generated by the wizard **into the project** and customized
for the specific architecture.

### Conductor Flow

```
/dev "Add order management"
  │
  ╔═══════════════════════════════════════════╗
  ║  PHASE 1: Understand + Contracts          ║
  ║  (sequential, single context)             ║
  ╚═══════════════════════════════════════════╝
  │
  ├─ 1.1 Understand the task
  ├─ 1.2 Schema: Prisma migration + generate
  │    → tsc --noEmit (verify Prisma types)
  ├─ 1.3 Domain: Create skeleton contracts
  │    Using contract-convention.md:
  │    - I{Feature}Repository (interface, method signatures)
  │    - {Feature}Service (interface/abstract)
  │    - Create{Feature}Dto, Update{Feature}Dto (structure only)
  │    - {Feature}CreatedEvent (type)
  │    → tsc --noEmit (contracts compile)
  │    → Save to .claude/pm/{feature}/contracts.md
  ├─ 1.4 GATE: Show contracts to user for approval
  │
  ╔═══════════════════════════════════════════╗
  ║  PHASE 2: Parallel Streams                ║
  ║  (parallel, isolated layer-specific agents)║
  ╚═══════════════════════════════════════════╝
  │
  │  ┌─ infra-worker ─────────────────────────┐
  │  │  Scope: src/infrastructure/{feature}/   │
  │  │  Task: Implement I{Feature}Repository   │
  │  │  Input: contracts.md + infra-stream.md  │
  │  └────────────────────────────────────────-┘
  │
  │  ┌─ app-worker ───────────────────────────┐
  │  │  Scope: src/application/{feature}/      │
  │  │  Task: Handlers, commands, queries      │
  │  │  Input: contracts.md + app-stream.md    │
  │  └────────────────────────────────────────-┘
  │
  │  ┌─ interface-worker ─────────────────────┐
  │  │  Scope: src/interface/{feature}/        │
  │  │  Task: Controllers, DTOs, Swagger       │
  │  │  Input: contracts.md + interface-stream.md│
  │  └────────────────────────────────────────-┘
  │
  ╔═══════════════════════════════════════════╗
  ║  PHASE 3: Merge + Verify                  ║
  ║  (sequential)                             ║
  ╚═══════════════════════════════════════════╝
  │
  ├─ 3.1 Collect stream reports
  │    Conductor sees ONLY: what done, files modified, blockers, insights
  ├─ 3.2 Resolve conflicts (if any) via git
  ├─ 3.3 tsc --noEmit (full type check)
  ├─ 3.4 Docker verification (if enabled)
  ├─ 3.5 Quality gates (from Gate 4)
  ├─ 3.6 Process insights (see below)
  └─ 3.7 Ripple detection (if enabled)
```

### Contract-First Approach

Phase 1.3 creates skeleton contracts: interfaces with method signatures but no
implementation. Each stream worker receives `contracts.md` and implements its part.

Since contracts are fixed:
- Infra agent knows: `IOrderRepository.create(data: CreateOrderDto): Promise<Order>`
- App agent knows it can call: `this.orderRepository.create()`
- Interface agent knows the structure of `CreateOrderDto`

No runtime coordination needed. Conflicts only possible in shared files (types/index.ts),
resolved via git.

### Context Isolation

The conductor (main thread) never sees code from streams. Only:
- What was accomplished (bullet list)
- Files modified (list)
- Blockers (if any)
- Insights discovered (see below)

This prevents context pollution and compaction on large features.

### When NOT to Parallelize

Conductor automatically falls back to sequential mode if:
- Only 1 layer affected (small task)
- Architecture audit showed high conflict zones
- User chose sequential in Gate 2

---

## Layer-Specific Agents

Wizard generates **one agent per architectural layer** with project-specific rules
embedded in the system prompt. This is critical — AI performs better with specific,
focused instructions than with parameterized generic prompts.

### Agent Generation Rules

The wizard:
1. Identifies layers from architecture audit (Gate 1)
2. Reads existing code patterns per layer
3. Generates an agent per layer with:
   - Scope (directory patterns)
   - Project rules (conventions, base classes, DI patterns)
   - Contract input format
   - Return format (including insights)

### Stream Worker Report Format

```markdown
## Stream Report: {Layer}

### Completed
- {what was done, bullet list}

### Files Modified
- {path} (new/modified)

### Blockers
- {if any, otherwise "None"}

### Insights
- {NEW PATTERN}: Discovered {X} used across the project but not in conventions
- {CONVENTION DRIFT}: {Y} doesn't match contract-convention.md
- {USEFUL DISCOVERY}: Shared utility {Z} already exists, could be documented
```

### Insight Processing (Conductor Phase 3.6)

```
Collect insights from all streams → Classify:
├─ CONVENTION DRIFT — skills say one thing, code says another
├─ NEW PATTERN — pattern not described in skills
└─ USEFUL DISCOVERY — utility/helper worth documenting

Show to user:
  "Streams discovered 3 insights:
   1. BaseAuditRepository instead of AbstractRepository — update convention?
   2. @Transactional() on mutations — add to rules?
   3. PaginationHelper — add to shared conventions?"

Per user decision: update references or run /pm:upgrade
```

---

## Backlog Sync & PM Commands

Commands are generated in the project based on Gate 3 choices.

### Conceptual Stages (hardcoded in pm-core as goals)

| Stage | Goal | Purpose |
|-------|------|---------|
| **Sync** | Synchronize progress with external system | Audit trail, team visibility |
| **Status** | Show current work state | Orientation for agent and user |
| **Next** | Suggest next task by priority | Automate prioritization |
| **Standup** | Generate report | Team communication |
| **Import** | Load tasks from external system | Initial synchronization |
| **Close** | Complete task/epic | Lifecycle management |

### Implementation (generated dynamically after discovery)

Gate 3 wizard determines what's available:
1. User picks tool (GitHub / Notion / Linear / custom)
2. Wizard discovers: MCP server? CLI? API?
3. Determines capabilities: read tasks? write comments? create tasks?
4. Generates ONLY commands that actually work with discovered capabilities
5. GitHub is the only "built-in" (gh CLI is standard)

### Ephemeral vs Persistent State

```
.claude/pm/                    # ← .gitignore! Ephemeral workspace
├── config.yaml                # Wizard settings
├── current-epic/
│   ├── state.yaml             # Current epic, tasks, progress
│   ├── contracts.md           # Contracts for conductor
│   └── streams/               # Stream reports
└── sync-log.yaml              # Last sync timestamps

Final results → persistent storage:
- GitHub Issues (comments, closed)
- Notion (updated cards)
- BACKLOG.md (committed to git)
```

Ephemeral state can be deleted anytime without data loss.
`/pm:sync` restores from persistent storage.

---

## Self-Improvement Protocol

### Hook-Based Detection (generated in project)

Opt-in during Gate 6 of wizard. Only enabled if user explicitly agrees.

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Check git diff --name-only for this session. If it includes CLAUDE.md, AGENTS.md, or files under .claude/, say: 'Project skills may be outdated. Run /pm:upgrade to sync.' Otherwise say nothing."
          }
        ]
      }
    ]
  }
}
```

**Filtering**: Hook checks file names only (not content), avoiding expensive full-diff analysis.
**State**: `.claude/pm/last-upgrade-check.txt` stores last commit hash — don't re-suggest
for same changes.

### Upward Knowledge Flow

```
Stream workers → discover insights → report to conductor
Conductor → classifies insights → shows to user
User → decides: update conventions / run /pm:upgrade / ignore
/pm:upgrade → diffs project vs skills → proposes updates → applies
```

### /pm:upgrade Flow

1. **Diff**: compare current project state with what skills describe
2. **Detect**: what changed (new patterns, new files, convention drift)
3. **Propose**: "Here's what I suggest updating:" (list with reasons)
4. **Apply**: user confirms → update references + agents
5. **Export**: update CLAUDE.md if needed (via `revise-claude-md` or manually)

---

## Relationship with Existing Plugins

| Plugin | Role | Changes |
|--------|------|---------|
| **pm-core** (NEW) | Meta-tool: analyzes project, generates skills/agents/commands | New plugin |
| **skill-forge** | Creates/improves individual skills | No changes |
| **dev-worktree** | Manages git worktrees + Docker environments | No changes; pm-core invokes `/worktree` when needed |

pm-core generates artifacts that LIVE in the project. After generation,
pm-core is only needed for `/pm:upgrade`.

---

## Component Summary

### pm-core Plugin Components (14 total)

| Component | Type | Purpose |
|-----------|------|---------|
| `project-setup/SKILL.md` | Skill | Wizard controller — 6 gates |
| `references/architecture-audit.md` | Reference | How to analyze project fitness |
| `references/conductor-pattern.md` | Reference | Parallel conductor flow template |
| `references/contract-convention.md` | Reference | Naming convention template |
| `references/backlog-strategies.md` | Reference | Discovery + capabilities per tool |
| `references/backend-nestjs-template.md` | Reference | NestJS + Clean Arch template |
| `references/backend-generic-template.md` | Reference | Generic backend template |
| `references/frontend-template.md` | Reference | Frontend (FSD/SPA) template |
| `references/pm-commands-template.md` | Reference | Command generation templates |
| `references/quality-patterns.md` | Reference | Proven quality check library |
| `commands/setup.md` | Command | `/pm:setup` — launch wizard |
| `commands/upgrade.md` | Command | `/pm:upgrade` — improve existing |
| `agents/architecture-auditor.md` | Agent | Deep project analysis |
| `agents/skill-generator.md` | Agent | Generate project-specific files |

### Generated Components (examples, depend on stack)

| Component | When Generated | Contains |
|-----------|---------------|----------|
| `infra-worker.md` | Backend Clean Arch | Prisma repos, DI, tenant rules |
| `app-worker.md` | Backend CQRS | Handlers, CommandBus, events |
| `interface-worker.md` | Backend API | Controllers, DTOs, guards, Swagger |
| `migration-worker.md` | Strapi/hybrid | SQL migrations, content types |
| `feature-worker.md` | Frontend FSD | Feature scaffolding, store, queries |
| `cqrs-worker.md` | CQRS projects | Commands, handlers, workflows |

---

## Docker Strategy

One Docker Compose stack per feature (in worktree). Parallel streams work with
files only — no Docker needed during stream execution. Docker launches at the end
for full verification: build + migrate + tsc + test.

---

## Review Findings & Mitigations

Triple-source review (2026-02-15): CCPM gap analysis, plugin-dev conventions, feasibility.

### Critical — Must Address

| # | Finding | Source | Mitigation |
|---|---------|--------|------------|
| C1 | Hook format wrong (needs wrapper `{"hooks":{"Stop":[...]}}`) | plugin-dev | **Fixed above** — corrected hooks.json format |
| C2 | Agent frontmatter needs `<example>` blocks for triggering | plugin-dev | Add to agent templates in `references/` — each generated agent gets 2-4 example blocks |
| C3 | Shell script delegation for complex commands | CCPM | Generate both `commands/*.md` (delegates) + `scripts/*.sh` (implementation) for heavy operations |
| C4 | Preflight validation pattern in every command | CCPM | Add standardized preflight checklist to `references/pm-commands-template.md` |
| C5 | No contract change recovery mid-stream | feasibility | **Contract negotiation protocol**: stream reports `### Contract Issues`, conductor halts + asks user. Fallback to sequential if 2+ issues arise |
| C6 | Agent generation unrealistic without templates | feasibility | Use **template-based generation**: `references/agent-template-{layer}.md` with placeholder sections. Skill-generator fills placeholders, doesn't free-form write |
| C7 | Frontmatter stripping for GitHub sync | CCPM | Strip YAML frontmatter before posting to GitHub, preserve locally. Add to sync command template |

### Important — Address During Implementation

| # | Finding | Source | Mitigation |
|---|---------|--------|------------|
| I1 | SKILL.md voice must be imperative, not second person | plugin-dev | Enforce in all templates. "Audit stack..." not "You should audit..." |
| I2 | Skill description needs "Use when..." + trigger phrases | plugin-dev/skill-forge | Add to SKILL.md: `description: Use when setting up pm-core... Triggers on 'setup project', 'pm setup', 'generate dev skills'` |
| I3 | Command frontmatter incomplete (needs `allowed-tools`, `argument-hint`) | plugin-dev | Add to all command templates |
| I4 | Standard patterns documentation (preflight, error format, output) | CCPM | Create `references/standard-patterns.md` |
| I5 | Datetime rule — centralize timestamp format | CCPM | Generated projects include `rules/datetime.md` or equivalent in CLAUDE.md |
| I6 | gh-sub-issue fallback when extension missing | CCPM | Check for extension, fallback to labels + task list in epic body |
| I7 | Progress file coordination between parallel agents | CCPM | Each stream writes ONLY to `streams/{layer}-report.md`. Conductor owns `state.yaml` exclusively |
| I8 | Agent coordination rules (file-level parallelism, atomic commits) | CCPM | Generate `rules/agent-coordination.md` in target project |
| I9 | Task reference updates after GitHub sync renaming | CCPM | Build mapping `001→#1234`, update `depends_on`, `conflicts_with` arrays |

### Warnings — Consider / Defer

| # | Finding | Source | Mitigation |
|---|---------|--------|------------|
| W1 | 10 reference files — progressive disclosure concern | plugin-dev | Acceptable for meta-tool complexity. SKILL.md stays lean (orchestration only) |
| W2 | Generated components should self-document origin | feasibility | Add `# Generated by pm-core v{X} on {date}` header to all generated files |
| W3 | Wizard context window risk on large projects | feasibility | Cache analysis results in `pm-setup-state.yaml` per gate. Break Gate 5 naming audit into focused scans |
| W4 | State concurrency — parallel agents sharing `.claude/pm/` | feasibility | Strict isolation: streams write only own report file, conductor owns all shared state |
| W5 | Cross-repo analysis underspecified | feasibility | **Defer to Phase Omega**. MVP: single-repo only |
| W6 | Upgrade: distinguishing generated vs user-customized files | feasibility | Track `generated-manifest.yaml` with file hashes. Diff before overwriting, ask user on conflicts |
| W7 | Frontend FSD needs different conductor pattern | feasibility | **Defer to Phase Omega**. Create `references/conductor-pattern-frontend.md` later |

## Phased Implementation Plan

### Phase Alpha: Wizard + Backlog (MVP)

**Scope**: Gates 1-3 of wizard + BACKLOG.md + GitHub Issues integration

- Gate 1: Project Understanding (architecture audit)
- Gate 2: Pipeline Mode (parallel/sequential decision)
- Gate 3: Task Tracking (GitHub + BACKLOG.md only, no other integrations)
- Generate: BACKLOG structure, GitHub labels, basic `/pm:sync` command
- Agent: `architecture-auditor.md` only

**Validates**: wizard flow, state persistence, GitHub integration

### Phase Beta: Sequential Dev-Skill Generation

**Scope**: Gates 4-6 + skill generation in SEQUENTIAL mode (no conductor)

- Gate 4: Quality checklist generation
- Gate 5: Naming conventions audit
- Gate 6: Knowledge export (CLAUDE.md, AGENTS.md)
- Generate: dev SKILL.md + references, quality gates, layer-specific agents
- Agent templates: `agent-template-{layer}.md` with placeholder approach
- Generated pipeline: sequential (like existing dev skills)

**Validates**: template-based agent generation, quality gates, skill structure

### Phase Gamma: Parallel Conductor (Backend)

**Scope**: Conductor pattern for backend Clean Architecture

- Contract-first Phase 1 (understand + schema + contracts)
- Parallel Phase 2 (layer-specific agents)
- Verification Phase 3 (merge + tsc + docker + quality)
- Contract negotiation protocol (stream reports issues, conductor halts)
- Shell script delegation for verification commands

**Validates**: parallel execution, contract approach, context isolation

### Phase Delta: Self-Improvement + Upgrade

**Scope**: Self-improvement hook + `/pm:upgrade` command

- Opt-in Stop hook with file-name-only filtering
- `/pm:upgrade` with generated-manifest diffing
- Insight processing from stream reports
- Upward knowledge flow protocol

**Validates**: hook performance, false positive rate, upgrade safety

### Phase Omega: Frontend + Cross-Repo + Advanced

**Scope**: FSD conductor + cross-repo analysis + additional integrations

- Frontend-specific conductor pattern
- Visual verification integration (Playwright)
- Cross-repo impact analysis
- Notion/Linear/Jira integration discovery
- Import command for existing projects

**Validates**: frontend parallel streams, cross-repo sync

## Inspiration & References

- **CCPM** (automazeio/ccpm): conductor pattern, context isolation, frontmatter
  state machine, GitHub sync, parallel agent orchestration, shell script delegation,
  preflight validation, agent coordination rules
- **gm-platform-api dev skill**: Clean Architecture layers, security audit
- **ff-api dev skill**: Ripple Detection (Phase 3.5), Decimal precision, @MurLock
- **ucare-api dev skill**: Design exploration, flexible routing, agent-driven reviews
- **gm-platform dev skill**: FSD layers, intent-driven routing, visual verification
