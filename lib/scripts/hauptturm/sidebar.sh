#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# sidebar.sh — Worktree Sidebar (scrollable, auto-refresh)
# Lists all git worktrees with BMAD status. Pure bash, zero tokens.
# ============================================================================

KLACK_ROOT="${KLACK_ROOT:?KLACK_ROOT not set}"
source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"
trap 'source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"' USR1

# --- Helpers ----------------------------------------------------------------

find_sprint_status() {
  for f in \
    "$KLACK_ROOT/_bmad-output/implementation-artifacts/sprint-status.yaml" \
    "$KLACK_ROOT/_bmad-output/sprint-status.yaml" \
    "$KLACK_ROOT/sprint-status.yaml"; do
    [[ -f "$f" ]] && echo "$f" && return
  done
  echo ""
}

extract_ticket_key() {
  local branch="$1"
  local slug="${branch##*/}"
  if [[ "$slug" =~ ^([A-Z][A-Z0-9]*-[0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$slug" =~ ^([0-9]+-[0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

lookup_status() {
  local key="$1" file="$2"
  [[ -z "$file" || ! -f "$file" ]] && return
  local match
  match="$(grep -i "^\s*${key}[a-z0-9-]*:" "$file" 2>/dev/null | head -1)" || true
  [[ -n "$match" ]] && echo "$match" | sed 's/.*:\s*//' | tr -d ' '
}

status_icon() {
  case "${1:-}" in
    done)          printf "${CLR_DONE}${SYM_DONE}${CLR_RST}" ;;
    in-progress)   printf "${CLR_RUN}${SYM_RUN}${CLR_RST}" ;;
    review)        printf "\e[34m◉${CLR_RST}" ;;
    ready-for-dev) printf "\e[36m○${CLR_RST}" ;;
    backlog)       printf "${CLR_MUTE}·${CLR_RST}" ;;
    error)         printf "${CLR_ERR}${SYM_ERR}${CLR_RST}" ;;
    *)             printf "${CLR_MUTE}?${CLR_RST}" ;;
  esac
}

# --- Main Loop (outputs to stdout, tmux pane scrolls naturally) -------------

while true; do
  tput cup 0 0 2>/dev/null || true
  cols="$(tput cols 2>/dev/null || echo 35)"
  now="$(date +%H:%M:%S)"
  sprint_file="$(find_sprint_status)"

  # Title
  printf "${CLR_ACCENT}${CLR_BOLD} WORKTREES${CLR_RST}  ${CLR_MUTE}${now}${CLR_RST}\n"
  printf "${CLR_MUTE}$(printf '─%.0s' $(seq 1 "$cols"))${CLR_RST}\n"

  # Git check
  if ! git -C "$KLACK_ROOT" rev-parse --git-dir &>/dev/null 2>&1; then
    printf " ${CLR_MUTE}Kein Git-Repo${CLR_RST}\n"
    sleep 5
    continue
  fi

  # Parse worktrees
  current_path="" current_branch=""
  wt_output="$(git -C "$KLACK_ROOT" worktree list --porcelain 2>/dev/null)"

  if [[ -z "$wt_output" ]]; then
    printf " ${CLR_MUTE}Keine Worktrees${CLR_RST}\n"
    sleep 5
    continue
  fi

  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+) ]]; then
      current_path="${BASH_REMATCH[1]}"
      current_branch=""
    elif [[ "$line" =~ ^branch\ refs/heads/(.+) ]]; then
      current_branch="${BASH_REMATCH[1]}"
    elif [[ -z "$line" && -n "$current_path" ]]; then
      # Render this worktree
      if [[ "$current_path" == "$(git -C "$KLACK_ROOT" rev-parse --show-toplevel 2>/dev/null)" ]]; then
        printf " ${CLR_WHITE}${CLR_BOLD}★ ${current_branch:-main}${CLR_RST}\n"
      else
        display="${current_branch:-$(basename "$current_path")}"
        # Truncate
        max=$((cols - 5))
        [[ ${#display} -gt $max ]] && display="${display:0:$((max-3))}..."

        ticket_key="$(extract_ticket_key "$display")"
        if [[ -z "$sprint_file" ]]; then
          st="?"
        elif [[ -n "$ticket_key" ]]; then
          st="$(lookup_status "$ticket_key" "$sprint_file")"
          [[ -z "$st" ]] && st="?"
        else
          st="?"
        fi

        printf " $(status_icon "$st") ${display}\n"
      fi
      current_path="" current_branch=""
    fi
  done <<< "$wt_output"

  # Last entry
  if [[ -n "$current_path" ]]; then
    if [[ "$current_path" == "$(git -C "$KLACK_ROOT" rev-parse --show-toplevel 2>/dev/null)" ]]; then
      printf " ${CLR_WHITE}${CLR_BOLD}★ ${current_branch:-main}${CLR_RST}\n"
    else
      display="${current_branch:-$(basename "$current_path")}"
      max=$((cols - 5))
      [[ ${#display} -gt $max ]] && display="${display:0:$((max-3))}..."
      ticket_key="$(extract_ticket_key "$display")"
      if [[ -z "$sprint_file" ]]; then st="?"
      elif [[ -n "$ticket_key" ]]; then st="$(lookup_status "$ticket_key" "$sprint_file")"; [[ -z "$st" ]] && st="?"
      else st="?"; fi
      printf " $(status_icon "$st") ${display}\n"
    fi
  fi

  # Footer
  printf "${CLR_MUTE}$(printf '─%.0s' $(seq 1 "$cols"))${CLR_RST}"; tput el 2>/dev/null || true; printf "\n"
  if [[ -z "$sprint_file" ]]; then
    printf " ${CLR_MUTE}kein sprint-status.yaml${CLR_RST}"; tput el 2>/dev/null || true; printf "\n"
  fi
  printf " ${CLR_MUTE}aktualisiert ${now}${CLR_RST}"; tput el 2>/dev/null || true; printf "\n"

  # Clear any leftover lines from previous render
  tput ed 2>/dev/null || true

  sleep 5
done
