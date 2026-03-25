#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# layout.sh — Hauptturm Layout
# Header (3 lines) | Status (ticket cards) | Claude (main) | Sidebar (right)
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

# Pane 0 = header
tmux send-keys -t "$KLACK_SESSION:hauptturm.0" C-c 2>/dev/null || true
tmux respawn-pane -t "$KLACK_SESSION:hauptturm.0" -k "$PANE_CMD bash $SCRIPTS/header.sh" 2>/dev/null

# Split: status cards below header
tmux split-window -v -t "$KLACK_SESSION:hauptturm.0" "$PANE_CMD bash $SCRIPTS/status.sh"

# Split: claude pane below status (gets most space)
tmux split-window -v -p 70 -t "$KLACK_SESSION:hauptturm.1" "$PANE_CMD bash $SCRIPTS/claude-pane.sh"

# Split: worktree sidebar on the right of claude pane (25%)
tmux split-window -h -p 25 -t "$KLACK_SESSION:hauptturm.2" "$PANE_CMD bash $SCRIPTS/sidebar.sh"

# Sizes: header=3, status=8 (compact cards), rest=claude+sidebar
tmux resize-pane -t "$KLACK_SESSION:hauptturm.0" -y 3
tmux resize-pane -t "$KLACK_SESSION:hauptturm.1" -y 8

# Focus claude pane
tmux select-pane -t "$KLACK_SESSION:hauptturm.2"
