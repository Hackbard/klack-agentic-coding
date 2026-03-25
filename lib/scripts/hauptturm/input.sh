#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# input.sh — Persistent input bar + command handler
# All developer interaction happens here
# ============================================================================

KLACK_ROOT="${KLACK_ROOT:?KLACK_ROOT not set}"
KLACK_SESSION="${KLACK_SESSION:-der-klack}"
source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"

trap 'source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"' USR1

log_activity() {
  local msg="$1"
  echo "$(date +%H:%M:%S)  [KLACK]  $msg" >> "$KLACK_ROOT/.klack/activity.log"
}

log_user() {
  local msg="$1"
  echo "$(date +%H:%M:%S)  [>]  $msg" >> "$KLACK_ROOT/.klack/activity.log"
}

cmd_answer() {
  local ticket="$1"; shift
  local text="$*"
  local sig="$KLACK_ROOT/.klack/signale/$ticket"

  if [[ ! -d "$sig" ]]; then
    log_activity "ERROR: Unknown ticket $ticket"
    return
  fi
  if [[ ! -f "$sig/waiting.flag" ]]; then
    log_activity "WARNING: $ticket is not waiting for an answer"
    return
  fi

  # Ruecksignal read order: delete flag first, then write answer
  rm -f "$sig/waiting.flag"
  echo "$text" > "$sig/answer.txt"
  log_activity "Answer delivered to $ticket"
}

cmd_add() {
  local ttype="$1"
  local ticket="$2"

  case "$ttype" in
    feat|fix|hot) ;;
    *)
      log_activity "ERROR: Invalid type '$ttype'. Allowed: feat, fix, hot"
      return
      ;;
  esac

  local sig="$KLACK_ROOT/.klack/signale/$ticket"
  mkdir -p "$sig"

  if [[ ! -f "$sig/status.json" ]]; then
    cat > "$sig/status.json" <<EOJSON
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
  [[ -f "$sig/error.log" ]] || touch "$sig/error.log"

  # Update session.json
  python3 -c "
import json
sf = '$KLACK_ROOT/.klack/session.json'
d = json.load(open(sf))
if '$ticket' not in d['tickets']:
    d['tickets'].append('$ticket')
    d['types']['$ticket'] = '$ttype'
    json.dump(d, open(sf, 'w'), indent=2)
" 2>/dev/null || true

  # Start Turmwaechter in new tmux window
  local turmwaechter="$KLACK_ROOT/.klack/scripts/ticket-run.sh"
  tmux new-window -t "$KLACK_SESSION" -n "$ticket" -c "$KLACK_ROOT" \
    "KLACK_ROOT='$KLACK_ROOT' ANTHROPIC_MODEL='${ANTHROPIC_MODEL:-}' CLAUDE_CODE_SUBAGENT_MODEL='${CLAUDE_CODE_SUBAGENT_MODEL:-}' KLACK_REVIEW_MODEL='${KLACK_REVIEW_MODEL:-}' '$turmwaechter' '$ticket' '$ttype'; exec bash" 2>/dev/null || true

  log_activity "Tower started for $ticket [$ttype]"
}

cmd_error() {
  local ticket="$1"
  local ef="$KLACK_ROOT/.klack/signale/$ticket/error.log"
  if [[ -f "$ef" && -s "$ef" ]]; then
    log_activity "--- error.log for $ticket ---"
    while IFS= read -r line; do
      echo "$(date +%H:%M:%S)  [$ticket]  $line" >> "$KLACK_ROOT/.klack/activity.log"
    done < "$ef"
    log_activity "--- end error.log ---"
  else
    log_activity "$ticket: no errors logged"
  fi
}

cmd_retry() {
  local ticket="$1"
  local sig="$KLACK_ROOT/.klack/signale/$ticket"
  local sf="$sig/status.json"

  if [[ ! -f "$sf" ]]; then
    log_activity "ERROR: Unknown ticket $ticket"
    return
  fi

  # Get type from session.json
  local ttype
  ttype="$(python3 -c "import json; print(json.load(open('$KLACK_ROOT/.klack/session.json'))['types']['$ticket'])" 2>/dev/null || echo "feat")"

  # Reset status to pending
  python3 -c "
import json
from datetime import datetime, timezone
d = json.load(open('$sf'))
d['status'] = 'pending'
d['log'] = 'Retrying from step: ' + d['step']
d['updated_at'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
json.dump(d, open('$sf', 'w'), indent=2)
" 2>/dev/null

  # Clear error log
  > "$sig/error.log"

  # Kill existing window if present, start fresh
  tmux kill-window -t "$KLACK_SESSION:$ticket" 2>/dev/null || true

  local turmwaechter="$KLACK_ROOT/.klack/scripts/ticket-run.sh"
  tmux new-window -t "$KLACK_SESSION" -n "$ticket" -c "$KLACK_ROOT" \
    "KLACK_ROOT='$KLACK_ROOT' ANTHROPIC_MODEL='${ANTHROPIC_MODEL:-}' CLAUDE_CODE_SUBAGENT_MODEL='${CLAUDE_CODE_SUBAGENT_MODEL:-}' KLACK_REVIEW_MODEL='${KLACK_REVIEW_MODEL:-}' '$turmwaechter' '$ticket' '$ttype'; exec bash" 2>/dev/null || true

  log_activity "Retrying $ticket"
}

cmd_abort() {
  local ticket="$1"
  local sf="$KLACK_ROOT/.klack/signale/$ticket/status.json"

  if [[ ! -f "$sf" ]]; then
    log_activity "ERROR: Unknown ticket $ticket"
    return
  fi

  tmux kill-window -t "$KLACK_SESSION:$ticket" 2>/dev/null || true

  python3 -c "
import json
from datetime import datetime, timezone
d = json.load(open('$sf'))
d['status'] = 'error'
d['log'] = 'Aborted by developer'
d['updated_at'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
json.dump(d, open('$sf', 'w'), indent=2)
" 2>/dev/null

  log_activity "Aborted $ticket"
}

cmd_watch() {
  local ticket="$1"
  local sig="$KLACK_ROOT/.klack/signale/$ticket"
  if [[ ! -d "$sig" ]]; then
    log_activity "ERROR: Unknown ticket $ticket"
    return
  fi
  echo "$ticket" > "$KLACK_ROOT/.klack/active_ticket"
  log_activity "Live log switched to $ticket"
}

cmd_theme() {
  local name="$1"
  case "$name" in
    unicorn|cylon|kitt|shufflepuck|monochrome)
      echo "$name" > "$KLACK_ROOT/.klack/active_theme"

      # Update tmux border colors
      source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"
      tmux set-option -t "$KLACK_SESSION" -g pane-border-style "fg=$CLR_BORDER_INACTIVE" 2>/dev/null || true
      tmux set-option -t "$KLACK_SESSION" -g pane-active-border-style "fg=$CLR_BORDER_ACTIVE" 2>/dev/null || true

      # Signal all pane scripts to reload theme
      for pid_file in "$KLACK_ROOT"/.klack/pane_pids_*; do
        [[ -f "$pid_file" ]] || continue
        kill -USR1 "$(cat "$pid_file")" 2>/dev/null || true
      done
      # Also broadcast SIGUSR1 to all bash children in our session
      tmux list-panes -t "$KLACK_SESSION:hauptturm" -F '#{pane_pid}' 2>/dev/null | while read -r pid; do
        kill -USR1 "$pid" 2>/dev/null || true
      done

      log_activity "Theme switched to $name"
      ;;
    *)
      log_activity "ERROR: Unknown theme '$name'. Options: unicorn, cylon, kitt, shufflepuck, monochrome"
      ;;
  esac
}

cmd_help() {
  log_activity "--- Command Reference ---"
  log_activity "  answer <ticket> \"text\"  — Answer a pending question"
  log_activity "  add <type> <ticket>     — Add new ticket (feat/fix/hot)"
  log_activity "  error <ticket>          — Show error log"
  log_activity "  retry <ticket>          — Retry from failed step"
  log_activity "  abort <ticket>          — Stop ticket processing"
  log_activity "  watch <ticket>          — Switch live log to ticket"
  log_activity "  theme <name>            — Switch colors (unicorn/cylon/kitt/shufflepuck/monochrome)"
  log_activity "  status                  — Force refresh"
  log_activity "  help                    — This message"
  log_activity "-------------------------"
}

# --- Main Input Loop ---------------------------------------------------------

while true; do
  printf "${CLR_BOLD}${CLR_WHITE}> ${CLR_RST}"
  if ! IFS= read -r input; then
    break
  fi

  # Empty input — do nothing
  [[ -z "${input// /}" ]] && continue

  log_user "$input"

  # Parse command
  # shellcheck disable=SC2086
  set -- $input
  verb="${1:-}"
  shift || true

  case "$verb" in
    answer)
      ticket="${1:-}"
      shift || true
      if [[ -z "$ticket" ]]; then
        log_activity "ERROR: Usage: answer <ticket-id> \"response\""
      else
        cmd_answer "$ticket" "$@"
      fi
      ;;
    add)
      ttype="${1:-}"
      ticket="${2:-}"
      if [[ -z "$ttype" || -z "$ticket" ]]; then
        log_activity "ERROR: Usage: add <type> <ticket-id>"
      else
        cmd_add "$ttype" "$ticket"
      fi
      ;;
    error)
      ticket="${1:-}"
      [[ -n "$ticket" ]] && cmd_error "$ticket" || log_activity "ERROR: Usage: error <ticket-id>"
      ;;
    retry)
      ticket="${1:-}"
      [[ -n "$ticket" ]] && cmd_retry "$ticket" || log_activity "ERROR: Usage: retry <ticket-id>"
      ;;
    abort)
      ticket="${1:-}"
      [[ -n "$ticket" ]] && cmd_abort "$ticket" || log_activity "ERROR: Usage: abort <ticket-id>"
      ;;
    watch)
      ticket="${1:-}"
      [[ -n "$ticket" ]] && cmd_watch "$ticket" || log_activity "ERROR: Usage: watch <ticket-id>"
      ;;
    theme)
      name="${1:-}"
      [[ -n "$name" ]] && cmd_theme "$name" || log_activity "ERROR: Usage: theme <name>"
      ;;
    status)
      log_activity "Status refresh triggered"
      ;;
    help)
      cmd_help
      ;;
    *)
      log_activity "ERROR: Unknown command '$verb'. Type 'help' for commands."
      ;;
  esac
done
