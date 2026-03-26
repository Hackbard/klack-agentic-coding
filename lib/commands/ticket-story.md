# ticket-story — Story-Analyse

## 1. Protokoll laden

Lies zuerst vollstaendig: `commands/klack-protocol.md` (oder `.claude/commands/klack-protocol.md`)
Das ist dein Betriebshandbuch. Befolge es. Lies `.klack.yml` fuer die Projekt-Config.

## 2. Dein Step: `story`

Der Turmwaechter hat status.json bereits auf `running` gesetzt.

## 3. Ticket einlesen

Basierend auf `ticket_source` aus `.klack.yml`:

- **jira**: Atlassian MCP → `getJiraIssue`, Kommentare, verlinkte Issues
- **github**: `gh issue view KLACK_TICKET --json title,body,comments,labels`
- **gitlab**: `glab issue view KLACK_TICKET`
- **linear**: Linear MCP (falls verfuegbar) oder API
- **markdown**: Lies `.klack/tickets/KLACK_TICKET.md` — lokales Ticket. Lies auch das zugehoerige Epic (`epic-N.md` wo N die erste Zahl in der Ticket-ID ist, z.B. E1-001 → epic-1.md) fuer Gesamtkontext.
- **bmad**: Story-Datei liegt bereits in `_bmad-output/implementation-artifacts/`:
  1. Finde die Datei via Pattern: `_bmad-output/implementation-artifacts/{KLACK_TICKET}-*.md`
     ```bash
     story_file=$(find "$KLACK_ROOT/_bmad-output/implementation-artifacts" \
       -name "${KLACK_TICKET}-*.md" -type f 2>/dev/null | head -1)
     ```
  2. Wenn KEINE Datei gefunden:
     - Schreibe `ERROR: No BMad story found for ticket '{KLACK_TICKET}'. Expected: _bmad-output/implementation-artifacts/{KLACK_TICKET}-*.md` nach `$KLACK_DIR/error.log`
     - `exit 1`
  3. Wenn gefunden: Lese den Datei-Inhalt
  4. Speichere in `$KLACK_DIR/ticket-raw.md` UND `$KLACK_DIR/story.md` (die BMad-Story IS bereits die Story — kein BMAD create-story Workflow noetig)
  5. Update `status.json` log: `"BMad story found and copied: {filename}"`
  6. **Weiter direkt zu Schritt 5 (Abschluss)** — Schritt 4 ueberspringen

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
