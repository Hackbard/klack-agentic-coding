#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# header.sh — Der Klack Header Pane
# Animated session header with theme-specific flair
# ============================================================================

KLACK_ROOT="${KLACK_ROOT:?KLACK_ROOT not set}"
source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"

trap 'source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"' USR1

# Animation state
frame=0
scanner_pos=0
scanner_dir=1

while true; do
  # Count tickets
  total=0; running=0; waiting=0; done_count=0; errors=0
  for sig_dir in "$KLACK_ROOT"/.klack/signale/*/; do
    [[ -d "$sig_dir" ]] || continue
    total=$((total + 1))
    sf="$sig_dir/status.json"
    [[ -f "$sf" ]] || continue
    st="$(python3 -c "import json; print(json.load(open('$sf'))['status'])" 2>/dev/null || echo "unknown")"
    case "$st" in
      running) running=$((running + 1)) ;;
      waiting) waiting=$((waiting + 1)) ;;
      done)    done_count=$((done_count + 1)) ;;
      error)   errors=$((errors + 1)) ;;
    esac
  done

  ts="$(date +%H:%M:%S)"
  cols="$(tput cols 2>/dev/null || echo 80)"

  # Build the border line based on theme
  border=""
  case "$ACTIVE_THEME" in
    unicorn)
      # Rainbow shimmer across the border
      rainbow_colors=("$CLR_RUN" "\e[95m" "\e[93m" "\e[92m" "\e[38;5;208m" "\e[38;5;213m")
      for ((i=0; i<cols; i++)); do
        cidx=$(( (i + frame) % ${#rainbow_colors[@]} ))
        border+="${rainbow_colors[$cidx]}━"
      done
      border+="$CLR_RST"
      ;;
    cylon)
      # Red scanner sweep
      for ((i=0; i<cols; i++)); do
        if [[ $i -eq $scanner_pos ]] || [[ $i -eq $((scanner_pos+1)) ]] || [[ $i -eq $((scanner_pos+2)) ]]; then
          border+="\e[1;31m█"
        else
          border+="\e[2;31m━"
        fi
      done
      border+="$CLR_RST"
      scanner_pos=$((scanner_pos + scanner_dir))
      if [[ $scanner_pos -ge $((cols - 3)) ]]; then scanner_dir=-1; fi
      if [[ $scanner_pos -le 0 ]]; then scanner_dir=1; fi
      ;;
    kitt)
      # Amber with red scanner block
      for ((i=0; i<cols; i++)); do
        if [[ $i -eq $scanner_pos ]]; then
          border+="\e[38;5;196m█"
        else
          border+="\e[38;5;130m═"
        fi
      done
      border+="$CLR_RST"
      scanner_pos=$((scanner_pos + scanner_dir))
      if [[ $scanner_pos -ge $((cols - 1)) ]]; then scanner_dir=-1; fi
      if [[ $scanner_pos -le 0 ]]; then scanner_dir=1; fi
      ;;
    shufflepuck)
      # Neon pulse
      neon_colors=("\e[96m" "\e[95m" "\e[93m" "\e[92m")
      pulse_idx=$(( frame % ${#neon_colors[@]} ))
      for ((i=0; i<cols; i++)); do
        cidx=$(( (i + pulse_idx) % ${#neon_colors[@]} ))
        border+="${neon_colors[$cidx]}━"
      done
      border+="$CLR_RST"
      ;;
    monochrome)
      border="\e[32m$(printf '━%.0s' $(seq 1 "$cols"))$CLR_RST"
      ;;
  esac

  # Title line
  title="${CLR_ACCENT}${CLR_BOLD} ⚡ DER KLACK${CLR_RST}"
  stats=""
  [[ $total -gt 0 ]] && stats+="  ${CLR_MUTE}│${CLR_RST}  ${CLR_WHITE}${total} Tuerme${CLR_RST}"
  [[ $running -gt 0 ]] && stats+="  ${CLR_RUN}${SYM_RUN} ${running}${CLR_RST}"
  [[ $waiting -gt 0 ]] && stats+="  ${CLR_WAIT}${SYM_WAIT} ${waiting}${CLR_RST}"
  [[ $done_count -gt 0 ]] && stats+="  ${CLR_DONE}${SYM_DONE} ${done_count}${CLR_RST}"
  [[ $errors -gt 0 ]] && stats+="  ${CLR_ERR}${SYM_ERR} ${errors}${CLR_RST}"

  theme_badge="${CLR_MUTE}[${ACTIVE_THEME}]${CLR_RST}"
  time_display="${CLR_MUTE}${ts}${CLR_RST}"

  # Render
  tput cup 0 0 2>/dev/null || true
  printf "\r${title}${stats}  ${time_display}  ${theme_badge}"
  tput el 2>/dev/null || true
  printf "\n"
  printf "${border}"
  tput el 2>/dev/null || true

  frame=$((frame + 1))
  sleep 1
done
