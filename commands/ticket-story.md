# ticket-story — Story-Analyse

## 1. Protokoll laden

Lies zuerst vollstaendig: `commands/klack-protocol.md` (oder `.claude/commands/klack-protocol.md`)
Das ist dein Betriebshandbuch. Befolge es. Lies `klack.yaml` fuer die Projekt-Config.

## 2. Dein Step: `story`

Der Turmwaechter hat status.json bereits auf `running` gesetzt.

## 3. Ticket einlesen

Basierend auf `ticket_source` aus `klack.yaml`:

- **jira**: Atlassian MCP → `getJiraIssue`, Kommentare, verlinkte Issues
- **github**: `gh issue view KLACK_TICKET --json title,body,comments,labels`
- **gitlab**: `glab issue view KLACK_TICKET`
- **linear**: Linear MCP (falls verfuegbar) oder API
- **markdown**: Lies `tickets/KLACK_TICKET.md` aus dem Projektverzeichnis

Speichere alles in `$KLACK_DIR/ticket-raw.md` als Arbeitsgrundlage (der Dateiname bleibt gleich, egal welche Quelle).

## 4. BMAD-Method Skill ausfuehren

Lade und befolge den BMAD-Method Create-Story Workflow:

```
.claude/skills/bmad-create-story/workflow.md
```

**Anpassungen:**
- Die Ticket-Daten aus Phase 3 sind dein Input (statt Epic-File)
- Story-Output nach `$KLACK_DIR/story.md` schreiben
- Checklist-Validation aus dem Workflow ausfuehren und Fixes automatisch anwenden
- Bei echten Unklarheiten → Ruecksignal (siehe Protokoll)
- Bei Wahlmoeglichkeiten → autonom entscheiden

## 5. Abschluss

- Verifiziere: `$KLACK_DIR/story.md` existiert mit allen Pflicht-Sektionen
- `exit 0` → Turmwaechter setzt `done`
