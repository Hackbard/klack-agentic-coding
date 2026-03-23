#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# ticket-status.sh — Single ticket detail card (used in dashboard mode)
# Arguments: <ticket-id> <color-index>
# ============================================================================

KLACK_ROOT="${KLACK_ROOT:?KLACK_ROOT not set}"
source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"

trap 'source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"' USR1

TICKET="${1:?ticket-id required}"
COLOR_IDX="${2:-0}"
PHASES=(story dev qa review release)

while true; do
  sf="$KLACK_ROOT/.klack/signale/$TICKET/status.json"
  clr="${TICKET_COLORS[$((COLOR_IDX % ${#TICKET_COLORS[@]}))]}"

  if [[ -f "$sf" ]]; then
    step="$(python3 -c "import json; print(json.load(open('$sf'))['step'])" 2>/dev/null || echo "init")"
    status="$(python3 -c "import json; print(json.load(open('$sf'))['status'])" 2>/dev/null || echo "unknown")"
    log_msg="$(python3 -c "import json; print(json.load(open('$sf'))['log'])" 2>/dev/null || echo "")"
  else
    step="init"; status="pending"; log_msg=""
  fi

  clear

  # Phase pipeline with labels
  for phase in "${PHASES[@]}"; do
    local_idx=-1; current_idx=-1
    for i in "${!PHASES[@]}"; do
      [[ "${PHASES[$i]}" == "$phase" ]] && local_idx=$i
      [[ "${PHASES[$i]}" == "$step" ]] && current_idx=$i
    done

    if [[ "$status" == "done" && "$step" == "release" ]]; then
      printf "${CLR_DONE}%s %s${CLR_RST}" "$SYM_DONE" "$phase"
    elif [[ $local_idx -lt $current_idx ]]; then
      printf "${CLR_DONE}%s %s${CLR_RST}" "$SYM_DONE" "$phase"
    elif [[ $local_idx -eq $current_idx ]]; then
      case "$status" in
        running) printf "${CLR_RUN}%s ${CLR_BOLD}%s${CLR_RST}" "$SYM_RUN" "${phase^^}" ;;
        waiting) printf "${CLR_WAIT}%s ${CLR_BOLD}%s${CLR_RST}" "$SYM_WAIT" "${phase^^}" ;;
        error)   printf "${CLR_ERR}%s ${CLR_BOLD}%s${CLR_RST}" "$SYM_ERR" "${phase^^}" ;;
        done)    printf "${CLR_DONE}%s %s${CLR_RST}" "$SYM_DONE" "$phase" ;;
        *)       printf "${CLR_MUTE}%s %s${CLR_RST}" "$SYM_PEND" "$phase" ;;
      esac
    else
      printf "${CLR_MUTE}%s %s${CLR_RST}" "$SYM_PEND" "$phase"
    fi

    [[ "$phase" != "release" ]] && printf " ${CLR_MUTE}${SYM_ARROW}${CLR_RST} "
  done
  printf "\n"

  # Status detail
  case "$status" in
    waiting)
      qf="$KLACK_ROOT/.klack/signale/$TICKET/question.txt"
      printf "${CLR_WAIT}⚠ WAITING FOR INPUT${CLR_RST}\n"
      [[ -f "$qf" ]] && printf "${CLR_WAIT}%s${CLR_RST}\n" "$(cat "$qf")"
      ;;
    error)
      printf "${CLR_ERR}%s %s${CLR_RST}\n" "$SYM_ERR" "$log_msg"
      ;;
    *)
      printf "%s\n" "$log_msg"
      ;;
  esac

  sleep 5
done
