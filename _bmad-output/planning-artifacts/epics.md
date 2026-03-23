---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - der-klack-konzept.md
---

# cc-crew (Der Klack) - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for cc-crew (Der Klack), decomposing the requirements from the concept document into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: Der Entwickler startet das System mit `cc-crew {typ} {ticket-ids}` und erhält autonome Abarbeitung aller Tickets
FR2: `cc-crew` legt eine tmux-Session mit Window 0 (Hauptturm) und je einem Window pro Ticket an
FR3: Der Hauptturm zeigt kontinuierlich Status aller Tickets (aktueller Step, Fortschrittsbalken, letzter Log-Eintrag)
FR4: Der Hauptturm empfängt Rückfragen aus laufenden Türmen und zeigt sie prominent an
FR5: Der Entwickler beantwortet Rückfragen direkt im Hauptturm; die Antwort wird in `answer.txt` geschrieben und das Flag gelöscht
FR6: Der Entwickler kann aus dem Hauptturm neue Tickets zur laufenden Session hinzufügen
FR7: Jeder BMAD-Method-Step startet als eigener Claude-Prozess mit frischem Kontext (kein `/clear`)
FR8: `ticket-story`: Jira-Ticket via Atlassian MCP einlesen, Story anreichern, alle Unklarheiten klären, vollständige `story.md` schreiben – erst dann fertig
FR9: `ticket-dev`: Ausschließlich `story.md` lesen, Git-Worktree anlegen/prüfen, implementieren (kein Test-Code), committen
FR10: `ticket-qa`: PEST-Tests schreiben (domänenspezifisch, Happy-Path + Edge Cases), Quality Gate Loop (CS-Fixer fix, PHPStan, PEST mit Coverage), max. 3 Iterationen
FR11: `ticket-review`: Nur Git-Diff als Input, Review als externer Entwickler, `review.md` schreiben, bei kritischen Findings blockieren + Rücksignal
FR12: `ticket-release`: `review.md` lesen, MR via `glab` gegen develop erstellen, Jira-Kommentar mit KI-Gruß schreiben, Turm als fertig markieren
FR13: Rücksignal-Mechanismus: `question.txt` schreiben + `waiting.flag` setzen + Poll-Schleife
FR14: Branch-Naming: `worktree-{feat|fix|hot}/{TICKET-ID}-{slug-aus-story-titel}`
FR15: Modell-Konfiguration via Umgebungsvariablen vor dem Start setzen
FR16: Der Entwickler kann zwischen 5 Hauptturm-Layouts wechseln (hybrid, fullchat, twocol, threezone, dashboard)
FR17: Der Entwickler kann zwischen 5 Farb-Schemata wechseln (unicorn, cylon, kitt, shufflepuck, monochrome)
FR18: Alle Entwickler-Interaktion erfolgt über eine persistente Input-Bar mit einheitlicher Command-Grammatik
FR19: tmux Mouse-Mode ist aktiv — Pane-Grenzen sind per Maus verschiebbar

### NonFunctional Requirements

NFR1: Alle Claude-Prozesse starten mit `--dangerously-skip-permissions` (kein manuelles Bestätigen)
NFR2: Alle Claude-Prozesse starten mit `--chrome` Flag
NFR3: Saubere Kontexttrennung: jeder BMAD-Method-Step = eigener Claude-Prozess = frischer Kontext
NFR4: Quality Gate mit CI-Parität: CS-Fixer (lokal ohne --dry-run), PHPStan (`memory_limit=1024M -vvv`), PEST (`--parallel`, 95% Coverage mit pcov)
NFR5: Maximal 3 QA-Iterationen vor Abbruch mit `error.log` + Rücksignal
NFR6: BMAD-Method-Definitionen unter `_bmad/` bleiben unverändert
NFR7: Sub-Agent-Model: Haiku (`CLAUDE_CODE_SUBAGENT_MODEL`), Haupt-Agents: Sonnet, Review-Step: Opus

### Additional Requirements

- Kommunikation ausschließlich über Dateien in `.klack/signale/{TICKET}/` (kein IPC, keine Sockets)
- Dateien pro Ticket: `story.md`, `review.md`, `status.json`, `question.txt`, `answer.txt`, `waiting.flag`, `error.log`
- Worktree-Verifikation: `.git` muss Datei sein (nicht Verzeichnis), sonst sofortiger Abbruch
- Step-Commands als Markdown unter `.claude/commands/ticket-{step}.md`
- `.gitlab-ci.yml` ist einzige Quelle der Wahrheit für Quality Gate Commands und Parameter
- Jeder Turmwächter-Start: `claude --dangerously-skip-permissions --chrome -p "$(cat .claude/commands/ticket-STEP.md)"`

### UX Design Requirements

UX1: Hauptturm uses tmux-native pane architecture with 4 specialized pane scripts (header, log, status, input)
UX2: 5 selectable layouts: hybrid, fullchat, twocol, threezone, dashboard
UX3: 5 selectable color schemes: unicorn, cylon, kitt, shufflepuck, monochrome
UX4: Mouse-draggable pane borders for developer customization
UX5: Persistent input bar for unified command interaction

### FR Coverage Map

```
FR1:  Epic 3 – CLI Input-Parsing und Ticket-Dispatch
FR2:  Epic 1 – tmux-Session und Window-Verwaltung
FR3:  Epic 2, Story 2.1 – Kontinuierliche Status-Anzeige im Hauptturm (status.sh Pane)
FR4:  Epic 2, Story 2.2 – Rückfragen im Hauptturm anzeigen (Status-Pane Preview + Activity-Log Box)
FR5:  Epic 2, Story 2.2 + Story 2.6 – Antworten eingeben via Input-Bar, Flag löschen
FR6:  Epic 2, Story 2.3 + Story 2.6 – Neue Tickets zur Session hinzufügen via Input-Bar
Note: Stories 2.4, 2.5, 2.6 are new requirements from UX design (FR16–FR19)
FR7:  Epic 1 – Frischer Claude-Prozess pro Step
FR8:  Epic 3 – ticket-story Command
FR9:  Epic 4 – ticket-dev Command
FR10: Epic 5 – ticket-qa Command mit Quality Gate Loop
FR11: Epic 6 – ticket-review Command
FR12: Epic 7 – ticket-release Command
FR13: Epic 1 – Rücksignal-Mechanismus (Dateistruktur + Poll-Schleife)
FR14: Epic 4 – Branch-Naming + Worktree-Verwaltung
FR15: Epic 1 – Modell-Konfiguration via Umgebungsvariablen
FR16: Epic 2, Story 2.4 – Layout-Switching (5 Layouts)
FR17: Epic 2, Story 2.5 – Theme-Switching (5 Farb-Schemata)
FR18: Epic 2, Story 2.6 – Persistente Input-Bar mit Command-Grammatik
FR19: Epic 2, Story 2.1 – tmux Mouse-Mode für Pane-Grenzen
```

## Epic List

### Epic 1: Klack-Fundament
Der Entwickler kann `cc-crew` aufrufen und die gesamte Infrastruktur steht bereit – tmux-Session, `.crew/`-Verzeichnisstruktur, Modell-Konfiguration, Turmwächter-Orchestrierung und Rücksignal-Mechanismus.
**FRs covered:** FR2, FR7, FR13, FR15 | NFR1, NFR2, NFR7

### Epic 2: Ankh-Morpork Hauptturm
Der Entwickler hat eine tmux-native Pane-Architektur im Hauptturm (Window 0): mehrere spezialisierte Pane-Scripts (`header.sh`, `log.sh`, `status.sh`, `input.sh`), 5 wählbare Layouts (hybrid, fullchat, twocol, threezone, dashboard), 5 wählbare Farb-Schemata (unicorn, cylon, kitt, shufflepuck, monochrome) und per Maus verschiebbare Pane-Grenzen. Alle Interaktion erfolgt über eine persistente Input-Bar.
**FRs covered:** FR3, FR4, FR5, FR6, FR16, FR17, FR18, FR19

### Epic 3: Story-Analyse (ticket-story)
Der Entwickler übergibt eine Ticket-ID und erhält eine vollständige, implementierungsfertige `story.md` – inklusive geklärter Unklarheiten.
**FRs covered:** FR1, FR8

### Epic 4: Autonome Implementierung (ticket-dev)
Das System implementiert eine Story selbständig in einem isolierten Git-Worktree mit korrektem Branch-Naming – der Entwickler muss nichts tun.
**FRs covered:** FR9, FR14

### Epic 5: Quality Gate (ticket-qa)
Das System schreibt domänenspezifische Tests und durchläuft den iterativen Quality Gate Loop bis der Code CI-Parität erreicht – oder bricht sauber ab.
**FRs covered:** FR10 | NFR4, NFR5

### Epic 6: Code Review (ticket-review)
Das System führt einen unvoreingenommenen Review durch und blockiert bei kritischen Findings – der Entwickler entscheidet nur wenn es wirklich nötig ist.
**FRs covered:** FR11 | NFR7

### Epic 7: Release (ticket-release)
Das System schließt das Ticket vollständig ab: Merge Request erstellt, Jira-Kommentar geschrieben, Turm als fertig markiert.
**FRs covered:** FR12

---

## Epic 1: Klack-Fundament

Der Entwickler kann `cc-crew` aufrufen und die gesamte Infrastruktur steht bereit – tmux-Session, `.crew/`-Verzeichnisstruktur, Modell-Konfiguration, Turmwächter-Orchestrierung und Rücksignal-Mechanismus.

### Story 1.1: cc-crew – Argument-Parsing and Model Configuration

As a developer,
I want to call `cc-crew feat IN-2262 fix IN-2200` with ticket type and IDs,
So that the system validates my input and sets the correct model environment before anything starts.

**Acceptance Criteria:**

**Given** the developer calls `cc-crew` with valid ticket type(s) (feat/fix/hot) and ticket ID(s)
**When** the script starts
**Then** the environment variables `ANTHROPIC_MODEL` (Sonnet) and `CLAUDE_CODE_SUBAGENT_MODEL` (Haiku) are exported
**And** the Opus model variable for the review step is exported

**Given** the developer calls `cc-crew` with an invalid ticket type (not feat/fix/hot)
**When** the script starts
**Then** an error message is shown and the script exits with code 1

**Given** the developer calls `cc-crew` with no arguments
**When** the script starts
**Then** a usage hint is displayed and the script exits with code 1

---

### Story 1.2: tmux Session and Ticket Windows

As a developer,
I want each ticket to get its own tmux window within a named session,
So that I can observe any ticket's raw Claude output independently without it being required.

**Acceptance Criteria:**

**Given** valid input was parsed
**When** `cc-crew` continues startup
**Then** a tmux session named `der-klack` is created (or reused if it exists)
**And** Window 0 is created and named `hauptturm` (placeholder for the dashboard)
**And** for each ticket ID a separate tmux window is created named after the ticket ID
**And** all windows start in the correct working directory

---

### Story 1.3: Klack-Signale Directory Structure

As a developer,
I want the `.klack/signale/{TICKET}/` directory structure created automatically,
So that all steps have their communication files ready before the first Claude process starts.

**Acceptance Criteria:**

**Given** a ticket window has been created
**When** the setup for that ticket runs
**Then** `.klack/signale/{TICKET}/` is created if it does not exist
**And** `status.json` is initialized with `{"step": "init", "status": "pending", "log": ""}`
**And** `error.log` is created empty
**And** `question.txt`, `answer.txt`, `waiting.flag` are not created yet (only on demand)

---

### Story 1.4: Turmwächter – Step Execution and Status Tracking

As a developer,
I want the Turmwächter to run each BMAD-Method step as a fresh Claude process and track progress in `status.json`,
So that each step has clean context and the Hauptturm can display the current state.

**Acceptance Criteria:**

**Given** the `.crew` structure for a ticket is initialized
**When** the Turmwächter (`ticket-run.sh`) starts
**Then** it executes steps sequentially: story → dev → qa → review → release
**And** each step is started with: `claude --dangerously-skip-permissions --chrome -p "$(cat .claude/commands/ticket-STEP.md)"`
**And** before each step `status.json` is updated with the current step name and status `"running"`
**And** after a successful step status is set to `"done"` for that step
**And** on exit code != 0 the error is written to `error.log`, status set to `"error"`, and the Turmwächter stops

---

### Story 1.5: Rücksignal-Mechanismus – Waiting and Resuming

As a developer,
I want the Turmwächter to pause when a question flag is set and continue automatically when I answer,
So that no step runs without my input when needed and I never miss a question.

**Acceptance Criteria:**

**Given** a Claude process has written `question.txt` and set `waiting.flag`
**When** the Turmwächter checks before starting the next step
**Then** it enters a poll loop (5-second interval) and does not start the next step
**And** it updates `status.json` with status `"waiting"`

**Given** the developer has written `answer.txt` and deleted `waiting.flag`
**When** the Turmwächter checks in its poll loop
**Then** it reads `answer.txt` and resumes execution
**And** status in `status.json` is reset to `"running"`

---

### Story 1.6: Session Restore on Restart

As a developer,
I want the system to detect and restore a previous session when I run `klack.sh` again,
So that interrupted work continues from where it left off without manual recovery.

**Acceptance Criteria:**

**Given** the developer runs `klack.sh` without ticket arguments
**When** `.klack/session.json` exists
**Then** the system reads session state and restores based on each ticket's status:
  - `done` or `error` → displayed in Hauptturm only (no tmux window created)
  - `running` → tmux window recreated, current step restarted
  - `waiting` → tmux window recreated, question re-displayed in Hauptturm
  - `pending` → tmux window recreated, starts from beginning

**Given** the developer runs `klack.sh` without ticket arguments
**When** no `.klack/session.json` exists
**Then** a usage hint is displayed and the script exits with code 1

**Given** the tmux session `der-klack` already exists
**When** `klack.sh` is called
**Then** it attaches to the existing session instead of creating a new one

---

### Story 1.7: Installer Script

As a developer,
I want an `install.sh` script that copies all klack files into my target project,
So that I can set up Der Klack in any project with a single command.

**Acceptance Criteria:**

**Given** the developer runs `install.sh <target-project-path>`
**When** the installer executes
**Then** it copies `commands/ticket-*.md` to `<target>/.claude/commands/`
**And** it copies `scripts/klack.sh` to `<target>/klack.sh` and makes it executable
**And** it copies `scripts/ticket-run.sh` to `<target>/.klack/scripts/`
**And** it copies `scripts/hauptturm/` to `<target>/.klack/scripts/hauptturm/`
**And** it adds `.klack/signale/`, `.klack/session.json`, `.klack/activity.log`, `.klack/active_theme`, `.klack/cmd.fifo` to `<target>/.gitignore`
**And** it verifies that `tmux`, `glab`, and `claude` are available in PATH

**Given** a required dependency is not found in PATH
**When** the installer checks dependencies
**Then** it prints which dependency is missing and exits with code 1

---

## Epic 2: Ankh-Morpork Hauptturm

Der Entwickler hat eine tmux-native Pane-Architektur im Hauptturm (Window 0): mehrere spezialisierte Pane-Scripts, wählbare Layouts und Farb-Schemata, per Maus verschiebbare Pane-Grenzen. Alle Interaktion erfolgt über eine persistente Input-Bar.

### Story 2.1: Status Dashboard – All Tickets at a Glance

As a developer,
I want Window 0 to be split into multiple tmux panes running specialized scripts,
So that I have a complete overview of all running tickets without switching into individual tower windows.

**Acceptance Criteria:**

**Given** the Hauptturm is started as Window 0
**When** the layout is initialized
**Then** Window 0 is split into multiple tmux panes running the following scripts from `.klack/scripts/hauptturm/`:
  - `header.sh` — session summary (ticket count, session uptime, active theme/layout)
  - `log.sh` — scrollable activity log
  - `status.sh` — ticket status cards (one per ticket)
  - `input.sh` — command prompt for developer interaction
**And** all scripts source `theme.sh` for color and symbol constants
**And** tmux mouse mode is ON — the developer can drag pane borders to resize
**And** the default layout is `hybrid` (header top, log center-left, status center-right, input bottom)

**Given** the status pane is running
**When** any ticket's `.klack/signale/{TICKET}/status.json` changes
**Then** the status pane refreshes within 5 seconds showing: ticket ID, current step, status, last log entry
**And** completed tickets are shown with a visual "done" indicator
**And** errored tickets are shown with a visual "error" indicator and the last error log line

**Given** any component generates an event
**When** it writes to `.klack/activity.log` (append-only)
**Then** `log.sh` picks up the new entry and displays it in the activity log pane

---

### Story 2.2: Question Display and Answer Input

As a developer,
I want pending questions from any tower to appear prominently in the Hauptturm,
So that I can answer directly without knowing which ticket window to switch to.

**Acceptance Criteria:**

**Given** any ticket has `waiting.flag` set and `question.txt` written
**When** the Hauptturm detects the flag
**Then** the question appears in BOTH the status pane (as a preview line on the ticket card) AND as a bordered box in the activity log pane
**And** the bordered box includes the ticket ID and the full question text

**Given** the developer wants to answer a question
**When** the developer types `answer IN-XXXX "response text"` in the input bar pane (`input.sh`)
**Then** `input.sh` writes the answer to `.klack/signale/{TICKET}/answer.txt`
**And** `input.sh` deletes `.klack/signale/{TICKET}/waiting.flag`
**And** the question preview disappears from the status pane on next refresh
**And** the answer is echoed to the activity log
**And** no window switching is needed at any point

---

### Story 2.3: Add New Tickets to Running Session

As a developer,
I want to add new ticket IDs to the running session from the Hauptturm,
So that I can queue additional work without restarting the entire session.

**Acceptance Criteria:**

**Given** the Hauptturm is running
**When** the developer types `add feat IN-2300` in the input bar
**Then** a new tmux window is created for the new ticket
**And** the `.klack/signale/{TICKET}/` structure is initialized for the new ticket
**And** the Turmwächter starts in the new window
**And** the new ticket gets assigned the next color from the active scheme's spectrum
**And** the status pane adds the new ticket card on next refresh

---

### Story 2.4: Layout Switching

As a developer,
I want to switch between different Hauptturm layouts at runtime,
So that I can choose the optimal view for my current situation.

**Acceptance Criteria:**

**Given** the Hauptturm is running
**When** the developer types `layout <name>` (hybrid/fullchat/twocol/threezone/dashboard)
**Then** all Hauptturm panes are killed and recreated according to the target layout
**And** each pane script starts fresh, reading current state from filesystem
**And** no data is lost (`status.json` and `activity.log` persist)
**And** the switch completes within one refresh cycle (≤5 seconds)

**Given** the terminal width is less than 120 columns
**When** the developer tries to switch to a layout requiring more space
**Then** a warning is shown in the activity log suggesting `layout fullchat`

---

### Story 2.5: Theme Switching

As a developer,
I want to switch between color schemes at runtime,
So that I can personalize the Hauptturm's visual appearance.

**Acceptance Criteria:**

**Given** the Hauptturm is running with any layout
**When** the developer types `theme <name>` (unicorn/cylon/kitt/shufflepuck/monochrome)
**Then** the active theme is written to `.klack/active_theme`
**And** tmux pane border colors update immediately
**And** SIGUSR1 is sent to all pane script PIDs
**And** each pane script re-sources `theme.sh` and re-renders with new colors
**And** the default theme is `unicorn` (rainbow — each ticket gets its own color)

---

### Story 2.6: Input Bar Command Handler

As a developer,
I want a persistent input bar in the Hauptturm that accepts all commands,
So that I never need to switch windows for routine operations.

**Acceptance Criteria:**

**Given** the input bar pane is running (`input.sh`)
**When** the developer types a command and hits Enter
**Then** the command is parsed and dispatched:
  - `answer IN-XXXX "text"` — writes `answer.txt`, deletes `waiting.flag`
  - `add <type> IN-XXXX` — creates new ticket (tmux window + `.klack` structure + status pane entry)
  - `error IN-XXXX` — displays full `error.log` in activity log
  - `retry IN-XXXX` — restarts ticket from failed step
  - `abort IN-XXXX` — stops ticket, preserves state
  - `layout <name>` — switches layout
  - `theme <name>` — switches color scheme
  - `status` — forces refresh of all displays
  - `help` — shows command reference in activity log
**And** unknown commands show an error message in the activity log
**And** empty Enter (no input) does nothing
**And** the user's command is echoed to the activity log: `[>] command text`

---

## Epic 3: Story-Analyse (ticket-story)

Der Entwickler übergibt eine Ticket-ID und erhält eine vollständige, implementierungsfertige `story.md` – inklusive geklärter Unklarheiten.

### Story 3.1: ticket-story Command – Jira Ticket Ingestion

As a developer,
I want the ticket-story step to read the full Jira ticket via the Atlassian MCP,
So that all ticket details, comments and linked issues are available for story enrichment.

**Acceptance Criteria:**

**Given** the Turmwächter starts the ticket-story step with a ticket ID
**When** the Claude process runs the ticket-story command
**Then** it reads the full Jira ticket including description, comments, and linked issues via Atlassian MCP
**And** it identifies all ambiguities or missing information in the ticket
**And** for each unresolvable ambiguity it uses the Rücksignal-Mechanismus to ask the developer

**Given** all ambiguities are resolved (either autonomously or via developer answer)
**When** the command continues
**Then** it proceeds to write the enriched story

---

### Story 3.2: Enriched story.md Creation

As a developer,
I want the ticket-story step to produce a complete, implementation-ready `story.md`,
So that the ticket-dev step has everything it needs without needing the Jira ticket at all.

**Acceptance Criteria:**

**Given** all ticket information is gathered and ambiguities resolved
**When** the command writes the story
**Then** `story.md` is written to `.klack/signale/{TICKET}/story.md`
**And** the story contains: title, user story, acceptance criteria, technical notes, and any developer answers incorporated
**And** the step is only marked complete when `story.md` exists and contains all required sections
**And** if any required section is missing the step uses the Rücksignal-Mechanismus rather than writing an incomplete story

---

## Epic 4: Autonome Implementierung (ticket-dev)

Das System implementiert eine Story selbständig in einem isolierten Git-Worktree – der Entwickler muss nichts tun.

### Story 4.1: Git Worktree and Branch Setup

As a developer,
I want the ticket-dev step to create and verify a Git worktree with the correct branch name,
So that all implementation work is isolated and never touches the main repository working tree.

**Acceptance Criteria:**

**Given** the ticket-dev step starts
**When** it sets up the worktree
**Then** it reads the story title from `story.md` to generate the slug (lowercase, spaces to hyphens, max 40 chars, special chars removed)
**And** it creates the branch `worktree-{type}/{TICKET-ID}-{slug}` if it does not exist
**And** it creates or verifies the Git worktree for that branch
**And** it verifies it is inside a worktree by checking that `.git` is a file (not a directory)
**And** if the worktree check fails it writes to `error.log` and exits immediately with code 1

---

### Story 4.2: Story Implementation and Commit

As a developer,
I want the ticket-dev step to implement the story according to project coding standards and commit the result,
So that a complete, committable implementation exists in the worktree before QA starts.

**Acceptance Criteria:**

**Given** the worktree is set up and verified
**When** the ticket-dev step implements the story
**Then** it reads exclusively from `story.md` — no other context
**And** it implements all acceptance criteria from the story
**And** it writes no test code (tests are the responsibility of ticket-qa)
**And** it follows the project's existing coding standards and patterns
**And** it commits all changes with a meaningful commit message referencing the ticket ID
**And** the step is only marked complete after a successful git commit

---

## Epic 5: Quality Gate (ticket-qa)

Das System schreibt domänenspezifische Tests und durchläuft den iterativen Quality Gate Loop bis CI-Parität erreicht ist.

### Story 5.1: PEST Test Writing

As a developer,
I want the ticket-qa step to write domain-specific PEST tests for the implemented story,
So that the code is covered by meaningful tests before the quality gate runs.

**Acceptance Criteria:**

**Given** the ticket-qa step starts
**When** it reads `story.md` and the current code state
**Then** it writes PEST tests for every acceptance criterion in the story
**And** test data is domain-specific and realistic (not pure random Faker data)
**And** every relevant happy path has a test
**And** every relevant edge case and negative path has a test
**And** tests are written in the worktree alongside the implementation

---

### Story 5.2: Quality Gate Loop

As a developer,
I want the ticket-qa step to run the full quality gate loop and fix issues automatically,
So that the code reaches CI parity before the review step.

**Acceptance Criteria:**

**Given** PEST tests have been written
**When** the quality gate loop starts
**Then** it first reads `.gitlab-ci.yml` to extract the exact commands, parameters, and thresholds
**And** it runs PHP-CS-Fixer locally without `--dry-run` (direct fix)
**And** it runs PHPStan with `memory_limit=1024M` and `-vvv`
**And** it runs PEST with `--parallel` and checks for 95% coverage with pcov
**And** if any tool reports errors it returns to fix the code and re-runs the loop
**And** after 3 failed iterations it writes a failure report to `error.log` and sends a Rücksignal to the developer
**And** the step is only marked complete when all three tools pass in the same iteration

---

## Epic 6: Code Review (ticket-review)

Das System führt einen unvoreingenommenen Review durch und blockiert bei kritischen Findings.

### Story 6.1: Git Diff Review and review.md

As a developer,
I want the ticket-review step to review only the Git diff as an external developer would,
So that the review is unbiased and catches issues that familiarity with the implementation might miss.

**Acceptance Criteria:**

**Given** the ticket-review step starts
**When** the Claude process (running on Opus) executes
**Then** it receives only the Git diff as input — no `story.md`, no development history
**And** it reviews for: edge cases, security, performance, SOLID violations, project standard deviations
**And** it writes a structured review to `.klack/signale/{TICKET}/review.md` with findings categorized by severity
**And** the review clearly distinguishes: blocking (critical) vs. non-blocking findings

---

### Story 6.2: Critical Finding Block and Rücksignal

As a developer,
I want the ticket-review step to block on critical findings and ask me for a decision,
So that no code with critical issues proceeds to release without my explicit approval.

**Acceptance Criteria:**

**Given** `review.md` contains one or more critical findings
**When** the review step completes its analysis
**Then** it uses the Rücksignal-Mechanismus to send the critical findings to the developer
**And** it waits for the developer's decision before the Turmwächter proceeds to release

**Given** `review.md` contains only non-blocking findings or no findings
**When** the review step completes
**Then** the Turmwächter proceeds to the release step without developer input

---

## Epic 7: Release (ticket-release)

Das System schließt das Ticket vollständig ab: Merge Request erstellt, Jira-Kommentar geschrieben, Turm als fertig markiert.

### Story 7.1: Merge Request Creation via glab

As a developer,
I want the ticket-release step to create a Merge Request automatically,
So that the code is ready for human review on GitLab without any manual steps.

**Acceptance Criteria:**

**Given** `review.md` exists and contains no blocking findings (or blocking findings were approved by the developer)
**When** the ticket-release step runs
**Then** it generates an MR title from the story title and ticket ID
**And** it generates an MR description from `story.md` and `review.md` (including non-blocking findings as notes)
**And** it creates the MR via `glab mr create` targeting the `develop` branch
**And** it records the MR URL in `status.json`

---

### Story 7.2: Jira Comment and Tower Completion

As a developer,
I want the ticket-release step to comment on the Jira ticket and mark the tower as done,
So that all stakeholders are informed and the Hauptturm shows the ticket as fully complete.

**Acceptance Criteria:**

**Given** the MR was created successfully
**When** the ticket-release step continues
**Then** it posts a comment to the Jira ticket via Atlassian MCP with: a brief summary of the implementation and a friendly AI greeting
**And** it updates `status.json` with step `"release"` and status `"done"`
**And** the Hauptturm displays the ticket with a visual "complete" indicator

**Given** either the MR creation or the Jira comment fails
**When** the step encounters the error
**Then** it writes the error to `error.log` and sends a Rücksignal to the developer
