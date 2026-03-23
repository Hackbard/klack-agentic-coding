#!/usr/bin/env zsh
# Source full user environment
[[ -f ~/.zshrc ]] && source ~/.zshrc 2>/dev/null
[[ -f ~/.zprofile ]] && source ~/.zprofile 2>/dev/null

KLACK_ROOT="${KLACK_ROOT:?KLACK_ROOT not set}"

CMD_FILE="$KLACK_ROOT/.claude/commands/hauptturm.md"

if [[ ! -f "$CMD_FILE" ]]; then
  echo "ERROR: $CMD_FILE not found" >&2
  exit 1
fi

# Write system prompt to temp file (avoids shell escaping issues)
PROMPT_FILE="$(mktemp)"
cat "$CMD_FILE" > "$PROMPT_FILE"
echo "" >> "$PROMPT_FILE"
echo "---" >> "$PROMPT_FILE"
echo "KLACK_ROOT: $KLACK_ROOT" >> "$PROMPT_FILE"
echo "KLACK_SESSION: ${KLACK_SESSION:-der-klack}" >> "$PROMPT_FILE"

# Check if there's an auto-start command (e.g. from klack epic)
INIT_FILE="$KLACK_ROOT/.klack/epic-init.md"
if [[ -f "$INIT_FILE" ]]; then
  # Append init context to system prompt
  echo "" >> "$PROMPT_FILE"
  cat "$INIT_FILE" >> "$PROMPT_FILE"
  rm -f "$INIT_FILE"
fi

exec claude --dangerously-skip-permissions --chrome --system-prompt-file "$PROMPT_FILE"
