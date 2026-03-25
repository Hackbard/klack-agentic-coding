#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# sidebar.sh — Worktree Sidebar
# Lists all git worktrees with BMAD status from sprint-status.yaml
# Pure bash — zero tokens burned.
# ============================================================================

KLACK_ROOT="${KLACK_ROOT:?KLACK_ROOT not set}"
source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"

trap 'source "$KLACK_ROOT/.klack/scripts/hauptturm/theme.sh"' USR1

# Find sprint-status.yaml (search common locations)
find_sprint_status() {
  local candidates=(
    "$KLACK_ROOT/_bmad-output/implementation-artifacts/sprint-status.yaml"
    "$KLACK_ROOT/_bmad-output/sprint-status.yaml"
    "$KLACK_ROOT/sprint-status.yaml"
  )
  for f in "${candidates[@]}"; do
    [[ -f "$f" ]] && echo "$f" && return
  done
  echo ""
}

# Extract ticket key from branch name
# worktree-feat/E1-001-implement-happy-api → E1-001
# worktree-feat/IN-2262-story-slug → IN-2262
# 1-1-npm-packaging → 1-1
extract_ticket_key() {
  local branch="$1"
  # Strip worktree-{type}/ prefix
  local slug="${branch#worktree-*/}"
  slug="${slug#*/}"  # handle any prefix before /

  # Try patterns: E1-001, IN-2262, or BMAD-style 1-1
  if [[ "$slug" =~ ^([A-Z][A-Z0-9]*-[0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$slug" =~ ^([0-9]+-[0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

# Look up status from sprint-status.yaml by ticket key
lookup_status() {
  local key="$1"
  local status_file="$2"

  [[ -z "$status_file" || ! -f "$status_file" ]] && echo "" && return

  # Search for a line containing the key and extract the status value
  # Format in yaml: "  1-1-some-name: done" or "  E1-001-name: in-progress"
  local match
  match="$(grep -i "^\s*${key}[a-z0-9-]*:" "$status_file" 2>/dev/null | head -1 || echo "")"

  if [[ -n "$match" ]]; then
    echo "$match" | sed 's/.*:\s*//' | tr -d ' '
  else
    echo ""
  fi
}

# Color a status string
color_status() {
  local status="$1"
  case "$status" in
    done)           printf "${CLR_DONE}done${CLR_RST}" ;;
    in-progress)    printf "${CLR_RUN}in-progress${CLR_RST}" ;;
    review)         printf "\e[34mreview${CLR_RST}" ;;
    ready-for-dev)  printf "\e[36mready${CLR_RST}" ;;
    backlog)        printf "${CLR_MUTE}backlog${CLR_RST}" ;;
    error)          printf "${CLR_ERR}error${CLR_RST}" ;;
    "")             printf "${CLR_MUTE}unknown${CLR_RST}" ;;
    *)              printf "${CLR_MUTE}${status}${CLR_RST}" ;;
  esac
}

while true; do
  tput cup 0 0 2>/dev/null || true
  cols="$(tput cols 2>/dev/null || echo 35)"

  # Title
  printf "${CLR_ACCENT}${CLR_BOLD} WORKTREES${CLR_RST}"
  tput el 2>/dev/null || true
  printf "\n${CLR_MUTE}$(printf '─%.0s' $(seq 1 "$cols"))${CLR_RST}"
  tput el 2>/dev/null || true

  sprint_file="$(find_sprint_status)"
  line_count=2

  # Get worktrees
  if ! command -v git &>/dev/null || ! git rev-parse --git-dir &>/dev/null 2>&1; then
    printf "\n ${CLR_MUTE}No git repo${CLR_RST}"
    tput el 2>/dev/null || true
    tput ed 2>/dev/null || true
    sleep 5
    continue
  fi

  worktree_output="$(git worktree list --porcelain 2>/dev/null || echo "")"

  if [[ -z "$worktree_output" ]]; then
    printf "\n ${CLR_MUTE}No worktrees${CLR_RST}"
    tput el 2>/dev/null || true
    tput ed 2>/dev/null || true
    sleep 5
    continue
  fi

  # Parse worktree list
  current_path=""
  current_branch=""

  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+) ]]; then
      current_path="${BASH_REMATCH[1]}"
      current_branch=""
    elif [[ "$line" =~ ^branch\ refs/heads/(.+) ]]; then
      current_branch="${BASH_REMATCH[1]}"
    elif [[ -z "$line" && -n "$current_path" ]]; then
      # End of worktree entry — render it
      local_name="$(basename "$current_path")"
      display_branch="${current_branch:-$local_name}"

      # Truncate branch for display
      if [[ ${#display_branch} -gt $((cols - 14)) ]]; then
        display_branch="${display_branch:0:$((cols - 17))}..."
      fi

      # Look up status
      ticket_key="$(extract_ticket_key "$display_branch")"
      if [[ -z "$sprint_file" ]]; then
        status_text="no tracking"
      elif [[ -n "$ticket_key" ]]; then
        raw_status="$(lookup_status "$ticket_key" "$sprint_file")"
        status_text="$raw_status"
      else
        status_text=""
      fi

      # Render line
      printf "\n"
      if [[ "$current_path" == "$KLACK_ROOT" ]]; then
        printf " ${CLR_WHITE}${CLR_BOLD}%-$((cols - 2))s${CLR_RST}" "* main"
      else
        printf " %-$((cols - 14))s " "$display_branch"
        color_status "$status_text"
      fi
      tput el 2>/dev/null || true
      line_count=$((line_count + 1))

      current_path=""
      current_branch=""
    fi
  done <<< "$worktree_output"

  # Handle last entry (if no trailing empty line)
  if [[ -n "$current_path" ]]; then
    local_name="$(basename "$current_path")"
    display_branch="${current_branch:-$local_name}"
    if [[ ${#display_branch} -gt $((cols - 14)) ]]; then
      display_branch="${display_branch:0:$((cols - 17))}..."
    fi
    ticket_key="$(extract_ticket_key "$display_branch")"
    if [[ -z "$sprint_file" ]]; then
      status_text="no tracking"
    elif [[ -n "$ticket_key" ]]; then
      raw_status="$(lookup_status "$ticket_key" "$sprint_file")"
      status_text="$raw_status"
    else
      status_text=""
    fi
    printf "\n"
    if [[ "$current_path" == "$KLACK_ROOT" ]]; then
      printf " ${CLR_WHITE}${CLR_BOLD}%-$((cols - 2))s${CLR_RST}" "* main"
    else
      printf " %-$((cols - 14))s " "$display_branch"
      color_status "$status_text"
    fi
    tput el 2>/dev/null || true
  fi

  # Footer
  printf "\n${CLR_MUTE}$(printf '─%.0s' $(seq 1 "$cols"))${CLR_RST}"
  tput el 2>/dev/null || true

  if [[ -z "$sprint_file" ]]; then
    printf "\n ${CLR_MUTE}No sprint-status.yaml${CLR_RST}"
    tput el 2>/dev/null || true
  fi

  tput ed 2>/dev/null || true
  sleep 5
done
