#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# ticket-run.sh — Turmwaechter
# Runs each BMAD-Method step as a fresh Claude process for a single ticket.
# Called by klack.sh inside a tmux window.
#
# Arguments: <ticket-id> <ticket-type>
# Env: KLACK_ROOT, ANTHROPIC_MODEL, KLACK_REVIEW_MODEL
# ============================================================================

if [[ $# -lt 2 ]]; then
  echo "ERROR: ticket-run.sh requires <ticket-id> <ticket-type>" >&2
  exit 1
fi

TICKET="$1"
TYPE="$2"
RUN_MODE="${3:-}"  # --review enables interactive review after each step
KLACK_DIR="${KLACK_ROOT:?KLACK_ROOT not set}/.klack/signale/$TICKET"
STEPS=(story dev qa review release pipeline)

# --- Helpers -----------------------------------------------------------------

update_status() {
  local step="$1"
  local status="$2"
  local log="${3:-}"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local mr_url worktree_path branch
  mr_url="$(python3 -c "import json,sys; d=json.load(open('$KLACK_DIR/status.json')); print(json.dumps(d.get('mr_url')))" 2>/dev/null || echo "null")"
  worktree_path="$(python3 -c "import json,sys; d=json.load(open('$KLACK_DIR/status.json')); print(json.dumps(d.get('worktree_path')))" 2>/dev/null || echo "null")"
  branch="$(python3 -c "import json,sys; d=json.load(open('$KLACK_DIR/status.json')); print(json.dumps(d.get('branch')))" 2>/dev/null || echo "null")"

  cat > "$KLACK_DIR/status.json" <<EOJSON
{
  "step": "$step",
  "status": "$status",
  "log": $(python3 -c "import json; print(json.dumps('$log'))" 2>/dev/null || echo "\"$log\""),
  "updated_at": "$now",
  "mr_url": $mr_url,
  "worktree_path": $worktree_path,
  "branch": $branch
}
EOJSON
}

log_activity() {
  local msg="$1"
  echo "$(date +%H:%M:%S)  [$TICKET]  $msg" >> "$KLACK_ROOT/.klack/activity.log"
}

notify_attention() {
  local title="$1"
  local body="$2"
  printf '\a'
  if command -v osascript &>/dev/null; then
    osascript -e "display notification \"$body\" with title \"$title\"" 2>/dev/null || true
  fi
  log_activity "ATTENTION: $body"
}

check_waiting() {
  if [[ -f "$KLACK_DIR/waiting.flag" ]]; then
    local question_preview
    question_preview="$(head -1 "$KLACK_DIR/question.txt" 2>/dev/null || echo "Input needed")"
    notify_attention "Klack — $TICKET" "$question_preview"
  fi
  while [[ -f "$KLACK_DIR/waiting.flag" ]]; do
    update_status "$current_step" "waiting" "Waiting for developer input"
    log_activity "Waiting for answer..."
    sleep 5
  done
  if [[ -f "$KLACK_DIR/answer.txt" ]]; then
    log_activity "Answer received. Continuing..."
    update_status "$current_step" "running" "Answer received, resuming"
  fi
}

ask_on_failure() {
  local step="$1"
  local exit_code="$2"
  local agent_log="$KLACK_DIR/agent-output.log"

  local last_output=""
  if [[ -f "$agent_log" ]]; then
    last_output="$(tail -20 "$agent_log")"
  fi

  cat > "$KLACK_DIR/question.txt" <<EOQUEST
Step '$step' ist fehlgeschlagen (exit code $exit_code).

Letzter Agent-Output:
$last_output

Optionen:
- "retry" → gleichen Step nochmal versuchen
- "skip"  → diesen Step ueberspringen, weiter mit naechstem
- "abort" → Pipeline fuer dieses Ticket beenden
EOQUEST

  update_status "$step" "waiting" "FEHLER in $step — warte auf Entscheidung"
  log_activity "FEHLER: $step exit $exit_code — warte auf Entscheidung"
  touch "$KLACK_DIR/waiting.flag"
  notify_attention "Klack — $TICKET" "Step '$step' fehlgeschlagen (exit $exit_code)"

  while [[ -f "$KLACK_DIR/waiting.flag" ]]; do
    sleep 5
  done

  decision="$(cat "$KLACK_DIR/answer.txt" 2>/dev/null | tr '[:upper:]' '[:lower:]' | xargs)"
  rm -f "$KLACK_DIR/answer.txt" "$KLACK_DIR/question.txt"
}

# --- MCP Config Discovery ----------------------------------------------------
# Merge all MCP configs (project + plugins + user) into one normalized file.
# --mcp-config requires {"mcpServers": {...}} format.

MCP_CONFIG_ARGS=()
MCP_MERGED="$KLACK_DIR/.mcp-merged.json"

python3 -c "
import json, os

merged = {}

# 1. Project .mcp.json
proj = '$KLACK_ROOT/.mcp.json'
if os.path.isfile(proj):
    d = json.load(open(proj))
    merged.update(d.get('mcpServers', d))

# 2. Plugin cache .mcp.json files
cache = os.path.expanduser('~/.claude/plugins/cache/claude-plugins-official')
if os.path.isdir(cache):
    for plugin in sorted(os.listdir(cache)):
        plugin_path = os.path.join(cache, plugin)
        if not os.path.isdir(plugin_path):
            continue
        versions = sorted(
            [v for v in os.listdir(plugin_path) if os.path.isdir(os.path.join(plugin_path, v))],
            key=lambda v: os.path.getmtime(os.path.join(plugin_path, v)),
            reverse=True
        )
        for v in versions:
            mcp_file = os.path.join(plugin_path, v, '.mcp.json')
            if os.path.isfile(mcp_file):
                d = json.load(open(mcp_file))
                merged.update(d.get('mcpServers', d))
                break

# 3. User-level .mcp.json
user_mcp = os.path.expanduser('~/.claude/.mcp.json')
if os.path.isfile(user_mcp):
    d = json.load(open(user_mcp))
    merged.update(d.get('mcpServers', d))

json.dump({'mcpServers': merged}, open('$MCP_MERGED', 'w'), indent=2)
print(str(len(merged)))
" 2>/dev/null

if [[ -f "$MCP_MERGED" ]]; then
  mcp_count="$(python3 -c "import json; print(len(json.load(open('$MCP_MERGED'))['mcpServers']))" 2>/dev/null || echo "?")"
  log_activity "MCP: $mcp_count servers loaded"
  MCP_CONFIG_ARGS+=("--mcp-config" "$MCP_MERGED")
fi

# --- Dependency Check ---------------------------------------------------------
# Wait until all tickets this ticket depends on are complete.
# Reads "Depends:" field from local ticket file or checks signale directories.

check_dependencies() {
  # Try local markdown ticket first
  local ticket_file="$KLACK_ROOT/.klack/tickets/$TICKET.md"
  local deps=""

  if [[ -f "$ticket_file" ]]; then
    deps="$(grep '^Depends:' "$ticket_file" 2>/dev/null | sed 's/^Depends:[[:space:]]*//' | tr ',' ' ')"
  fi

  # Try bmad story file (ticket_source: bmad)
  local bmad_story
  bmad_story="$(find "$KLACK_ROOT/_bmad-output/implementation-artifacts" \
    -name "${TICKET}-*.md" -type f 2>/dev/null | head -1)"
  if [[ -n "$bmad_story" ]]; then
    local bmad_deps
    bmad_deps="$(grep '^Depends:' "$bmad_story" 2>/dev/null | sed 's/^Depends:[[:space:]]*//' | tr ',' ' ' || true)"
    deps="$deps $bmad_deps"
  fi

  # Also check for a deps file that klack epic / klack plan might create
  local deps_file="$KLACK_DIR/depends.txt"
  if [[ -f "$deps_file" ]]; then
    deps="$deps $(cat "$deps_file" | tr ',' ' ')"
  fi

  # Clean up — remove empty entries
  deps="$(echo "$deps" | xargs)"
  [[ -z "$deps" ]] && return 0

  log_activity "Waiting for dependencies: $deps"
  update_status "init" "waiting" "Waiting for: $deps"

  for dep in $deps; do
    local dep_status_file="$KLACK_ROOT/.klack/signale/$dep/status.json"
    while true; do
      if [[ -f "$dep_status_file" ]]; then
        local dep_status
        dep_status="$(python3 -c "import json; d=json.load(open('$dep_status_file')); print(d['step'] + '/' + d['status'])" 2>/dev/null || echo "unknown")"
        if [[ "$dep_status" == "complete/done" ]]; then
          log_activity "Dependency $dep is done"
          break
        fi
      fi
      sleep 15
    done
  done

  log_activity "All dependencies satisfied"
}

check_dependencies

# --- Resume Detection ---------------------------------------------------------
# Check status.json to skip already-completed steps on restart

LAST_DONE_STEP=""
if [[ -f "$KLACK_DIR/status.json" ]]; then
  prev_step="$(python3 -c "import json; print(json.load(open('$KLACK_DIR/status.json'))['step'])" 2>/dev/null || echo "init")"
  prev_status="$(python3 -c "import json; print(json.load(open('$KLACK_DIR/status.json'))['status'])" 2>/dev/null || echo "pending")"
  if [[ "$prev_step" == "complete" && "$prev_status" == "done" ]]; then
    log_activity "Ticket already complete — nothing to do"
    echo "Ticket $TICKET already complete."
    exit 0
  elif [[ "$prev_status" == "done" ]]; then
    LAST_DONE_STEP="$prev_step"
    log_activity "Resuming after completed step: $LAST_DONE_STEP"
  elif [[ "$prev_status" == "running" || "$prev_status" == "error" ]]; then
    # Was mid-step or failed — restart FROM this step
    LAST_DONE_STEP="__resume_from_${prev_step}"
    log_activity "Resuming from interrupted step: $prev_step"
  fi
fi

# --- Step Execution ----------------------------------------------------------

skip_done=true
[[ -z "$LAST_DONE_STEP" ]] && skip_done=false

for current_step in "${STEPS[@]}"; do
  # Skip steps that were already completed
  if [[ "$skip_done" == "true" ]]; then
    if [[ "$LAST_DONE_STEP" == "$current_step" ]]; then
      log_activity "Skipping $current_step (already done)"
      skip_done=false  # Next step will run
      continue
    elif [[ "$LAST_DONE_STEP" == "__resume_from_${current_step}" ]]; then
      skip_done=false  # This step needs to re-run
    else
      log_activity "Skipping $current_step (already done)"
      continue
    fi
  fi

  cmd_file="$KLACK_ROOT/.claude/commands/ticket-${current_step}.md"

  if [[ ! -f "$cmd_file" ]]; then
    log_activity "Command file not found: $cmd_file — skipping step"
    continue
  fi

  # Retry loop per step
  while true; do
    update_status "$current_step" "running" "Starting $current_step..."
    log_activity "Starting $current_step..."

    step_model="$ANTHROPIC_MODEL"
    if [[ "$current_step" == "review" ]]; then
      step_model="${KLACK_REVIEW_MODEL:-$ANTHROPIC_MODEL}"
    fi

    protocol_file="$KLACK_ROOT/.claude/commands/klack-protocol.md"
    protocol=""
    if [[ -f "$protocol_file" ]]; then
      protocol="$(cat "$protocol_file")

---

"
    fi

    prompt="${protocol}$(cat "$cmd_file")

---
KLACK_TICKET: $TICKET
KLACK_TYPE: $TYPE
KLACK_DIR: $KLACK_DIR"

    agent_log="$KLACK_DIR/agent-output.log"

    # Run Claude autonomously — output tee'd to agent-output.log for livelog panel
    > "$agent_log"
    set +e
    ANTHROPIC_MODEL="$step_model" claude \
      --dangerously-skip-permissions \
      --chrome \
      "${MCP_CONFIG_ARGS[@]}" \
      -p "$prompt" 2>&1 | tee "$agent_log"
    claude_exit=${PIPESTATUS[0]}
    set -e

    if [[ $claude_exit -eq 0 ]]; then
      check_waiting
      update_status "$current_step" "done" "$current_step complete"
      log_activity "$current_step complete"

      # Interactive review — developer can chat with the agent's context
      if [[ "$RUN_MODE" == "--review" ]]; then
        # Clean up any previous resume file
        rm -f "$KLACK_DIR/resume.md"

        log_activity "$current_step done — interaktive Session (/klack-next fuer Uebergabe, /exit zum Weitermachen)"
        update_status "$current_step" "done" "Review — /klack-next oder /exit"
        set +e
        ANTHROPIC_MODEL="$step_model" claude \
          --dangerously-skip-permissions \
          --chrome \
          "${MCP_CONFIG_ARGS[@]}" \
          -c
        set -e

        notify_attention "Klack — $TICKET" "Interaktiver Step '$current_step' beendet. Entscheidung noetig."

        # Check if developer triggered /klack-next (resume.md exists)
        if [[ -f "$KLACK_DIR/resume.md" ]]; then
          log_activity "Developer hat /klack-next genutzt — autonome Weiterarbeit"
          update_status "$current_step" "done" "Autonome Weiterarbeit nach Review"

          resume_prompt="$(cat "$KLACK_DIR/resume.md")"
          rm -f "$KLACK_DIR/resume.md"

          # Continue autonomously with conversation context + resume instructions
          set +e
          ANTHROPIC_MODEL="$step_model" claude \
            --dangerously-skip-permissions \
            --chrome \
            "${MCP_CONFIG_ARGS[@]}" \
            -c \
            -p "Der Developer hat dir die Arbeit uebergeben. Hier ist sein Stand:

$resume_prompt

Arbeite autonom weiter. Melde Fortschritt via status.json log-Feld."
          auto_exit=$?
          set -e

          if [[ $auto_exit -ne 0 ]]; then
            log_activity "Autonome Weiterarbeit fehlgeschlagen (exit $auto_exit)"
            echo "Autonomous continuation failed with exit $auto_exit" >> "$KLACK_DIR/error.log"
            ask_on_failure "$current_step" "$auto_exit"
            case "$decision" in
              retry|nochmal) continue ;;
              skip|weiter)   break ;;
              *)             exit 1 ;;
            esac
          fi
          log_activity "Autonome Weiterarbeit abgeschlossen"
        else
          log_activity "Review-Session beendet, weiter zum naechsten Step"
        fi
      fi

      break
    else
      echo "$current_step failed with exit code $claude_exit" >> "$KLACK_DIR/error.log"

      ask_on_failure "$current_step" "$claude_exit"

      case "$decision" in
        retry|nochmal|wiederholen)
          log_activity "Developer sagt: retry $current_step"
          > "$KLACK_DIR/error.log"
          continue
          ;;
        skip|weiter|ueberspringen)
          log_activity "Developer sagt: skip $current_step"
          update_status "$current_step" "done" "$current_step SKIPPED by developer"
          break
          ;;
        *)
          log_activity "Developer sagt: abort"
          update_status "$current_step" "error" "Aborted by developer"
          exit 1
          ;;
      esac
    fi
  done
done

update_status "complete" "done" "All steps complete"
log_activity "All steps complete! Tower finished."
echo "Ticket $TICKET — all steps complete."
