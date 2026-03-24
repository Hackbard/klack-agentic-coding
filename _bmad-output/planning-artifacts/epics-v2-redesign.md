---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
  - _bmad-output/planning-artifacts/epics.md
  - user-input-redesign-spec
status: complete
completedAt: '2026-03-24'
---

# Klack v2 Redesign — Epic Breakdown

## Overview

This document covers the Hauptturm redesign, smart initialization, worktree-centric sidebar, BMAD workflow launcher, and phase-aware orchestration. These epics build on the completed v1 pipeline (Epics 1–11).

## Requirements Inventory

### Functional Requirements (Redesign)

FR-R1: When klack starts in a directory, check if the project is already initialized for Klack/BMAD
FR-R2: If not initialized, prompt user for ticket system (Jira, GitLab, GitHub, Linear, markdown) and save to .klack.yml
FR-R3: Check if BMAD is initialized; if not, prompt user to run BMAD init
FR-R4: Hauptturm layout has 3 zones: statusbar (top), worktree sidebar (right), main shell/chat (center)
FR-R5: Worktree sidebar lists all git worktrees with their BMAD status from sprint-status.yaml
FR-R6: Status is derived by matching branch names in worktrees to ticket keys in sprint-status.yaml
FR-R7: A tmux keyboard shortcut opens a popup listing all available BMAD workflows
FR-R8: User can select a workflow from the popup to start a new worktree with that workflow
FR-R9: Each worktree has a .klack-worktree.yaml storing autonomy mode (yolo vs interactive)
FR-R10: BMAD Phase 1-3 workflows (planning) always open an interactive tmux window
FR-R11: After a planning window closes, the main shell asks "Autonom weiter im YOLO-Modus?"
FR-R12: The answer to the YOLO question is stored in .klack-worktree.yaml and controls Phase 4 behavior

### Non-Functional Requirements (Redesign)

NFR-R1: Sidebar status polling must not burn tokens — pure bash, no Claude invocations
NFR-R2: Worktree status refresh cycle ≤ 5 seconds
NFR-R3: Popup workflow picker must work without external dependencies (pure tmux + bash)
NFR-R4: Planning windows must be full tmux windows (not panes) for adequate space
NFR-R5: Initialization wizard must be skippable if .klack.yml already exists

## Epic List

### Epic 12: Smart Initialization
When klack starts, it detects whether the project is initialized and guides the user through setup if needed — ticket system selection and BMAD initialization check.

### Epic 13: Hauptturm Layout v2 — Worktree-Centric Sidebar
The Hauptturm gets a new 3-zone layout with a worktree sidebar that shows all git worktrees and their BMAD status, derived from sprint-status.yaml.

### Epic 14: BMAD Workflow Launcher & Autonomy Control
A tmux popup lets the user pick BMAD workflows, with phase-aware orchestration (planning = interactive, implementation = configurable YOLO mode).

---

## Epic 12: Smart Initialization

When klack starts, it detects whether the project is initialized and guides the user through setup if needed.

### Story 12.1: Project Initialization Check and Ticket System Wizard

As a developer,
I want klack to detect if the project is initialized and guide me through setup if not,
So that I can start using klack without manually creating config files.

**Acceptance Criteria:**

**Given** the developer runs `klack` in a directory without `.klack.yml`
**When** klack starts
**Then** it displays a welcome message and asks which ticket system to use (Jira, GitLab, GitHub, Linear, markdown)
**And** it creates `.klack.yml` with the selected `ticket_source` and sensible defaults for `pr_tool`, `pr_target_branch`, `ci_tool`
**And** for Jira: also asks for `jira_project` key
**And** for GitLab/GitHub: auto-detects from git remote URL

**Given** the developer runs `klack` in a directory with `.klack.yml`
**When** klack starts
**Then** it skips the wizard and proceeds normally

### Story 12.2: BMAD Initialization Check

As a developer,
I want klack to check if BMAD is initialized in the project,
So that I know whether I need to set up BMAD before using klack's full pipeline.

**Acceptance Criteria:**

**Given** the project has `.klack.yml` but no `_bmad/` directory
**When** klack starts
**Then** it displays a note: "BMAD not initialized. Run bmad init or install BMAD-Method skills for full pipeline support."
**And** klack continues (not blocked — BMAD is optional for basic ticket processing)

**Given** the project has both `.klack.yml` and `_bmad/` directory
**When** klack starts
**Then** no BMAD-related message is shown

---

## Epic 13: Hauptturm Layout v2 — Worktree-Centric Sidebar

The Hauptturm gets a new 3-zone layout with a worktree sidebar.

### Story 13.1: New 3-Zone Tmux Layout

As a developer,
I want the Hauptturm to have a clean 3-zone layout (statusbar, sidebar, main pane),
So that I have maximum space for my shell/Claude chat while still seeing all worktree statuses.

**Acceptance Criteria:**

**Given** klack starts and initializes the Hauptturm
**When** the layout is created
**Then** Window 0 is split into 3 zones:
  - Top: narrow statusbar pane (2-3 lines) showing session info, active theme, klack version
  - Right: sidebar pane (30-40 chars wide) listing worktrees with status
  - Center/Bottom: main pane for shell and Claude Code interaction
**And** the main pane has focus by default
**And** tmux mouse mode is ON for pane border resizing
**And** the sidebar width is configurable via `.klack.yml` (`sidebar_width`, default 35)

### Story 13.2: Worktree Sidebar with Status Polling

As a developer,
I want the right sidebar to list all git worktrees with their current BMAD status,
So that I can see at a glance which tickets are in progress, in review, or done.

**Acceptance Criteria:**

**Given** the sidebar pane is running (`sidebar.sh`)
**When** it polls (every 5 seconds)
**Then** it runs `git worktree list` to find all worktrees
**And** for each worktree it extracts the branch name
**And** it maps the branch name to a ticket key (using the branch naming convention: `worktree-{type}/{TICKET}-{slug}`)
**And** it looks up the ticket status from `_bmad-output/implementation-artifacts/sprint-status.yaml`
**And** it displays each worktree as: `{branch-short} [{status}]`
**And** status is color-coded: green=done, yellow=in-progress, blue=review, red=error, gray=backlog

**Given** a worktree branch does not match any ticket in sprint-status.yaml
**When** the sidebar renders
**Then** it shows the worktree with status `[unknown]` in gray

**Given** no sprint-status.yaml exists
**When** the sidebar polls
**Then** it shows all worktrees with `[no tracking]` and a note to run sprint-planning

### Story 13.3: Worktree Status Derivation from sprint-status.yaml

As a developer,
I want the sidebar to derive worktree status from the central BMAD sprint-status.yaml,
So that the status is always consistent with the project's sprint tracking.

**Acceptance Criteria:**

**Given** a worktree with branch `worktree-feat/E1-001-implement-happy-api`
**When** the sidebar parses the branch name
**Then** it extracts ticket key `E1-001` (or `1-1` for BMAD-style numbering)
**And** it searches sprint-status.yaml for a key containing that ticket identifier
**And** it returns the status value (done, in-progress, review, ready-for-dev, backlog)

**Given** sprint-status.yaml is modified externally (by dev-story or sprint-planning)
**When** the sidebar polls on next cycle
**Then** it picks up the updated status within 5 seconds
**And** zero tokens are burned — this is pure bash/grep/awk

---

## Epic 14: BMAD Workflow Launcher & Autonomy Control

A tmux popup lets the user pick BMAD workflows, with phase-aware orchestration.

### Story 14.1: Tmux Popup Workflow Picker

As a developer,
I want to press a keyboard shortcut and see a popup with all available BMAD workflows,
So that I can quickly start any workflow without remembering slash commands.

**Acceptance Criteria:**

**Given** the developer is in the Hauptturm tmux session
**When** they press `Ctrl-b w` (or configurable shortcut in .klack.yml)
**Then** a tmux display-popup appears in the center of the screen
**And** it lists all available BMAD workflows grouped by phase:
  - Phase 1 (Planning): Product Brief, PRD, Market Research, Domain Research
  - Phase 2 (Design): UX Design, Architecture, Technical Research
  - Phase 3 (Sprint): Create Epics & Stories, Sprint Planning, Create Story
  - Phase 4 (Implementation): Dev Story, QA Tests, Code Review, Release
**And** each workflow has a number for quick selection
**And** the user types a number and hits Enter to select

**Given** the user selects a workflow
**When** the popup closes
**Then** klack determines the phase and proceeds according to phase rules (see Story 14.3)

### Story 14.2: Per-Worktree Autonomy Config (.klack-worktree.yaml)

As a developer,
I want each worktree to have its own autonomy config,
So that I can run some worktrees in YOLO mode and others interactively.

**Acceptance Criteria:**

**Given** a new worktree is created (via workflow launcher or manually)
**When** klack initializes the worktree
**Then** a `.klack-worktree.yaml` is created in the worktree root with:
  - `mode: interactive` (default)
  - `workflow: <selected-workflow-name>`
  - `created_at: <ISO-8601>`

**Given** the developer answers "ja" to "Autonom weiter im YOLO-Modus?"
**When** klack updates the config
**Then** `.klack-worktree.yaml` is updated with `mode: yolo`
**And** subsequent Phase 4 steps in this worktree run with `--dangerously-skip-permissions` and no review pauses

**Given** the developer answers "nein"
**When** klack updates the config
**Then** `.klack-worktree.yaml` keeps `mode: interactive`
**And** subsequent Phase 4 steps pause for review after each step (--review behavior)

### Story 14.3: Phase-Aware Workflow Orchestration

As a developer,
I want planning workflows to always be interactive and implementation workflows to respect my YOLO setting,
So that I collaborate on planning but can let implementation run autonomously.

**Acceptance Criteria:**

**Given** the user selects a Phase 1, 2, or 3 workflow from the popup
**When** klack starts the workflow
**Then** a new tmux WINDOW is created (not a pane) with the workflow name
**And** an interactive Claude session (`claude -c`) is started in that window
**And** the selected BMAD skill is loaded as context
**And** the developer collaborates with Claude in that window
**And** this window is never run in background/autonomous mode

**Given** the user selects a Phase 4 workflow from the popup
**When** klack starts the workflow
**Then** it reads `.klack-worktree.yaml` for the mode setting
**And** if `mode: yolo`: runs fully autonomous (claude -p, no pauses)
**And** if `mode: interactive`: runs with --review mode (pauses after each step)

### Story 14.4: Planning-to-Implementation Transition

As a developer,
I want klack to ask me about YOLO mode when I finish a planning session,
So that I make an explicit choice about how the implementation should proceed.

**Acceptance Criteria:**

**Given** the developer closes a planning window (Phase 1-3 workflow)
**When** they return to the main Hauptturm shell
**Then** klack detects the closed window and displays in the main pane:
  "Planungs-Session beendet. Moechtest du die Implementierung im YOLO-Modus (vollautonom) starten? [j/n]"
**And** waits for developer input

**Given** the developer answers "j" (yes)
**When** klack processes the answer
**Then** it updates `.klack-worktree.yaml` with `mode: yolo`
**And** it prints confirmation: "YOLO-Modus aktiviert. Implementierung laeuft autonom."
**And** if there are Phase 4 workflows pending, it starts them automatically

**Given** the developer answers "n" (no)
**When** klack processes the answer
**Then** it updates `.klack-worktree.yaml` with `mode: interactive`
**And** it prints: "Interaktiver Modus. Du wirst nach jedem Step gefragt."
