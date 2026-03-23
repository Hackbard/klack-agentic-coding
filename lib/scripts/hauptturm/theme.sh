#!/usr/bin/env bash
# ============================================================================
# theme.sh — Color and symbol constants, sourced by all pane scripts
# ============================================================================

KLACK_ROOT="${KLACK_ROOT:?KLACK_ROOT not set}"
ACTIVE_THEME_FILE="$KLACK_ROOT/.klack/active_theme"

# Read active theme (default: unicorn)
ACTIVE_THEME="$(cat "$ACTIVE_THEME_FILE" 2>/dev/null || echo "unicorn")"

# --- Semantic Colors (same across all schemes) -------------------------------

CLR_ERR="\e[1;31m"      # Bold red — errors only
CLR_WAIT="\e[1;33m"     # Bold yellow — question blocks
CLR_DONE="\e[32m"       # Green — completion
CLR_MUTE="\e[90m"       # Dark grey — timestamps, labels
CLR_RST="\e[0m"         # Reset
CLR_BOLD="\e[1m"        # Bold
CLR_WHITE="\e[37m"      # White

# --- Symbols -----------------------------------------------------------------

SYM_DONE="✓"
SYM_RUN="▶"
SYM_WAIT="?"
SYM_ERR="✗"
SYM_PEND="·"
SYM_ARROW="→"

# --- Ticket Color Spectrum (per scheme) --------------------------------------

# Ticket colors assigned by index (0-based, wraps around)
TICKET_COLORS=()

# Scheme-specific accent colors
CLR_RUN=""
CLR_ACCENT=""
CLR_BORDER_INACTIVE=""
CLR_BORDER_ACTIVE=""

case "$ACTIVE_THEME" in
  unicorn)
    TICKET_COLORS=(
      "\e[96m"          # Cyan
      "\e[95m"          # Magenta
      "\e[93m"          # Yellow
      "\e[92m"          # Green
      "\e[38;5;208m"    # Orange
      "\e[38;5;213m"    # Pink
    )
    CLR_RUN="\e[96m"
    CLR_ACCENT="\e[95m"
    CLR_BORDER_INACTIVE="colour240"
    CLR_BORDER_ACTIVE="colour51"
    ;;
  cylon)
    TICKET_COLORS=(
      "\e[1;31m"        # Bold red
      "\e[33m"          # Amber
      "\e[31m"          # Red
      "\e[1;33m"        # Bold amber
      "\e[91m"          # Bright red
      "\e[38;5;202m"    # Dark orange
    )
    CLR_RUN="\e[31m"
    CLR_ACCENT="\e[1;31m"
    CLR_BORDER_INACTIVE="colour52"
    CLR_BORDER_ACTIVE="colour196"
    ;;
  kitt)
    TICKET_COLORS=(
      "\e[38;5;214m"    # Amber
      "\e[38;5;220m"    # Gold
      "\e[38;5;196m"    # Red
      "\e[38;5;214m"    # Amber
      "\e[38;5;130m"    # Dark amber
      "\e[38;5;220m"    # Gold
    )
    CLR_RUN="\e[38;5;196m"
    CLR_ACCENT="\e[38;5;214m"
    CLR_BORDER_INACTIVE="colour130"
    CLR_BORDER_ACTIVE="colour214"
    ;;
  shufflepuck)
    TICKET_COLORS=(
      "\e[96m"          # Cyan neon
      "\e[95m"          # Magenta neon
      "\e[93m"          # Yellow neon
      "\e[92m"          # Green neon
      "\e[1;96m"        # Bright cyan
      "\e[1;95m"        # Bright magenta
    )
    CLR_RUN="\e[1;96m"
    CLR_ACCENT="\e[1;95m"
    CLR_BORDER_INACTIVE="colour240"
    CLR_BORDER_ACTIVE="colour51"
    ;;
  monochrome)
    TICKET_COLORS=(
      "\e[32m"          # Green
      "\e[32m"          # Green
      "\e[32m"          # Green
      "\e[32m"          # Green
      "\e[32m"          # Green
      "\e[32m"          # Green
    )
    CLR_RUN="\e[1;32m"
    CLR_ACCENT="\e[32m"
    CLR_BORDER_INACTIVE="colour238"
    CLR_BORDER_ACTIVE="colour46"
    ;;
esac

# Get ticket color by index (wraps around)
ticket_color() {
  local idx="$1"
  local len=${#TICKET_COLORS[@]}
  echo -e "${TICKET_COLORS[$((idx % len))]}"
}

# Get ticket color escape code by index
ticket_color_code() {
  local idx="$1"
  local len=${#TICKET_COLORS[@]}
  echo "${TICKET_COLORS[$((idx % len))]}"
}
