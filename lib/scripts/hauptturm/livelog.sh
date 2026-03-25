#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# livelog.sh — Live detail log for active ticket
# Shows: status line, live tmux pane capture from ticket window,
# questions, errors. Switch ticket via .klack/active_ticket.
# ============================================================================

KLACK_ROOT="${KLACK_ROOT:?KLACK_ROOT not set}"
KLACK_SESSION="${KLACK_SESSION:-der-klack}"
source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"
trap 'source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"' USR1

ACTIVE_TICKET_FILE="$KLACK_ROOT/.klack/active_ticket"

get_active_ticket() {
  if [[ -f "$ACTIVE_TICKET_FILE" ]]; then
    cat "$ACTIVE_TICKET_FILE" | tr -d ' \n'
    return
  fi
  for d in "$KLACK_ROOT"/.klack/signale/*/; do
    [[ -d "$d" ]] && basename "$d" && return
  done
  echo ""
}

while true; do
  tput cup 0 0 2>/dev/null || true
  cols="$(tput cols 2>/dev/null || echo 40)"
  rows="$(tput lines 2>/dev/null || echo 30)"
  now="$(date +%H:%M:%S)"
  ticket="$(get_active_ticket)"

  if [[ -z "$ticket" ]]; then
    printf "${CLR_MUTE}Kein aktives Ticket${CLR_RST}"; tput el 2>/dev/null || true; printf "\n"
    tput ed 2>/dev/null || true
    sleep 3
    continue
  fi

  sig="$KLACK_ROOT/.klack/signale/$ticket"

  # --- Title + Status (2 lines) ---
  printf "${CLR_ACCENT}${CLR_BOLD}${ticket}${CLR_RST} ${CLR_MUTE}${now}${CLR_RST}"; tput el 2>/dev/null || true; printf "\n"

  if [[ -f "$sig/status.json" ]]; then
    step="$(python3 -c "import json; print(json.load(open('$sig/status.json'))['step'])" 2>/dev/null || echo "?")"
    status="$(python3 -c "import json; print(json.load(open('$sig/status.json'))['status'])" 2>/dev/null || echo "?")"

    case "$status" in
      running) printf "${CLR_RUN}${SYM_RUN} ${step}${CLR_RST}" ;;
      waiting) printf "${CLR_WAIT}${SYM_WAIT} ${step} WAITING${CLR_RST}" ;;
      done)    printf "${CLR_DONE}${SYM_DONE} ${step}${CLR_RST}" ;;
      error)   printf "${CLR_ERR}${SYM_ERR} ${step} ERROR${CLR_RST}" ;;
      *)       printf "${CLR_MUTE}${step} ${status}${CLR_RST}" ;;
    esac
    tput el 2>/dev/null || true; printf "\n"
  fi

  printf "${CLR_MUTE}$(printf '─%.0s' $(seq 1 "$cols"))${CLR_RST}"; tput el 2>/dev/null || true; printf "\n"

  # --- Question (if waiting) ---
  if [[ -f "$sig/waiting.flag" && -f "$sig/question.txt" ]]; then
    printf "${CLR_WAIT}${CLR_BOLD}FRAGE${CLR_RST}"; tput el 2>/dev/null || true; printf "\n"
    head -3 "$sig/question.txt" 2>/dev/null | while IFS= read -r line; do
      printf "${CLR_WAIT}%s${CLR_RST}" "$line"; tput el 2>/dev/null || true; printf "\n"
    done
    printf "${CLR_MUTE}$(printf '─%.0s' $(seq 1 "$cols"))${CLR_RST}"; tput el 2>/dev/null || true; printf "\n"
  fi

  # --- Live pane capture from ticket tmux window ---
  # Reserve lines: title(1) + status(1) + separator(1) + question(~5) + errors(~5) + separator(1)
  used_lines=4
  [[ -f "$sig/waiting.flag" ]] && used_lines=$((used_lines + 5))
  [[ -f "$sig/error.log" && -s "$sig/error.log" ]] && used_lines=$((used_lines + 5))
  capture_lines=$((rows - used_lines - 2))
  [[ $capture_lines -lt 5 ]] && capture_lines=5

  if tmux has-session -t "$KLACK_SESSION" 2>/dev/null && \
     tmux list-windows -t "$KLACK_SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "$ticket"; then
    # Capture live output from ticket's tmux window
    pane_output="$(tmux capture-pane -t "$KLACK_SESSION:${ticket}" -p -S -${capture_lines} 2>/dev/null || echo "")"

    if [[ -n "$pane_output" ]]; then
      printf "${CLR_MUTE}LIVE OUTPUT${CLR_RST}"; tput el 2>/dev/null || true; printf "\n"
      echo "$pane_output" | tail -${capture_lines} | while IFS= read -r line; do
        # Truncate to pane width
        printf "%.${cols}s" "$line"; tput el 2>/dev/null || true; printf "\n"
      done
    else
      printf "${CLR_MUTE}(kein Output)${CLR_RST}"; tput el 2>/dev/null || true; printf "\n"
    fi
  else
    # No tmux window — fall back to activity log
    printf "${CLR_MUTE}ACTIVITY${CLR_RST}"; tput el 2>/dev/null || true; printf "\n"
    if [[ -f "$KLACK_ROOT/.klack/activity.log" ]]; then
      grep "\[$ticket\]" "$KLACK_ROOT/.klack/activity.log" 2>/dev/null | tail -${capture_lines} | while IFS= read -r line; do
        printf "${CLR_MUTE}%.${cols}s${CLR_RST}" "$line"; tput el 2>/dev/null || true; printf "\n"
      done
    fi
  fi

  # --- Errors ---
  if [[ -f "$sig/error.log" && -s "$sig/error.log" ]]; then
    printf "${CLR_MUTE}$(printf '─%.0s' $(seq 1 "$cols"))${CLR_RST}"; tput el 2>/dev/null || true; printf "\n"
    printf "${CLR_ERR}${CLR_BOLD}ERRORS${CLR_RST}"; tput el 2>/dev/null || true; printf "\n"
    tail -3 "$sig/error.log" 2>/dev/null | while IFS= read -r line; do
      printf "${CLR_ERR}%.${cols}s${CLR_RST}" "$line"; tput el 2>/dev/null || true; printf "\n"
    done
  fi

  tput ed 2>/dev/null || true
  sleep 2
done
