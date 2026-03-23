#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# status.sh — Ticket Status Cards
# Visual pipeline progress per ticket with theme colors
# ============================================================================

KLACK_ROOT="${KLACK_ROOT:?KLACK_ROOT not set}"
source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"

trap 'source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"' USR1

PHASES=(story dev qa review release pipeline)
PHASE_LABELS=("STORY" "DEV" "QA" "REVIEW" "RELEASE" "CI")

# Spinner frames for running state
SPINNERS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
spin_frame=0

render_phase_block() {
  local phase="$1"
  local current_step="$2"
  local current_status="$3"
  local label="$4"

  local phase_idx=-1 current_idx=-1
  for i in "${!PHASES[@]}"; do
    [[ "${PHASES[$i]}" == "$phase" ]] && phase_idx=$i
    [[ "${PHASES[$i]}" == "$current_step" ]] && current_idx=$i
  done

  if [[ "$current_status" == "done" && "$current_step" == "release" ]]; then
    printf "${CLR_DONE}[${SYM_DONE} %-7s]${CLR_RST}" "$label"
  elif [[ $phase_idx -lt $current_idx ]]; then
    printf "${CLR_DONE}[${SYM_DONE} %-7s]${CLR_RST}" "$label"
  elif [[ $phase_idx -eq $current_idx ]]; then
    case "$current_status" in
      running)
        local spin="${SPINNERS[$((spin_frame % ${#SPINNERS[@]}))]}"
        printf "${CLR_RUN}${CLR_BOLD}[${spin} %-7s]${CLR_RST}" "$label"
        ;;
      waiting) printf "${CLR_WAIT}${CLR_BOLD}[${SYM_WAIT} %-7s]${CLR_RST}" "$label" ;;
      error)   printf "${CLR_ERR}${CLR_BOLD}[${SYM_ERR} %-7s]${CLR_RST}" "$label" ;;
      done)    printf "${CLR_DONE}[${SYM_DONE} %-7s]${CLR_RST}" "$label" ;;
      *)       printf "${CLR_MUTE}[${SYM_PEND} %-7s]${CLR_RST}" "$label" ;;
    esac
  else
    printf "${CLR_MUTE}[${SYM_PEND} %-7s]${CLR_RST}" "$label"
  fi
}

while true; do
  tput cup 0 0 2>/dev/null || true

  idx=0
  found_any=false

  for sig_dir in "$KLACK_ROOT"/.klack/signale/*/; do
    [[ -d "$sig_dir" ]] || continue
    found_any=true
    ticket="$(basename "$sig_dir")"
    sf="$sig_dir/status.json"
    clr="${TICKET_COLORS[$((idx % ${#TICKET_COLORS[@]}))]}"

    if [[ -f "$sf" ]]; then
      step="$(python3 -c "import json; print(json.load(open('$sf'))['step'])" 2>/dev/null || echo "init")"
      status="$(python3 -c "import json; print(json.load(open('$sf'))['status'])" 2>/dev/null || echo "unknown")"
      log_msg="$(python3 -c "import json; print(json.load(open('$sf'))['log'][:50])" 2>/dev/null || echo "")"
    else
      step="init"; status="pending"; log_msg=""
    fi

    # Ticket header with colored border
    printf "\n"
    printf "  ${clr}${CLR_BOLD}┌─ %-10s${CLR_RST}" "$ticket"

    # Status indicator
    case "$status" in
      running) printf " ${CLR_RUN}${SPINNERS[$((spin_frame % ${#SPINNERS[@]}))]} running${CLR_RST}" ;;
      waiting) printf " ${CLR_WAIT}⚠ WAITING${CLR_RST}" ;;
      error)   printf " ${CLR_ERR}${SYM_ERR} ERROR${CLR_RST}" ;;
      done)    printf " ${CLR_DONE}${SYM_DONE} DONE${CLR_RST}" ;;
      *)       printf " ${CLR_MUTE}${SYM_PEND} pending${CLR_RST}" ;;
    esac
    tput el 2>/dev/null || true

    # Phase pipeline
    printf "\n  ${clr}│${CLR_RST}  "
    for p in "${!PHASES[@]}"; do
      render_phase_block "${PHASES[$p]}" "$step" "$status" "${PHASE_LABELS[$p]}"
    done
    tput el 2>/dev/null || true

    # Log message
    printf "\n  ${clr}│${CLR_RST}  ${CLR_MUTE}%s${CLR_RST}" "$log_msg"
    tput el 2>/dev/null || true

    # Question preview if waiting
    if [[ "$status" == "waiting" && -f "$sig_dir/question.txt" ]]; then
      q="$(head -1 "$sig_dir/question.txt" | cut -c1-60)"
      printf "\n  ${clr}│${CLR_RST}  ${CLR_WAIT}┌─ %s${CLR_RST}" "$q"
      tput el 2>/dev/null || true
    fi

    printf "\n  ${clr}${CLR_BOLD}└$( printf '─%.0s' {1..30} )${CLR_RST}"
    tput el 2>/dev/null || true

    idx=$((idx + 1))
  done

  if [[ "$found_any" == "false" ]]; then
    printf "\n  ${CLR_MUTE}Keine Tuerme aktiv${CLR_RST}"
    tput el 2>/dev/null || true
  fi

  # Clear remaining lines
  tput ed 2>/dev/null || true

  spin_frame=$((spin_frame + 1))
  sleep 2
done
