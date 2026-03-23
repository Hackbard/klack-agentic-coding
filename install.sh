#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# install.sh — Der Klack Installer
# Copies klack files into a target project directory.
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage: install.sh <target-project-path>
Installs Der Klack into the target project.
EOF
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

TARGET="$(cd "$1" && pwd)"

if [[ ! -d "$TARGET" ]]; then
  echo "ERROR: Target directory '$1' does not exist" >&2
  exit 1
fi

# --- Dependency Check --------------------------------------------------------

missing=()
for dep in tmux glab claude; do
  if ! command -v "$dep" &>/dev/null; then
    missing+=("$dep")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "ERROR: Missing required dependencies: ${missing[*]}" >&2
  echo "Please install them and ensure they are in your PATH." >&2
  exit 1
fi

# --- tmux Version Check -----------------------------------------------------

tmux_version="$(tmux -V | sed 's/tmux //')"
tmux_major="${tmux_version%%.*}"
tmux_minor="${tmux_version#*.}"
tmux_minor="${tmux_minor%%[a-z]*}"
if [[ "$tmux_major" -lt 3 ]] || { [[ "$tmux_major" -eq 3 ]] && [[ "$tmux_minor" -lt 2 ]]; }; then
  echo "WARNING: tmux $tmux_version detected. tmux 3.2+ recommended for pane border labels." >&2
fi

# --- Copy Commands -----------------------------------------------------------

echo "Installing Der Klack into $TARGET..."

mkdir -p "$TARGET/.claude/commands"
if ls "$SCRIPT_DIR"/commands/*.md &>/dev/null; then
  cp "$SCRIPT_DIR"/commands/*.md "$TARGET/.claude/commands/"
  echo "  Copied command files to .claude/commands/ (incl. klack-protocol.md)"
else
  echo "  WARNING: No command files found in $SCRIPT_DIR/commands/ (Epics 3-7 not yet implemented)"
fi

# --- Copy Scripts ------------------------------------------------------------

# Main entrypoint
cp "$SCRIPT_DIR/scripts/klack.sh" "$TARGET/klack.sh"
chmod +x "$TARGET/klack.sh"
echo "  Copied klack.sh (executable)"

# Turmwaechter
mkdir -p "$TARGET/.klack/scripts"
cp "$SCRIPT_DIR/scripts/ticket-run.sh" "$TARGET/.klack/scripts/ticket-run.sh"
chmod +x "$TARGET/.klack/scripts/ticket-run.sh"
echo "  Copied ticket-run.sh"

# Hauptturm pane scripts
if ls "$SCRIPT_DIR"/scripts/hauptturm/*.sh &>/dev/null; then
  mkdir -p "$TARGET/.klack/scripts/hauptturm"
  cp "$SCRIPT_DIR"/scripts/hauptturm/*.sh "$TARGET/.klack/scripts/hauptturm/"
  chmod +x "$TARGET"/.klack/scripts/hauptturm/*.sh
  echo "  Copied hauptturm/ pane scripts"
else
  echo "  WARNING: No hauptturm/ pane scripts found (Epic 2 not yet implemented)"
fi

# Klack skills
if [[ -d "$SCRIPT_DIR/.claude/skills/klack-next" ]]; then
  mkdir -p "$TARGET/.claude/skills/klack-next"
  cp "$SCRIPT_DIR/.claude/skills/klack-next/SKILL.md" "$TARGET/.claude/skills/klack-next/"
  echo "  Copied klack-next skill"
fi

# --- Update .gitignore -------------------------------------------------------

GITIGNORE="$TARGET/.gitignore"
ENTRIES=(
  ".klack/signale/"
  ".klack/session.json"
  ".klack/activity.log"
  ".klack/active_theme"
  ".klack/cmd.fifo"
)

touch "$GITIGNORE"
for entry in "${ENTRIES[@]}"; do
  if ! grep -qxF "$entry" "$GITIGNORE"; then
    echo "$entry" >> "$GITIGNORE"
  fi
done
echo "  Updated .gitignore"

# --- Done --------------------------------------------------------------------

echo ""
echo "Der Klack installed successfully!"
echo "Run: cd $TARGET && ./klack.sh feat TICKET-ID"
