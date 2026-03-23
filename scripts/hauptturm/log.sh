#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# log.sh — Activity Log Pane
# Color-coded scrolling log with ticket colors and event highlighting
# ============================================================================

KLACK_ROOT="${KLACK_ROOT:?KLACK_ROOT not set}"
source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"

trap 'source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"' USR1

LOG_FILE="$KLACK_ROOT/.klack/activity.log"
touch "$LOG_FILE"

# Build ticket color map
declare -A TCLR
idx=0
for sig_dir in "$KLACK_ROOT"/.klack/signale/*/; do
  [[ -d "$sig_dir" ]] || continue
  ticket="$(basename "$sig_dir")"
  TCLR["$ticket"]="${TICKET_COLORS[$((idx % ${#TICKET_COLORS[@]}))]}"
  idx=$((idx + 1))
done

colorize() {
  local line="$1"

  # Format: HH:MM:SS  [TICKET]  message
  if [[ "$line" =~ ^([0-9]{2}:[0-9]{2}:[0-9]{2})[[:space:]]+\[([A-Za-z0-9_>-]+)\][[:space:]]+(.*) ]]; then
    local ts="${BASH_REMATCH[1]}"
    local src="${BASH_REMATCH[2]}"
    local msg="${BASH_REMATCH[3]}"
    local clr="${TCLR[$src]:-$CLR_WHITE}"

    # User command echo
    if [[ "$src" == ">" ]]; then
      printf "${CLR_BOLD}${CLR_WHITE}  ${ts}  ❯ ${msg}${CLR_RST}\n"
      return
    fi

    # System message
    if [[ "$src" == "KLACK" ]]; then
      printf "${CLR_MUTE}  ${ts}  ${CLR_ACCENT}⚡${CLR_RST} ${CLR_MUTE}${msg}${CLR_RST}\n"
      return
    fi

    # Error
    if [[ "$msg" == *"FEHLER"* ]] || [[ "$msg" == *"ERROR"* ]] || [[ "$msg" == *"failed"* ]]; then
      printf "${CLR_MUTE}  ${ts}${CLR_RST}  ${CLR_ERR}[${src}]${CLR_RST} ${CLR_ERR}${msg}${CLR_RST}\n"
      return
    fi

    # Completion
    if [[ "$msg" == *"complete"* ]] || [[ "$msg" == *"DONE"* ]] || [[ "$msg" == *"${SYM_DONE}"* ]]; then
      printf "${CLR_MUTE}  ${ts}${CLR_RST}  ${clr}${CLR_BOLD}[${src}]${CLR_RST} ${CLR_DONE}${SYM_DONE} ${msg}${CLR_RST}\n"
      return
    fi

    # Waiting
    if [[ "$msg" == *"Waiting"* ]] || [[ "$msg" == *"warte"* ]]; then
      printf "${CLR_MUTE}  ${ts}${CLR_RST}  ${CLR_WAIT}[${src}] ${SYM_WAIT} ${msg}${CLR_RST}\n"
      return
    fi

    # MCP info
    if [[ "$msg" == "MCP:"* ]]; then
      printf "${CLR_MUTE}  ${ts}${CLR_RST}  ${CLR_ACCENT}[${src}]${CLR_RST} ${CLR_MUTE}${msg}${CLR_RST}\n"
      return
    fi

    # Default
    printf "${CLR_MUTE}  ${ts}${CLR_RST}  ${clr}[${src}]${CLR_RST} ${msg}\n"
  else
    printf "${CLR_MUTE}  %s${CLR_RST}\n" "$line"
  fi
}

# Show existing log
while IFS= read -r line; do
  colorize "$line"
done < "$LOG_FILE"

# Follow new entries
tail -f "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
  colorize "$line"
done
