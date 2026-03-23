# ticket-dev — Implementierung

## 1. Protokoll laden

Lies zuerst vollstaendig: `commands/klack-protocol.md`

## 2. Dein Step: `dev`

Der Turmwaechter hat status.json bereits auf `running` gesetzt.

## 3. Git-Worktree anlegen

1. Lies `$KLACK_DIR/story.md` → Titel fuer Slug
2. Branch: `worktree-$KLACK_TYPE/$KLACK_TICKET-<slug>` (Slug-Regeln im Protokoll)
3. `git worktree add` → Worktree erstellen
4. Worktree-Verifikation (`.git` muss Datei sein — siehe Protokoll)
5. status.json → `worktree_path` und `branch` Felder setzen

## 4. BMAD-Method Skill ausfuehren

Lade und befolge den BMAD-Method Dev-Story Workflow **im Worktree**:

```
.claude/skills/bmad-dev-story/workflow.md
```

**Anpassungen:**
- `story_path` = `$KLACK_DIR/story.md`
- Arbeite ausschliesslich im Worktree
- Keine Tests schreiben (ticket-qa macht das)
- Bei HALT → Ruecksignal
- Sprint-Status-Updates ueberspringen (Turmwaechter regelt das)

## 5. Abschluss

- Alle Aenderungen committen: `$KLACK_TYPE($KLACK_TICKET): <beschreibung>`
- status.json → `log` auf Commit-Hash setzen (nur log, nicht status!)
- `exit 0` → Turmwaechter setzt `done`
