# ticket-review — Code Review

## 1. Protokoll laden

Lies zuerst vollstaendig: `commands/klack-protocol.md`

## 2. Dein Step: `review`

Der Turmwaechter hat status.json bereits auf `running` gesetzt.

**Hinweis: Du laeuft auf Opus** (nicht Sonnet wie die anderen Steps).

## 3. Setup

1. Lies `$KLACK_DIR/status.json` → `worktree_path`, `branch`
2. Navigiere in den Worktree
3. Worktree-Verifikation (siehe Protokoll)

## 4. BMAD-Method Skill ausfuehren

Lade und befolge den BMAD-Method Code-Review Workflow:

```
.claude/skills/bmad-code-review/workflow.md
```

**Anpassungen:**
- Review-Scope: `git diff develop...HEAD` (oder `git diff main...HEAD`)
- Review-Output nach `$KLACK_DIR/review.md` schreiben
- Der BMAD-Method Workflow hat Step-Files (`./steps/step-01-*.md` etc.) — folge ihnen sequentiell
- Bei "WAIT FOR INPUT" Checkpoints: autonom weitermachen (du bist der Reviewer)
- Die Multi-Layer-Review-Architektur (Blind Hunter, Edge Case Hunter, etc.) voll ausfuehren

## 5. Kritische Findings

**Wenn `review.md` CRITICAL/blocking Findings enthaelt:**
→ Ruecksignal: Findings-Zusammenfassung an Developer, er entscheidet

**Wenn keine kritischen Findings:**
→ Direkt weiter, Turmwaechter geht zu Release

## 6. Abschluss

- status.json → `log` auf "APPROVED" oder "BLOCKED" setzen (nur log!)
- `exit 0` → Turmwaechter setzt `done`
