---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-03-20'
inputDocuments:
  - der-klack-konzept.md
  - _bmad-output/planning-artifacts/epics.md
workflowType: 'architecture'
project_name: 'cc-crew (Der Klack)'
user_name: 'Postmeister'
date: '2026-03-20'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**

15 functional requirements spanning 7 epics. The system is an autonomous multi-ticket development pipeline orchestrated via tmux and a filesystem message bus. Core flows: ticket ingestion (FR8) → implementation (FR9) → quality gate (FR10) → review (FR11) → release (FR12), with cross-cutting orchestration (FR1–FR7) and developer interaction (FR13) throughout.

Key architectural implication: every FR that involves "step completion" must write to `status.json` — this is the contract between the Turmwächter and all steps.

**Non-Functional Requirements:**

- NFR1/NFR2: All Claude processes launch with `--dangerously-skip-permissions --chrome` — this is a non-negotiable process startup contract, not a configuration option.
- NFR3: Context isolation by process boundary — no `/clear`, no shared memory. Each step is architecturally a black box receiving only its designated input files.
- NFR4/NFR5: Quality gate with exact CI parity — `.gitlab-ci.yml` is the authoritative source for all commands, parameters, and thresholds. Max 3 iterations before escalation.
- NFR6: `_bmad/` directory is read-only — no modifications permitted.
- NFR7: Model tiering via environment variables — Haiku for sub-agents, Sonnet for main agents, Opus for review.

**Scale & Complexity:**

- Primary domain: DevOps automation / shell orchestration
- Complexity level: Medium (14 stories, clear system boundaries, no UI)
- No database, no network stack — process orchestration and filesystem I/O are the primary technical challenges
- Estimated core components: 6 (cc-crew entrypoint, hauptturm pane scripts, ticket-run.sh, 5 ticket-* commands, .klack/ filesystem structure)

### Technical Constraints & Dependencies

- **tmux**: Required for session/window management — no abstraction layer
- **Git worktrees**: Mandatory isolation for all implementation work; `.git` as file (not directory) is the verification contract
- **Atlassian MCP**: Required for Jira ticket ingestion (ticket-story) and commenting (ticket-release)
- **glab CLI**: Required for GitLab MR creation (ticket-release)
- **Claude Code CLI**: All steps run as `claude --dangerously-skip-permissions --chrome -p "..."` invocations
- **PHP toolchain**: PHP-CS-Fixer, PHPStan, PEST with pcov — versions and parameters sourced exclusively from `.gitlab-ci.yml`
- **BMAD-Method**: `_bmad/` definitions are referenced but never modified

### Cross-Cutting Concerns Identified

1. **Rücksignal-Mechanismus** — Used in ticket-story (ambiguity resolution), ticket-qa (QA loop failure), ticket-review (critical findings), ticket-release (MR/Jira failures). Must be implemented as a reusable pattern, not per-step.
2. **Status tracking** (`status.json`) — Every step reads and writes status. Schema and update contract must be defined once and respected by all steps.
3. **Error handling** (`error.log`) — All steps write errors consistently. Format and escalation path must be uniform.
4. **Model configuration** — Environment variables set once by cc-crew, inherited by all child processes. No per-step configuration.
5. **Worktree isolation** — Steps ticket-dev through ticket-release operate inside a worktree. Verification (`.git` as file) must be enforced at step start, not assumed.

## Starter Template Evaluation

### Primary Technology Domain

Shell scripting / CLI automation — no traditional starter template applies.

### Technology Stack (Pre-decided by Concept Document)

All core technology decisions are defined in `der-klack-konzept.md` and are not open for re-evaluation:

- **Orchestration runtime**: bash
- **Terminal multiplexer**: tmux
- **AI process invocation**: `claude` CLI with `--dangerously-skip-permissions --chrome -p`
- **Command definitions**: Markdown files in `.claude/commands/ticket-{step}.md`
- **Inter-process communication**: Filesystem only (`.klack/signale/{TICKET}/` directory structure)
- **VCS isolation**: Git worktrees (verified via `.git` as file)
- **GitLab integration**: `glab` CLI
- **Jira integration**: Atlassian MCP
- **Quality gate toolchain**: PHP-CS-Fixer, PHPStan, PEST with pcov — parameters from `.gitlab-ci.yml`
- **Model routing**: Environment variables (`ANTHROPIC_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL`)

### Project Initialization

No starter command. Initial structure created by `cc-crew` script at runtime:
- `.klack/signale/{TICKET}/` directories created per ticket on startup
- `.claude/commands/ticket-{step}.md` files are static artifacts delivered with the project

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- `.klack/signale/{TICKET}/` as the canonical message bus directory structure
- `status.json` schema contract between all steps and Turmwächter
- Ticket context injection via prompt append (not environment variables)
- Hauptturm as dynamic tmux pane landscape

**Important Decisions (Shape Architecture):**
- Standard `git worktree add` — git manages worktree directories
- Error handling model: hard crash vs. Rücksignal distinction

**Deferred Decisions (Post-MVP):**
- Jira status updates during processing
- Dependency analysis between parallel tickets
- Additional `.klack/` subdirectories beyond `signale/`

---

### Message Bus: `.klack/signale/` Directory Structure

The canonical filesystem message bus. Lives in the target project root (gitignored there).
Extensible: `.klack/signale/`, `.klack/config/`, `.klack/logs/` possible in future.

```
.klack/
└── signale/
    └── IN-2262/
        ├── story.md        ← written by ticket-story
        ├── review.md       ← written by ticket-review
        ├── status.json     ← updated by all steps
        ├── question.txt    ← written when Rücksignal needed
        ├── answer.txt      ← written by Hauptturm
        ├── waiting.flag    ← set while awaiting answer
        └── error.log       ← written on abort
```

All filenames are English. The directory is created by the Turmwächter before the first step starts.

---

### Data Architecture: `status.json` Schema

Contract between all steps and the Turmwächter. Every step writes on status change.

```json
{
  "step": "init|story|dev|qa|review|release",
  "status": "pending|running|waiting|done|error",
  "log": "<last log entry as string>",
  "updated_at": "<ISO-8601 timestamp>",
  "mr_url": null
}
```

- No `progress` field — step-level granularity is sufficient
- `mr_url` populated only by ticket-release on success
- `updated_at` written on every status change

---

### Process Orchestration: Ticket Context Injection

Ticket context is appended to the prompt by the Turmwächter — not passed via environment variables. This keeps context visible in the prompt (debuggable when something crashes).

```bash
claude --dangerously-skip-permissions --chrome -p "$(cat .claude/commands/ticket-story.md)

---
KLACK_TICKET: IN-2262
KLACK_TYPE: feat
KLACK_DIR: $(pwd)/.klack/signale/IN-2262"
```

Static `ticket-*.md` command files remain generic. The Turmwächter injects context dynamically at step start. No temporary file generation, no environment variable management.

---

### Infrastructure: Git Worktrees

Standard `git worktree add` — git manages worktree directory location per project convention. No custom path logic in cc-crew.

Verification in every step that requires a worktree: `.git` must be a file (not a directory). Failure → write `error.log`, exit immediately with code 1.

---

### Hauptturm Architecture: tmux-Native Pane Architecture

tmux Window 0 is split into multiple tmux panes — each pane runs its own lightweight bash script from `.klack/scripts/hauptturm/`. tmux handles layout, borders, and resizing natively.

**Core principles:**

- Each UI zone is a separate tmux pane running its own script
- Mouse mode is ON (`tmux set-option -g mouse on`) — developer can drag pane borders to resize
- tmux 3.2+ pane border labels (`pane-border-format`) show ticket names in the border line
- Developer can use standard tmux keybindings to resize/swap/zoom panes

**Pane scripts (all in `.klack/scripts/hauptturm/`):**

| Script | Purpose |
|--------|---------|
| `header.sh` | Header pane renderer (session name, ticket count, active theme) |
| `log.sh` | Activity log pane (tail -f style, reads `.klack/activity.log`) |
| `status.sh` | Status card renderer (aggregated ticket overview) |
| `ticket-status.sh` | Single ticket card (used in dashboard mode, one pane per ticket) |
| `input.sh` | Interactive prompt + command handler (writes to `.klack/cmd.fifo`) |
| `layout.sh` | Layout switcher (kills/recreates panes per target layout) |
| `theme.sh` | Color/symbol constants, sourced by all pane scripts |

**Layouts (5 selectable, switched via `layout.sh`):**

| Layout | Description |
|--------|-------------|
| `hybrid` | Default layout — balanced mix of status and log |
| `fullchat` | Maximized log/interaction area |
| `twocol` | Two-column split |
| `threezone` | Three distinct zones |
| `dashboard` | One pane per ticket (ticket-status.sh per ticket) |

Layout switching: `layout.sh` kills existing panes and recreates them according to the target layout definition.

**Color Schemes (5 selectable):**

| Theme | Description |
|-------|-------------|
| `unicorn` | Default — rainbow colors |
| `cylon` | Red-dominant theme |
| `kitt` | Dark with red accents |
| `shufflepuck` | Neon/retro palette |
| `monochrome` | No colors, plain terminal |

Theme switching: sending SIGUSR1 to all pane scripts triggers re-source of `theme.sh`. The active theme name is stored in `.klack/active_theme`.

---

### Hauptturm Input Commands

The input bar (`input.sh`) accepts commands with the grammar: `<verb> [<ticket-id>] [<argument>]`

| Command | Description |
|---------|-------------|
| `answer <ticket-id> "<text>"` | Write `answer.txt`, delete `waiting.flag` |
| `add <type> <ticket-id>` | Create new tmux window + start Turmwächter for ticket |
| `error <ticket-id>` | Display error.log contents for ticket |
| `retry <ticket-id>` | Retry failed step for ticket |
| `abort <ticket-id>` | Abort ticket processing |
| `layout <name>` | Switch to named layout (hybrid, fullchat, twocol, threezone, dashboard) |
| `theme <name>` | Switch color scheme (unicorn, cylon, kitt, shufflepuck, monochrome) |
| `status` | Refresh status display |
| `help` | Show available commands |

Input is handled by `input.sh`, which writes commands to `.klack/cmd.fifo` (named pipe). The Turmwächter and other scripts read from this pipe to act on commands.

---

### Error Handling Model

**Hard Error (Claude process exits with code != 0):**
→ Write `error.log`, set `status.json` to `"error"`, Turmwächter stops. No retry, no Rücksignal.

**QA Loop Exhaustion (after 3 iterations without passing):**
→ Write failure report to `error.log`, then Rücksignal: developer decides whether to intervene manually or abort.

**Review Blocking (critical findings in `review.md`):**
→ Rücksignal: developer decides whether to proceed anyway or abort.

## Implementation Patterns & Consistency Rules

### Critical Conflict Points

6 areas where AI agents could make incompatible implementation choices without explicit rules.

---

### Pattern 1: Context Reading in Claude Commands

Every `ticket-*.md` command receives its context via a trailing block in the prompt:

```
---
KLACK_TICKET: IN-2262
KLACK_TYPE: feat
KLACK_DIR: /absolute/path/to/.klack/signale/IN-2262
```

**Rule:** Commands use `KLACK_DIR` as the sole filesystem anchor — always absolute, never relative. `KLACK_TICKET` and `KLACK_TYPE` are available for readability and branch naming. Never derive paths by searching or guessing.

---

### Pattern 2: `status.json` Write Protocol

Every step MUST follow this exact sequence:

```
1. START  → status = "running",  step = "<stepname>", log = "Starting...", updated_at = <now>
2. WAIT   → status = "waiting",  log = "<question summary>"  (only when Rücksignal needed)
3. DONE   → status = "done",     log = "<brief summary>",    updated_at = <now>
4. ERROR  → status = "error",    log = "<error message>",    updated_at = <now>
```

No step may exit without writing a terminal status (`done` or `error`).

---

### Pattern 3: Rücksignal Write/Read Order

**Writing (step needs an answer):**
```
1. Write question.txt
2. Update status.json → "waiting"
3. Set waiting.flag  ← last, this is the trigger
```

**Reading (Hauptturm delivers answer):**
```
1. Delete waiting.flag  ← first, prevents re-detection
2. Write answer.txt
```

**Consuming (Turmwächter resumes):**
```
1. Read answer.txt
2. Update status.json → "running"
3. Continue execution
```

Rationale: `waiting.flag` is the canonical signal. Its presence means "blocked". Its absence means "clear to proceed". The order prevents race conditions.

---

### Pattern 4: Bash Script Style

All shell scripts (`cc-crew`, `ticket-run.sh`, `hauptturm/*.sh`) begin with:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

Rules:
- Always double-quote variables: `"$KLACK_TICKET"` not `$KLACK_TICKET`
- Errors go to stderr: `echo "ERROR: ..." >&2`
- Exit codes: `exit 1` on error, `exit 0` on success
- No `exit` without a preceding `error.log` write when inside Turmwächter context

---

### Pattern 5: Branch Slug Generation

Branch format: `worktree-{type}/{TICKET-ID}-{slug}`

Slug rules (applied in order):
1. Take story title from `story.md` first line (strip leading `#`)
2. Lowercase entire string
3. Replace spaces with hyphens
4. Remove all characters except `a-z`, `0-9`, `-`
5. Collapse multiple consecutive hyphens into one
6. Strip leading and trailing hyphens
7. Truncate to 40 characters maximum (truncate at word boundary if possible)

Example: `"Add user authentication flow"` → `add-user-authentication-flow`

---

### Pattern 6: Worktree Verification

Every step that operates inside a worktree (ticket-dev, ticket-qa, ticket-review, ticket-release) MUST verify at start:

```bash
if [ -d ".git" ]; then
  echo "ERROR: Not inside a git worktree (.git is a directory, not a file)" >&2
  echo "Worktree verification failed" > "$KLACK_DIR/error.log"
  exit 1
fi
```

`.git` as a file (not directory) is the canonical worktree indicator. This check runs before any implementation work begins — no exceptions.

---

### Enforcement Guidelines

**All AI agents implementing any component MUST:**
- Follow the `status.json` write protocol exactly — no shortcuts, no skipped states
- Use `KLACK_DIR` as the filesystem anchor — never construct paths manually
- Apply the Rücksignal write order precisely — `waiting.flag` is always last when setting, always first when clearing
- Begin all bash scripts with `set -euo pipefail`
- Verify worktree before doing any work in steps 4–7 (dev, qa, review, release)
- Generate slugs using the exact 7-step rule — no improvisation

**Anti-Patterns to Avoid:**
- Reading `KLACK_TICKET` from `status.json` (use the injected prompt value)
- Writing `waiting.flag` before `question.txt` (breaks Hauptturm detection)
- Using relative paths in any script or command
- Exiting with error without updating `status.json` and writing `error.log`
- Checking `[ -f ".git" ]` instead of `[ -d ".git" ]` for worktree detection (logic is inverted — worktree has `.git` as file, main repo has it as directory)

## Project Structure & Boundaries

### Tool Name

The tool is named **klack** (not cc-crew). All scripts, commands, and references use this name.

### klack Repository Structure

```
klack/
├── install.sh                      ← installer: copies files into target project
├── commands/                       ← source command files (installed into target project)
│   ├── ticket-story.md             ← Epic 3: Jira ingestion + story enrichment
│   ├── ticket-dev.md               ← Epic 4: implementation in git worktree
│   ├── ticket-qa.md                ← Epic 5: PEST tests + quality gate loop
│   ├── ticket-review.md            ← Epic 6: unbiased diff review (Opus)
│   └── ticket-release.md          ← Epic 7: MR creation + Jira comment
└── scripts/                        ← source scripts (installed into target project)
    ├── klack.sh                    ← main entrypoint
    ├── ticket-run.sh               ← Turmwächter (Epic 1, Stories 1.4/1.5)
    └── hauptturm/                  ← dashboard pane scripts (Epic 2)
        ├── theme.sh                ← color/symbol constants, sourced by all
        ├── header.sh               ← header pane renderer
        ├── log.sh                  ← activity log pane (tail -f style)
        ├── status.sh               ← status card renderer
        ├── ticket-status.sh        ← single ticket card (dashboard mode)
        ├── input.sh                ← interactive prompt + command handler
        └── layout.sh               ← layout switcher
```

### Target Project Structure (after `install.sh`)

```
<target-project>/
├── klack.sh                        ← entrypoint, executable, user runs: ./klack.sh feat IN-2262
├── .claude/
│   └── commands/
│       ├── ticket-story.md         ← installed by klack
│       ├── ticket-dev.md
│       ├── ticket-qa.md
│       ├── ticket-review.md
│       └── ticket-release.md
└── .klack/
    ├── scripts/                    ← committed, internal (not run by hand)
    │   ├── ticket-run.sh
    │   └── hauptturm/              ← dashboard pane scripts
    │       ├── theme.sh
    │       ├── header.sh
    │       ├── log.sh
    │       ├── status.sh
    │       ├── ticket-status.sh
    │       ├── input.sh
    │       └── layout.sh
    ├── activity.log                ← gitignored, append-only log read by log.sh
    ├── active_theme                ← gitignored, current theme name
    ├── cmd.fifo                    ← gitignored, named pipe for input commands
    └── signale/                    ← gitignored, runtime state
        └── IN-2262/
            ├── story.md
            ├── review.md
            ├── status.json
            ├── question.txt
            ├── answer.txt
            ├── waiting.flag
            └── error.log
```

`.gitignore` entries: `.klack/signale/`, `.klack/session.json`, `.klack/activity.log`, `.klack/active_theme`, `.klack/cmd.fifo` (not `.klack/` — scripts directory is committed)

### What `install.sh` Does

1. Copy `commands/ticket-*.md` → `<target>/.claude/commands/`
2. Copy `scripts/klack.sh` → `<target>/klack.sh` (chmod +x)
3. Copy `scripts/ticket-run.sh` → `<target>/.klack/scripts/`
4. Copy `scripts/hauptturm/` → `<target>/.klack/scripts/hauptturm/` (entire directory)
5. Add `.klack/signale/`, `.klack/session.json`, `.klack/activity.log`, `.klack/active_theme`, `.klack/cmd.fifo` to `<target>/.gitignore`
6. Verify dependencies: `tmux` (3.2+), `glab`, `claude` available in PATH

### Epic to Structure Mapping

| Epic | Component | Location |
|------|-----------|----------|
| Epic 1: Klack-Fundament | `klack.sh`, `ticket-run.sh` | `klack.sh`, `.klack/scripts/ticket-run.sh` |
| Epic 2: Hauptturm | `hauptturm/*.sh` | `.klack/scripts/hauptturm/*.sh` |
| Epic 3: ticket-story | `ticket-story.md` | `.claude/commands/ticket-story.md` |
| Epic 4: ticket-dev | `ticket-dev.md` | `.claude/commands/ticket-dev.md` |
| Epic 5: ticket-qa | `ticket-qa.md` | `.claude/commands/ticket-qa.md` |
| Epic 6: ticket-review | `ticket-review.md` | `.claude/commands/ticket-review.md` |
| Epic 7: ticket-release | `ticket-release.md` | `.claude/commands/ticket-release.md` |

### Integration Points

**klack.sh → ticket-run.sh:**
Starts one Turmwächter per ticket via tmux window. Passes ticket ID and type via environment and/or prompt injection.

**ticket-run.sh → ticket-*.md:**
Each step launched as: `claude --dangerously-skip-permissions --chrome -p "$(cat .claude/commands/ticket-STEP.md)\n\n---\nKLACK_TICKET: ...\nKLACK_TYPE: ...\nKLACK_DIR: ..."`

**ticket-*.md → .klack/signale/:**
All reads and writes go through `KLACK_DIR` (absolute path). No relative paths.

**hauptturm/*.sh ↔ .klack/signale/:**
Pane scripts read `status.json` from all ticket directories. `input.sh` writes commands to `.klack/cmd.fifo`. The Turmwächter writes `answer.txt` and deletes `waiting.flag` in response to `answer` commands.

### Deferred Architecture: BMAD-Method Planning Integration

**Future Epic (not in current scope):**
A `ticket-plan.md` command that drives a BMAD-Method workflow session (e.g., `/bmad-create-epics-and-stories`) autonomously, relaying interactive A/P/C rounds to the developer via the Rücksignal-Mechanismus. Technically feasible — the Rücksignal pattern is generic enough. Deferred until the core pipeline (Epics 1–7) is stable and validated in production.

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:**
All decisions work together without conflict. The Rücksignal-Mechanismus is generic and reused across story, qa, review, and release steps identically. The `status.json` contract is the single source of truth read by both the Turmwächter and the Hauptturm. Prompt injection cleanly delivers context to stateless Claude processes. The tmux-native pane architecture supports both the status display and the interactive input model, with each pane running its own script.

**Pattern Consistency:**
All 6 implementation patterns align with the technology stack (bash, tmux, Claude CLI). Naming is consistent (English filenames, German component names for Scheibenwelt flavor). The worktree verification pattern is unambiguous and enforceable.

**Structure Alignment:**
The project structure maps cleanly to the 7 epics. Every component has a defined home. Integration points between components are explicit and filesystem-mediated (no hidden coupling).

---

### Requirements Coverage ✅

| Requirement | Covered By | Status |
|-------------|-----------|--------|
| FR1 (klack entrypoint) | `klack.sh` | ✅ |
| FR2 (tmux session + windows) | `klack.sh` | ✅ |
| FR3 (continuous status display) | `hauptturm/*.sh` | ✅ |
| FR4 (question display) | `hauptturm/*.sh` + `waiting.flag` | ✅ |
| FR5 (answer input) | Hauptturm input pane | ✅ |
| FR6 (add new tickets) | `add` command in Hauptturm | ✅ |
| FR7 (fresh Claude process per step) | `ticket-run.sh` | ✅ |
| FR8 (ticket-story) | `ticket-story.md` | ✅ |
| FR9 (ticket-dev) | `ticket-dev.md` | ✅ |
| FR10 (ticket-qa + quality gate) | `ticket-qa.md` | ✅ |
| FR11 (ticket-review) | `ticket-review.md` | ✅ |
| FR12 (ticket-release) | `ticket-release.md` | ✅ |
| FR13 (Rücksignal-Mechanismus) | Pattern 3 + all steps | ✅ |
| FR14 (branch naming) | Pattern 5 (slug generation) | ✅ |
| FR15 (model configuration) | `klack.sh` env vars | ✅ |
| NFR1 (--dangerously-skip-permissions) | `ticket-run.sh` | ✅ |
| NFR2 (--chrome) | `ticket-run.sh` | ✅ |
| NFR3 (context isolation) | one Claude process per step | ✅ |
| NFR4 (quality gate CI parity) | `ticket-qa.md` reads `.gitlab-ci.yml` | ✅ |
| NFR5 (max 3 QA iterations) | error handling model | ✅ |
| NFR6 (_bmad/ untouched) | architectural constraint | ✅ |
| NFR7 (model tiering) | env vars set by `klack.sh` | ✅ |

---

### Gap Analysis: Resilience Requirements (Added During Validation)

Two requirements surfaced during validation that were missing from the original concept:

**Gap 1 — Worktree Path Persistence (Critical)**

Resolution: `status.json` extended with `worktree_path` and `branch` fields. Written by `ticket-dev.md` when the worktree is created. Read by `ticket-run.sh` on restart to verify/reconnect.

**Gap 2 — Session Restoration on Restart (Critical)**

Resolution: `session.json` added at `.klack/` root. `klack.sh` reads it on start to detect and restore existing sessions.

---

### Updated `.klack/` Structure

```
.klack/
├── session.json              ← session state (gitignored): tickets, types, started_at
├── activity.log              ← gitignored: append-only log read by log.sh
├── active_theme              ← gitignored: current theme name
├── cmd.fifo                  ← gitignored: named pipe for input commands
├── scripts/                  ← committed: internal scripts
│   ├── ticket-run.sh
│   └── hauptturm/            ← dashboard pane scripts
│       ├── theme.sh
│       ├── header.sh
│       ├── log.sh
│       ├── status.sh
│       ├── ticket-status.sh
│       ├── input.sh
│       └── layout.sh
└── signale/                  ← gitignored: runtime state per ticket
    └── IN-2262/
        ├── story.md
        ├── review.md
        ├── status.json       ← includes worktree_path + branch
        ├── question.txt
        ├── answer.txt
        ├── waiting.flag
        └── error.log
```

`.gitignore` entries: `.klack/signale/`, `.klack/session.json`, `.klack/activity.log`, `.klack/active_theme`, `.klack/cmd.fifo`

**Updated `status.json` Schema:**

```json
{
  "step": "init|story|dev|qa|review|release",
  "status": "pending|running|waiting|done|error",
  "log": "<last log entry>",
  "updated_at": "<ISO-8601>",
  "mr_url": null,
  "worktree_path": "/absolute/path/to/worktree",
  "branch": "worktree-feat/IN-2262-story-slug"
}
```

**`session.json` Schema:**

```json
{
  "started_at": "<ISO-8601>",
  "tickets": ["IN-2262", "IN-2200"],
  "types": {"IN-2262": "feat", "IN-2200": "fix"}
}
```

**Session Restore Logic in `klack.sh`:**

```
On start:
  tmux session "der-klack" exists?
    YES → attach, restore missing windows
    NO  → create fresh

  For each ticket in .klack/signale/:
    status = "done" | "error" → display only in Hauptturm (no window)
    status = "running"        → recreate window, restart current step
    status = "waiting"        → recreate window, redisplay question.txt in Hauptturm
    status = "pending"        → recreate window, start from beginning
```

---

### Architecture Completeness Checklist

- [x] Project context analyzed and cross-cutting concerns mapped
- [x] Technology stack decided (all pre-decided by concept document)
- [x] Message bus structure defined (`.klack/signale/`)
- [x] `status.json` schema with full field set including resilience fields
- [x] Ticket context injection pattern defined (prompt append)
- [x] Rücksignal write/read/consume order specified
- [x] Bash script style enforced (`set -euo pipefail`)
- [x] Slug generation rules (7-step algorithm)
- [x] Worktree verification pattern
- [x] Hauptturm tmux-native pane architecture
- [x] Error handling model (hard crash vs. Rücksignal)
- [x] Installer pattern defined
- [x] Session restoration on restart
- [x] All 15 FRs and 7 NFRs covered
- [x] Deferred epic documented (BMAD-Method planning integration)

### Architecture Readiness Assessment

**Overall Status: READY FOR IMPLEMENTATION**

**Confidence Level: High**

**Key Strengths:**
- Extreme simplicity: filesystem as message bus eliminates distributed systems complexity
- Clean process isolation: each step is a black box, testable independently
- Resilience by design: stateful `.klack/` enables full session restoration
- Clear patterns: 6 explicit rules prevent agent implementation conflicts
- Extensible: `.klack/` structure accommodates future subdirectories cleanly

**Areas for Future Enhancement:**
- BMAD-Method planning integration (deferred Epic 8)
- Jira status updates during processing
- Dependency analysis between parallel tickets

### Implementation Handoff

**AI Agents implementing klack MUST read this document before writing any code.**

**First Implementation Priority:** Epic 1 — Klack-Fundament (`klack.sh`, `ticket-run.sh`, `.klack/` structure, session restore logic)
