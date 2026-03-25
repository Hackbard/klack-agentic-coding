# Story 13.1: New 3-Zone Tmux Layout + Worktree Sidebar

Status: review

## Story

**As a** developer,
**I want** the Hauptturm to have a clean 3-zone layout (statusbar, sidebar, main pane),
**So that** I have maximum space for my shell/Claude chat while still seeing all worktree statuses.

## Acceptance Criteria (combined 13.1 + 13.2 + 13.3)

### AC1: 3-Zone Layout
- [ ] Window 0 splits into: statusbar (top, 2 lines), sidebar (right, 35 chars), main pane (center)
- [ ] Main pane has focus by default
- [ ] tmux mouse mode ON for pane border resizing

### AC2: Worktree Sidebar
- [ ] sidebar.sh polls every 5 seconds
- [ ] Lists all git worktrees with branch name and BMAD status
- [ ] Status color-coded: green=done, yellow=in-progress, blue=review, red=error, gray=backlog

### AC3: Status Derivation
- [ ] Extracts ticket key from branch name (worktree-{type}/{TICKET}-{slug})
- [ ] Looks up status from sprint-status.yaml
- [ ] Shows [unknown] for unmatched branches, [no tracking] if no sprint-status.yaml

## Tasks

- [x] Create `lib/scripts/hauptturm/sidebar.sh` — worktree list + status polling
- [x] Add `worktree` layout to `layout.sh` (header top, sidebar right, main center)
- [x] Update sprint-status
- [ ] Test layout renders correctly

## Dev Notes

- Stories 13.1, 13.2, 13.3 are implemented together as they are inseparable.
- sidebar.sh is pure bash — grep/awk on sprint-status.yaml, no tokens burned.
- Branch format: `worktree-{type}/{TICKET}-{slug}` — extract TICKET part.
