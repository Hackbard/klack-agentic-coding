#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# klack.sh — Der Klack Entrypoint
# Autonomous multi-ticket development pipeline orchestrator
# ============================================================================

KLACK_SESSION="der-klack"
KLACK_ROOT="${KLACK_ROOT:-$(pwd)}"
export KLACK_ROOT

# --- Usage -------------------------------------------------------------------

usage() {
  cat >&2 <<'EOF'
Usage: klack <type> <ticket-id> [<type> <ticket-id> ...]
Types: feat, fix, hot
Suffix: +review after ticket-id for interactive review after each step

Examples:
  klack feat IN-2262                    # autonom (default)
  klack feat IN-2262+review             # review nach jedem Step
  klack feat IN-2262 fix IN-2200+review # mixed: IN-2262 autonom, IN-2200 mit review

Run without arguments to restore a previous session.
EOF
  exit 1
}

# --- Model Configuration (NFR7) ---------------------------------------------

export ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-claude-sonnet-4-6}"
export CLAUDE_CODE_SUBAGENT_MODEL="${CLAUDE_CODE_SUBAGENT_MODEL:-claude-haiku-4-5-20251001}"
export KLACK_REVIEW_MODEL="${KLACK_REVIEW_MODEL:-claude-opus-4-6}"

# --- Helpers -----------------------------------------------------------------

setup_tmux_session() {
  # Kill stale session if hauptturm window is missing
  if tmux has-session -t "$KLACK_SESSION" 2>/dev/null; then
    if ! tmux list-windows -t "$KLACK_SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "hauptturm"; then
      echo "Stale session detected (no hauptturm window) — recreating..."
      tmux kill-session -t "$KLACK_SESSION" 2>/dev/null
    else
      echo "Reusing existing session '$KLACK_SESSION'"
      return
    fi
  fi

  if ! tmux has-session -t "$KLACK_SESSION" 2>/dev/null; then
    tmux new-session -d -s "$KLACK_SESSION" -n "hauptturm" -c "$KLACK_ROOT"
    tmux set-option -t "$KLACK_SESSION" -g mouse on
    tmux set-option -t "$KLACK_SESSION" -g status off
    tmux set-option -t "$KLACK_SESSION" -g pane-border-style "fg=colour240"
    tmux set-option -t "$KLACK_SESSION" -g pane-active-border-style "fg=colour51"
    tmux set-option -t "$KLACK_SESSION" -g pane-border-lines heavy
    tmux set-option -t "$KLACK_SESSION" -g pane-border-format "#{pane_title}"
    tmux set-option -t "$KLACK_SESSION" default-shell "$SHELL"

    # Bind Ctrl-b w to workflow picker popup
    local picker="$KLACK_ROOT/.klack/scripts/hauptturm/workflow-picker.sh"
    tmux bind-key -T prefix w display-popup -E -w 45 -h 30 \
      "export KLACK_ROOT='$KLACK_ROOT' KLACK_SESSION='$KLACK_SESSION'; bash '$picker'"
  fi
}

init_hauptturm() {
  # Initialize default layout (hybrid) in the hauptturm window
  local layout_script="$KLACK_ROOT/.klack/scripts/hauptturm/layout.sh"
  if [[ -x "$layout_script" ]]; then
    KLACK_ROOT="$KLACK_ROOT" KLACK_SESSION="$KLACK_SESSION" "$layout_script" 2>/dev/null || true
  fi
}

init_signale() {
  local ticket="$1"
  local sig_dir="$KLACK_ROOT/.klack/signale/$ticket"
  mkdir -p "$sig_dir"
  if [[ ! -f "$sig_dir/status.json" ]]; then
    cat > "$sig_dir/status.json" <<EOJSON
{
  "step": "init",
  "status": "pending",
  "log": "",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "mr_url": null,
  "worktree_path": null,
  "branch": null
}
EOJSON
  fi
  [[ -f "$sig_dir/error.log" ]] || touch "$sig_dir/error.log"
}

start_turmwaechter() {
  local ticket="$1"
  local ttype="$2"
  local force_flag="${3:-}"
  local turmwaechter="$KLACK_ROOT/.klack/scripts/ticket-run.sh"

  if ! tmux list-windows -t "$KLACK_SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "$ticket"; then
    tmux new-window -t "$KLACK_SESSION" -n "$ticket" -c "$KLACK_ROOT" \
      "KLACK_ROOT='$KLACK_ROOT' ANTHROPIC_MODEL='$ANTHROPIC_MODEL' CLAUDE_CODE_SUBAGENT_MODEL='$CLAUDE_CODE_SUBAGENT_MODEL' KLACK_REVIEW_MODEL='$KLACK_REVIEW_MODEL' exec $SHELL -lc '$turmwaechter $ticket $ttype $force_flag; exec $SHELL'"
  fi
}

get_ticket_status() {
  local ticket="$1"
  local sf="$KLACK_ROOT/.klack/signale/$ticket/status.json"
  if [[ -f "$sf" ]]; then
    python3 -c "import json; print(json.load(open('$sf'))['status'])" 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

write_session_json() {
  python3 -c "
import json
from datetime import datetime, timezone
tickets = $(python3 -c "import json; print(json.dumps([t for t in '${KLACK_TICKETS[*]}'.split()]))")
types_list = '${KLACK_TYPES[*]}'.split()
types_map = dict(zip(tickets, types_list))
d = {
    'started_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'tickets': tickets,
    'types': types_map
}
json.dump(d, open('$KLACK_ROOT/.klack/session.json', 'w'), indent=2)
"
}

# --- Session Restore (Story 1.6) --------------------------------------------

if [[ $# -eq 0 ]]; then
  # No arguments — try to restore existing session or start fresh Hauptturm
  # If tmux session exists, just attach
  if tmux has-session -t "$KLACK_SESSION" 2>/dev/null; then
    echo "Attaching to existing session '$KLACK_SESSION'"
    exec tmux attach-session -t "$KLACK_SESSION"
  fi

  if [[ ! -f "$KLACK_ROOT/.klack/session.json" ]]; then
    # No session — start fresh Hauptturm (no tickets, just the workspace)
    setup_tmux_session
    init_hauptturm
    exec tmux attach-session -t "$KLACK_SESSION"
  fi

  # Read session.json and restore
  echo "Restoring session from .klack/session.json..."

  # Parse session.json
  eval "$(python3 -c "
import json
s = json.load(open('$KLACK_ROOT/.klack/session.json'))
tickets = s['tickets']
types = s['types']
print('KLACK_TICKETS=(' + ' '.join(tickets) + ')')
print('KLACK_TYPES=(' + ' '.join(types[t] for t in tickets) + ')')
")"

  setup_tmux_session
  touch "$KLACK_ROOT/.klack/activity.log"

  for i in "${!KLACK_TICKETS[@]}"; do
    ticket="${KLACK_TICKETS[$i]}"
    ttype="${KLACK_TYPES[$i]}"
    status="$(get_ticket_status "$ticket")"

    case "$status" in
      done|error)
        # Display in Hauptturm only — no window needed
        echo "  [$ticket] status: $status (no window)"
        ;;
      running|waiting|pending|unknown)
        # Recreate window and restart
        init_signale "$ticket"
        start_turmwaechter "$ticket" "$ttype" ""
        echo "  [$ticket] status: $status (window restored)"
        ;;
    esac
  done

  init_hauptturm
  tmux select-window -t "$KLACK_SESSION:hauptturm"
  echo "Der Klack — session restored with ${#KLACK_TICKETS[@]} ticket(s)"
  exec tmux attach-session -t "$KLACK_SESSION"
fi

# --- Argument Validation (new session) --------------------------------------

if [[ $(( $# % 2 )) -ne 0 ]]; then
  echo "ERROR: Arguments must be pairs of <type> <ticket-id>" >&2
  usage
fi

# --- Argument Parsing --------------------------------------------------------

KLACK_TYPES=()
KLACK_TICKETS=()
KLACK_MODES=()  # per-ticket: "" (autonom) or "--review"

while [[ $# -gt 0 ]]; do
  type="$1"
  ticket="$2"
  shift 2

  case "$type" in
    feat|fix|hot)
      ;;
    *)
      echo "ERROR: Invalid ticket type '$type'. Allowed: feat, fix, hot" >&2
      exit 1
      ;;
  esac

  if [[ -z "$ticket" ]]; then
    echo "ERROR: Empty ticket ID for type '$type'" >&2
    exit 1
  fi

  # Parse +review suffix
  mode=""
  if [[ "$ticket" == *"+review" ]]; then
    ticket="${ticket%+review}"
    mode="--review"
  fi

  KLACK_TYPES+=("$type")
  KLACK_TICKETS+=("$ticket")
  KLACK_MODES+=("$mode")
done

# --- New Session Setup -------------------------------------------------------

setup_tmux_session
touch "$KLACK_ROOT/.klack/activity.log"

for i in "${!KLACK_TICKETS[@]}"; do
  init_signale "${KLACK_TICKETS[$i]}"
done

write_session_json

for i in "${!KLACK_TICKETS[@]}"; do
  start_turmwaechter "${KLACK_TICKETS[$i]}" "${KLACK_TYPES[$i]}" "${KLACK_MODES[$i]}"
done

init_hauptturm
tmux select-window -t "$KLACK_SESSION:hauptturm"

echo "Der Klack — ${#KLACK_TICKETS[@]} ticket(s) loaded"
for i in "${!KLACK_TICKETS[@]}"; do
  echo "  [${KLACK_TYPES[$i]}] ${KLACK_TICKETS[$i]}"
done

exec tmux attach-session -t "$KLACK_SESSION"
