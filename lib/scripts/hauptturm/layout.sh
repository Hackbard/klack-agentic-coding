#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# layout.sh — Hauptturm Layout
# Grid: 12 columns. Claude=7, Right side=5.
# Header (1 line) | Status cards | Claude (left 58%) |
# Live Log (right top 60%) | Worktrees (right bottom 40%)
# ============================================================================

KLACK_ROOT="${KLACK_ROOT:?KLACK_ROOT not set}"
KLACK_SESSION="${KLACK_SESSION:-der-klack}"
SCRIPTS="$KLACK_ROOT/.klack/scripts/hauptturm"

export KLACK_ROOT KLACK_SESSION

tmux set-option -t "$KLACK_SESSION" default-shell "/bin/zsh" 2>/dev/null || true

PANE_CMD="export KLACK_ROOT='$KLACK_ROOT' KLACK_SESSION='$KLACK_SESSION';"

# Kill all panes except pane 0
count="$(tmux list-panes -t "$KLACK_SESSION:hauptturm" 2>/dev/null | wc -l | tr -d ' ')"
while [[ "$count" -gt 1 ]]; do
  tmux kill-pane -t "$KLACK_SESSION:hauptturm.1" 2>/dev/null || break
  count=$((count - 1))
done

# Pane 0 = header (1 line)
tmux send-keys -t "$KLACK_SESSION:hauptturm.0" C-c 2>/dev/null || true
tmux respawn-pane -t "$KLACK_SESSION:hauptturm.0" -k "$PANE_CMD bash $SCRIPTS/header.sh" 2>/dev/null

# Split: status cards below header
tmux split-window -v -t "$KLACK_SESSION:hauptturm.0" "$PANE_CMD bash $SCRIPTS/status.sh"

# Split: claude pane below status (gets most vertical space)
tmux split-window -v -p 75 -t "$KLACK_SESSION:hauptturm.1" "$PANE_CMD bash $SCRIPTS/claude-pane.sh"

# Split: right side from claude pane — 5/12 = 42%
tmux split-window -h -p 42 -t "$KLACK_SESSION:hauptturm.2" "$PANE_CMD bash $SCRIPTS/livelog.sh"

# Split: worktrees below livelog — 40% of right side
tmux split-window -v -p 40 -t "$KLACK_SESSION:hauptturm.3" "$PANE_CMD bash $SCRIPTS/sidebar.sh"

# Header = 1 line only
tmux resize-pane -t "$KLACK_SESSION:hauptturm.0" -y 1

# Status cards = 5 lines (compact)
tmux resize-pane -t "$KLACK_SESSION:hauptturm.1" -y 5

# Focus claude pane
tmux select-pane -t "$KLACK_SESSION:hauptturm.2"
