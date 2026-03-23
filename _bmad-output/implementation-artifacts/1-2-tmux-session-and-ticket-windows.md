# Story 1.2: tmux Session and Ticket Windows

Status: ready-for-dev

## Story

As a developer,
I want each ticket to get its own tmux window within a named session,
so that I can observe any ticket's raw Claude output independently.

## Acceptance Criteria

1. **Given** valid input was parsed
   **When** `klack.sh` continues startup
   **Then** a tmux session named `der-klack` is created (or reused if it exists)

2. **And** Window 0 is created and named `hauptturm` (placeholder for the dashboard)

3. **And** for each ticket ID a separate tmux window is created named after the ticket ID

4. **And** all windows start in the correct working directory

## Tasks / Subtasks

- [ ] Task 1: Create or attach to tmux session `der-klack` (AC: #1)
- [ ] Task 2: Name Window 0 as `hauptturm` (AC: #2)
- [ ] Task 3: Create one tmux window per ticket (AC: #3, #4)
- [ ] Task 4: Configure tmux session options (mouse on, status off, pane borders)

## Dev Notes

### Extends klack.sh

This story adds tmux session management to the existing `klack.sh` created in Story 1.1. Append after the argument parsing and model configuration section.

### tmux Session Configuration (from Architecture + UX)

```bash
tmux set-option -g mouse on
tmux set-option -g pane-border-style "fg=colour240"
tmux set-option -g pane-active-border-style "fg=colour51"
tmux set-option -g pane-border-lines heavy
tmux set-option -g pane-border-format "#{pane_title}"
tmux set-option -g status off
```
[Source: _bmad-output/planning-artifacts/ux-design-specification.md#tmux Session Configuration]

### Session Name

Always `der-klack`. If session already exists, attach to it (session restore is Story 1.6 — for now just reuse).

### Window Naming

- Window 0: `hauptturm`
- Per ticket: window named after ticket ID (e.g., `IN-2262`)

### Working Directory

All windows must start in the project root (where `klack.sh` was invoked from). Use `$(pwd)` at session/window creation time.

### What This Story Does NOT Do

- Does NOT start the Hauptturm pane scripts (Epic 2)
- Does NOT start the Turmwaechter in ticket windows (Story 1.4)
- Does NOT create `.klack/signale/` directories (Story 1.3)
- Window 0 is a placeholder — just an empty window named `hauptturm`
- Ticket windows are empty — just named windows in the correct directory

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Hauptturm Architecture]
- [Source: _bmad-output/planning-artifacts/ux-design-specification.md#tmux Session Configuration]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.2]

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List
