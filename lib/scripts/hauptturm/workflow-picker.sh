#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# workflow-picker.sh — BMAD Workflow Launcher
# Called via tmux popup (Ctrl-b w). Lists workflows, starts them phase-aware.
# ============================================================================

KLACK_ROOT="${KLACK_ROOT:?KLACK_ROOT not set}"
KLACK_SESSION="${KLACK_SESSION:-der-klack}"

# --- Workflow Definitions ---------------------------------------------------
# Format: "number|phase|skill-name|display-name"

WORKFLOWS=(
  "1|1|bmad-create-product-brief|Product Brief"
  "2|1|bmad-create-prd|PRD erstellen"
  "3|1|bmad-market-research|Market Research"
  "4|1|bmad-domain-research|Domain Research"
  "5|2|bmad-create-ux-design|UX Design"
  "6|2|bmad-create-architecture|Architecture"
  "7|2|bmad-technical-research|Technical Research"
  "8|3|bmad-create-epics-and-stories|Epics & Stories"
  "9|3|bmad-sprint-planning|Sprint Planning"
  "10|3|bmad-create-story|Create Story"
  "11|4|bmad-dev-story|Dev Story"
  "12|4|bmad-qa-generate-e2e-tests|QA Tests"
  "13|4|bmad-code-review|Code Review"
  "14|4|bmad-check-implementation-readiness|Implementation Readiness"
)

# --- Display Menu -----------------------------------------------------------

clear
printf "\n"
printf "  \e[1;96m⚡ KLACK WORKFLOW LAUNCHER\e[0m\n"
printf "  \e[90m─────────────────────────────\e[0m\n\n"

printf "  \e[1;33mPhase 1 — Planung (interaktiv)\e[0m\n"
for w in "${WORKFLOWS[@]}"; do
  IFS='|' read -r num phase skill name <<< "$w"
  [[ "$phase" == "1" ]] && printf "    \e[97m%2s\e[0m  %s\n" "$num" "$name"
done

printf "\n  \e[1;33mPhase 2 — Design (interaktiv)\e[0m\n"
for w in "${WORKFLOWS[@]}"; do
  IFS='|' read -r num phase skill name <<< "$w"
  [[ "$phase" == "2" ]] && printf "    \e[97m%2s\e[0m  %s\n" "$num" "$name"
done

printf "\n  \e[1;33mPhase 3 — Sprint (interaktiv)\e[0m\n"
for w in "${WORKFLOWS[@]}"; do
  IFS='|' read -r num phase skill name <<< "$w"
  [[ "$phase" == "3" ]] && printf "    \e[97m%2s\e[0m  %s\n" "$num" "$name"
done

printf "\n  \e[1;33mPhase 4 — Implementierung\e[0m\n"
for w in "${WORKFLOWS[@]}"; do
  IFS='|' read -r num phase skill name <<< "$w"
  [[ "$phase" == "4" ]] && printf "    \e[97m%2s\e[0m  %s\n" "$num" "$name"
done

printf "\n  \e[90m─────────────────────────────\e[0m\n"
printf "  \e[90mq = abbrechen\e[0m\n\n"
printf "  Workflow: "

# --- Read Selection ---------------------------------------------------------

read -r selection

[[ "$selection" == "q" || -z "$selection" ]] && exit 0

# Find the selected workflow
selected_phase=""
selected_skill=""
selected_name=""

for w in "${WORKFLOWS[@]}"; do
  IFS='|' read -r num phase skill name <<< "$w"
  if [[ "$num" == "$selection" ]]; then
    selected_phase="$phase"
    selected_skill="$skill"
    selected_name="$name"
    break
  fi
done

if [[ -z "$selected_skill" ]]; then
  printf "\n  \e[31mUnbekannte Auswahl: %s\e[0m\n" "$selection"
  sleep 1
  exit 1
fi

# --- Phase-Aware Launch -----------------------------------------------------

log_activity() {
  echo "$(date +%H:%M:%S)  [KLACK]  $1" >> "$KLACK_ROOT/.klack/activity.log"
}

if [[ "$selected_phase" -le 3 ]]; then
  # Phase 1-3: ALWAYS interactive — new tmux window
  window_name="plan-${selected_name// /-}"
  window_name="${window_name,,}"  # lowercase

  log_activity "Starte Planungs-Workflow: $selected_name (Phase $selected_phase, interaktiv)"

  tmux new-window -t "$KLACK_SESSION" -n "$window_name" \
    "export KLACK_ROOT='$KLACK_ROOT' KLACK_SESSION='$KLACK_SESSION'; \
     claude --dangerously-skip-permissions --chrome -p '/$selected_skill'; \
     echo ''; \
     echo 'Planungs-Session beendet.'; \
     echo ''; \
     read -p 'Moechtest du die Implementierung im YOLO-Modus (vollautonom) starten? [j/n] ' yolo_answer; \
     if [[ \"\$yolo_answer\" == \"j\" ]]; then \
       echo 'mode: yolo' > '$KLACK_ROOT/.klack-worktree.yaml'; \
       echo 'workflow: $selected_skill' >> '$KLACK_ROOT/.klack-worktree.yaml'; \
       echo \"created_at: \$(date -u +%Y-%m-%dT%H:%M:%SZ)\" >> '$KLACK_ROOT/.klack-worktree.yaml'; \
       echo ''; \
       echo 'YOLO-Modus aktiviert. Implementierung laeuft autonom.'; \
     else \
       echo 'mode: interactive' > '$KLACK_ROOT/.klack-worktree.yaml'; \
       echo 'workflow: $selected_skill' >> '$KLACK_ROOT/.klack-worktree.yaml'; \
       echo \"created_at: \$(date -u +%Y-%m-%dT%H:%M:%SZ)\" >> '$KLACK_ROOT/.klack-worktree.yaml'; \
       echo ''; \
       echo 'Interaktiver Modus. Du wirst nach jedem Step gefragt.'; \
     fi; \
     sleep 2"

else
  # Phase 4: Respect .klack-worktree.yaml mode
  mode="interactive"
  if [[ -f "$KLACK_ROOT/.klack-worktree.yaml" ]]; then
    mode="$(grep '^mode:' "$KLACK_ROOT/.klack-worktree.yaml" 2>/dev/null | sed 's/mode:\s*//' | tr -d ' ')" || mode="interactive"
  fi

  log_activity "Starte Implementierungs-Workflow: $selected_name (Phase 4, mode=$mode)"

  if [[ "$mode" == "yolo" ]]; then
    # Autonomous — inject skill as prompt, no review pauses
    tmux new-window -t "$KLACK_SESSION" -n "${selected_name// /-}" \
      "export KLACK_ROOT='$KLACK_ROOT' KLACK_SESSION='$KLACK_SESSION'; \
       claude --dangerously-skip-permissions --chrome -p '/$selected_skill'"
  else
    # Interactive — open chat session with skill hint
    tmux new-window -t "$KLACK_SESSION" -n "${selected_name// /-}" \
      "export KLACK_ROOT='$KLACK_ROOT' KLACK_SESSION='$KLACK_SESSION'; \
       claude --dangerously-skip-permissions --chrome -p '/$selected_skill'"
  fi
fi
