#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# layout.sh — Layout switcher
# Kills and recreates Hauptturm panes according to target layout
# ============================================================================

KLACK_ROOT="${KLACK_ROOT:?KLACK_ROOT not set}"
KLACK_SESSION="${KLACK_SESSION:-der-klack}"
SCRIPTS="$KLACK_ROOT/.klack/scripts/hauptturm"

TARGET="${1:?layout name required}"

# Export so all child processes inherit
export KLACK_ROOT KLACK_SESSION

# Set tmux to use zsh as default shell for new panes
tmux set-option -t "$KLACK_SESSION" default-shell "/bin/zsh" 2>/dev/null || true

# Pane command prefix: sets env vars, runs script in login zsh
PANE_CMD="export KLACK_ROOT='$KLACK_ROOT' KLACK_SESSION='$KLACK_SESSION';"

# Focus the pane running claude-pane.sh (the main interaction pane)
focus_claude_pane() {
  local pane_id
  pane_id="$(tmux list-panes -t "$KLACK_SESSION:hauptturm" -F '#{pane_index} #{pane_start_command}' 2>/dev/null \
    | grep 'claude-pane' | head -1 | awk '{print $1}')" || true
  if [[ -n "$pane_id" ]]; then
    tmux select-pane -t "$KLACK_SESSION:hauptturm.${pane_id}"
  fi
}

# Kill all panes except pane 0 in hauptturm window
kill_extra_panes() {
  local count
  count="$(tmux list-panes -t "$KLACK_SESSION:hauptturm" 2>/dev/null | wc -l | tr -d ' ')"
  while [[ "$count" -gt 1 ]]; do
    tmux kill-pane -t "$KLACK_SESSION:hauptturm.1" 2>/dev/null || break
    count=$((count - 1))
  done
}

# Get terminal dimensions
COLS="$(tmux display-message -t "$KLACK_SESSION:hauptturm" -p '#{window_width}' 2>/dev/null || echo 120)"

layout_hybrid() {
  # 4 panes: header(top,1line) | log(center-left) + status(center-right) | input(bottom,1line)
  kill_extra_panes

  # Pane 0 becomes header
  tmux send-keys -t "$KLACK_SESSION:hauptturm.0" C-c 2>/dev/null || true
  tmux respawn-pane -t "$KLACK_SESSION:hauptturm.0" -k "$PANE_CMD bash $SCRIPTS/header.sh" 2>/dev/null

  # Split bottom for input (1 line)
  tmux split-window -v -p 60 -t "$KLACK_SESSION:hauptturm.0" "$PANE_CMD bash $SCRIPTS/claude-pane.sh"

  # Split header pane to create log+status area
  tmux split-window -v -t "$KLACK_SESSION:hauptturm.0" "$PANE_CMD bash $SCRIPTS/log.sh"

  # Split log pane horizontally for status (right 25%)
  tmux split-window -h -p 25 -t "$KLACK_SESSION:hauptturm.1" "$PANE_CMD bash $SCRIPTS/status.sh"

  # Resize header to 1 line
  tmux resize-pane -t "$KLACK_SESSION:hauptturm.0" -y 1

  focus_claude_pane
}

layout_fullchat() {
  # 3 panes: header(compressed,1line) | log(full width) | input(1line)
  kill_extra_panes

  tmux send-keys -t "$KLACK_SESSION:hauptturm.0" C-c 2>/dev/null || true
  tmux respawn-pane -t "$KLACK_SESSION:hauptturm.0" -k "$PANE_CMD bash $SCRIPTS/header.sh" 2>/dev/null

  tmux split-window -v -p 60 -t "$KLACK_SESSION:hauptturm.0" "$PANE_CMD bash $SCRIPTS/claude-pane.sh"
  tmux split-window -v -t "$KLACK_SESSION:hauptturm.0" "$PANE_CMD bash $SCRIPTS/log.sh"

  tmux resize-pane -t "$KLACK_SESSION:hauptturm.0" -y 1
  focus_claude_pane
}

layout_twocol() {
  # 4 panes: header | log(left) + status(right) | input
  if [[ "$COLS" -lt 160 ]]; then
    echo "$(date +%H:%M:%S)  [KLACK]  WARNING: Terminal width $COLS < 160. twocol works best at 160+. Try: layout fullchat" >> "$KLACK_ROOT/.klack/activity.log"
  fi

  kill_extra_panes

  tmux send-keys -t "$KLACK_SESSION:hauptturm.0" C-c 2>/dev/null || true
  tmux respawn-pane -t "$KLACK_SESSION:hauptturm.0" -k "$PANE_CMD bash $SCRIPTS/header.sh" 2>/dev/null

  tmux split-window -v -p 60 -t "$KLACK_SESSION:hauptturm.0" "$PANE_CMD bash $SCRIPTS/claude-pane.sh"
  tmux split-window -v -t "$KLACK_SESSION:hauptturm.0" "$PANE_CMD bash $SCRIPTS/log.sh"

  # Status on the right (35%)
  tmux split-window -h -p 35 -t "$KLACK_SESSION:hauptturm.1" "$PANE_CMD bash $SCRIPTS/status.sh"

  tmux resize-pane -t "$KLACK_SESSION:hauptturm.0" -y 1
  focus_claude_pane
}

layout_threezone() {
  # 4 panes: header | status(band) | log | input
  kill_extra_panes

  tmux send-keys -t "$KLACK_SESSION:hauptturm.0" C-c 2>/dev/null || true
  tmux respawn-pane -t "$KLACK_SESSION:hauptturm.0" -k "$PANE_CMD bash $SCRIPTS/header.sh" 2>/dev/null

  tmux split-window -v -p 60 -t "$KLACK_SESSION:hauptturm.0" "$PANE_CMD bash $SCRIPTS/claude-pane.sh"
  tmux split-window -v -t "$KLACK_SESSION:hauptturm.0" "$PANE_CMD bash $SCRIPTS/status.sh"
  tmux split-window -v -t "$KLACK_SESSION:hauptturm.1" "$PANE_CMD bash $SCRIPTS/log.sh"

  tmux resize-pane -t "$KLACK_SESSION:hauptturm.0" -y 1
  # Status band gets ~25% of remaining space
  tmux resize-pane -t "$KLACK_SESSION:hauptturm.1" -y 6

  focus_claude_pane
}

layout_worktree() {
  # hybrid + sidebar: header(top) | log+status(center) | claude(bottom) | sidebar(far right)
  kill_extra_panes

  # Pane 0 becomes header
  tmux send-keys -t "$KLACK_SESSION:hauptturm.0" C-c 2>/dev/null || true
  tmux respawn-pane -t "$KLACK_SESSION:hauptturm.0" -k "$PANE_CMD bash $SCRIPTS/header.sh" 2>/dev/null

  # Split bottom for claude pane (main interaction)
  tmux split-window -v -p 60 -t "$KLACK_SESSION:hauptturm.0" "$PANE_CMD bash $SCRIPTS/claude-pane.sh"

  # Split header area to create log+status zone
  tmux split-window -v -t "$KLACK_SESSION:hauptturm.0" "$PANE_CMD bash $SCRIPTS/log.sh"

  # Split log pane horizontally for status (right 25%)
  tmux split-window -h -p 25 -t "$KLACK_SESSION:hauptturm.1" "$PANE_CMD bash $SCRIPTS/status.sh"

  # Resize header to 1 line
  tmux resize-pane -t "$KLACK_SESSION:hauptturm.0" -y 1

  # Add worktree sidebar on the far right (split the whole window)
  tmux split-window -h -p 20 -t "$KLACK_SESSION:hauptturm.4" "$PANE_CMD bash $SCRIPTS/sidebar.sh"

  focus_claude_pane
}

layout_dashboard() {
  # N+3 panes: header + 1 per ticket + log(compact) + input
  kill_extra_panes

  tmux send-keys -t "$KLACK_SESSION:hauptturm.0" C-c 2>/dev/null || true
  tmux respawn-pane -t "$KLACK_SESSION:hauptturm.0" -k "$PANE_CMD bash $SCRIPTS/header.sh" 2>/dev/null

  tmux split-window -v -p 60 -t "$KLACK_SESSION:hauptturm.0" "$PANE_CMD bash $SCRIPTS/claude-pane.sh"
  tmux split-window -v -t "$KLACK_SESSION:hauptturm.0" "$PANE_CMD bash $SCRIPTS/log.sh"

  tmux resize-pane -t "$KLACK_SESSION:hauptturm.0" -y 1
  # Log gets only 5 lines in dashboard mode
  tmux resize-pane -t "$KLACK_SESSION:hauptturm.1" -y 5

  # Add one pane per ticket above the log
  local idx=0
  for sig_dir in "$KLACK_ROOT"/.klack/signale/*/; do
    [[ -d "$sig_dir" ]] || continue
    local ticket
    ticket="$(basename "$sig_dir")"
    tmux split-window -v -b -t "$KLACK_SESSION:hauptturm.1" \
      "$PANE_CMD bash $SCRIPTS/ticket-status.sh $ticket $idx" 2>/dev/null || true
    idx=$((idx + 1))
  done

  focus_claude_pane
}

# Execute layout
case "$TARGET" in
  hybrid)     layout_hybrid ;;
  fullchat)   layout_fullchat ;;
  twocol)     layout_twocol ;;
  threezone)  layout_threezone ;;
  worktree)   layout_worktree ;;
  dashboard)  layout_dashboard ;;
  *)
    echo "ERROR: Unknown layout '$TARGET'" >&2
    exit 1
    ;;
esac
