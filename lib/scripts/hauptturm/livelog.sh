#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# livelog.sh — Live detail log for active ticket
# Shows status, filtered activity, agent output, errors.
# Switch ticket via .klack/active_ticket file.
# ============================================================================

KLACK_ROOT="${KLACK_ROOT:?KLACK_ROOT not set}"
source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"
trap 'source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"' USR1

ACTIVE_TICKET_FILE="$KLACK_ROOT/.klack/active_ticket"

get_active_ticket() {
  # Read from file, or auto-detect first ticket
  if [[ -f "$ACTIVE_TICKET_FILE" ]]; then
    cat "$ACTIVE_TICKET_FILE" | tr -d ' \n'
    return
  fi
  # Auto-detect: first signale directory
  for d in "$KLACK_ROOT"/.klack/signale/*/; do
    [[ -d "$d" ]] && basename "$d" && return
  done
  echo ""
}

while true; do
  tput cup 0 0 2>/dev/null || true
  cols="$(tput cols 2>/dev/null || echo 40)"
  now="$(date +%H:%M:%S)"
  ticket="$(get_active_ticket)"

  if [[ -z "$ticket" ]]; then
    printf "${CLR_MUTE}Kein aktives Ticket${CLR_RST}\n"
    sleep 3
    continue
  fi

  sig="$KLACK_ROOT/.klack/signale/$ticket"

  # Title
  printf "${CLR_ACCENT}${CLR_BOLD}${ticket}${CLR_RST} ${CLR_MUTE}• LIVE LOG ${now}${CLR_RST}\n"
  printf "${CLR_MUTE}$(printf '─%.0s' $(seq 1 "$cols"))${CLR_RST}\n"

  # Status from status.json
  if [[ -f "$sig/status.json" ]]; then
    step="$(python3 -c "import json; print(json.load(open('$sig/status.json'))['step'])" 2>/dev/null || echo "?")"
    status="$(python3 -c "import json; print(json.load(open('$sig/status.json'))['status'])" 2>/dev/null || echo "?")"
    log_msg="$(python3 -c "import json; print(json.load(open('$sig/status.json'))['log'][:60])" 2>/dev/null || echo "")"

    case "$status" in
      running) printf " ${CLR_RUN}${SYM_RUN} ${step}${CLR_RST} running\n" ;;
      waiting) printf " ${CLR_WAIT}${SYM_WAIT} ${step}${CLR_RST} WAITING\n" ;;
      done)    printf " ${CLR_DONE}${SYM_DONE} ${step}${CLR_RST} done\n" ;;
      error)   printf " ${CLR_ERR}${SYM_ERR} ${step}${CLR_RST} ERROR\n" ;;
      *)       printf " ${CLR_MUTE}${step} ${status}${CLR_RST}\n" ;;
    esac
    [[ -n "$log_msg" ]] && printf " ${CLR_MUTE}${log_msg}${CLR_RST}\n"
  fi

  printf "${CLR_MUTE}$(printf '─%.0s' $(seq 1 "$cols"))${CLR_RST}\n"

  # Activity log filtered for this ticket
  printf " ${CLR_ACCENT}ACTIVITY${CLR_RST}\n"
  if [[ -f "$KLACK_ROOT/.klack/activity.log" ]]; then
    grep "\[$ticket\]" "$KLACK_ROOT/.klack/activity.log" 2>/dev/null | tail -15 | while IFS= read -r line; do
      printf " ${CLR_MUTE}%s${CLR_RST}\n" "$line"
    done
  else
    printf " ${CLR_MUTE}(keine Eintraege)${CLR_RST}\n"
  fi

  # Question if waiting
  if [[ -f "$sig/waiting.flag" && -f "$sig/question.txt" ]]; then
    printf "${CLR_MUTE}$(printf '─%.0s' $(seq 1 "$cols"))${CLR_RST}\n"
    printf " ${CLR_WAIT}${CLR_BOLD}FRAGE${CLR_RST}\n"
    head -5 "$sig/question.txt" 2>/dev/null | while IFS= read -r line; do
      printf " ${CLR_WAIT}%s${CLR_RST}\n" "$line"
    done
  fi

  # Errors if any
  if [[ -f "$sig/error.log" && -s "$sig/error.log" ]]; then
    printf "${CLR_MUTE}$(printf '─%.0s' $(seq 1 "$cols"))${CLR_RST}\n"
    printf " ${CLR_ERR}${CLR_BOLD}ERRORS${CLR_RST}\n"
    tail -5 "$sig/error.log" 2>/dev/null | while IFS= read -r line; do
      printf " ${CLR_ERR}%s${CLR_RST}\n" "$line"
    done
  fi

  # Clear any leftover lines from previous render
  tput ed 2>/dev/null || true

  sleep 2
done
