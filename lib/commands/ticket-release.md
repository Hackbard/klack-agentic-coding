# ticket-release — Release

## 1. Protokoll laden

Lies zuerst vollstaendig: `commands/klack-protocol.md`
Lies `klack.yaml` fuer `pr_tool`, `pr_target_branch`, `ticket_source`.

## 2. Dein Step: `release`

Der Turmwaechter hat status.json bereits auf `running` gesetzt.

## 3. Voraussetzungen pruefen

1. Lies `$KLACK_DIR/review.md` → keine ungeloesten CRITICAL Findings
2. Lies `$KLACK_DIR/story.md` → fuer MR/PR-Beschreibung
3. Lies `$KLACK_DIR/status.json` → `branch`, `worktree_path`
4. Navigiere in Worktree, Worktree-Verifikation

## 4. Branch pushen & MR/PR erstellen

```bash
git push -u origin <branch>
```

Basierend auf `pr_tool` aus `klack.yaml`:

**gitlab:**
```bash
glab mr create \
  --title "Draft: $KLACK_TYPE($KLACK_TICKET): <story-titel>" \
  --description "<beschreibung>" \
  --target-branch <pr_target_branch> \
  --draft \
  --no-editor
```

**github:**
```bash
gh pr create \
  --title "Draft: $KLACK_TYPE($KLACK_TICKET): <story-titel>" \
  --body "<beschreibung>" \
  --base <pr_target_branch> \
  --draft
```

MR/PR-URL in status.json → `mr_url` speichern.

## 5. Ticket-Kommentar

Basierend auf `ticket_source` aus `klack.yaml`:

- **jira**: Atlassian MCP → `addCommentToJiraIssue`
- **github**: `gh issue comment KLACK_TICKET --body "<text>"`
- **gitlab**: `glab issue note KLACK_TICKET --message "<text>"`
- **linear**: Linear MCP oder API
- **markdown**: Append to `tickets/KLACK_TICKET.md`

Kommentar-Text:
```
Merge Request erstellt: <MR/PR URL>
Zusammenfassung: <aus story.md>
Review: APPROVED / APPROVED WITH NOTES

— Der Klack
  "Die Botschaft ist das Medium." – Postmeister
```

## 6. Abschluss

- status.json → `mr_url` setzen (nur mr_url und log, nicht status!)
- `exit 0` → Turmwaechter setzt `done`
- Bei Fehler (MR/PR oder Kommentar) → error.log schreiben + `exit 1`

**Kein BMAD-Method Skill noetig** — Release ist rein Klack-spezifisch.
