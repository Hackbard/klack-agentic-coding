---
name: klack-weiter
description: Uebergabe an den autonomen Klack-Agenten. Schreibt den aktuellen Stand in eine Resume-Datei damit der Turmwaechter autonom weitermachen kann.
---

Du bist in einer interaktiven Klack Review-Session. Der Developer will dass du ab jetzt autonom weitermachst.

## Was du tun musst:

### 1. Aktuellen Stand zusammenfassen

Analysiere die bisherige Konversation und schreibe eine praezise Resume-Datei. Finde `KLACK_DIR` aus dem System-Prompt oder der Umgebung.

Falls KLACK_DIR nicht bekannt: suche nach `.klack/signale/*/status.json` im aktuellen Verzeichnis und identifiziere das aktive Ticket.

### 2. Resume-Datei schreiben

Schreibe nach `$KLACK_DIR/resume.md`:

```markdown
# Resume: Autonome Weiterarbeit

## Was wurde gemacht
- [Liste der erledigten Arbeiten aus der interaktiven Session]

## Was noch offen ist
- [Liste der noch ausstehenden Aufgaben]

## Aktueller Zustand
- [Welche Dateien wurden erstellt/geaendert]
- [Welcher Branch, welcher Worktree]
- [Offene Punkte]

## Naechster Schritt
[Konkrete Anweisung was der autonome Agent als naechstes tun soll]
```

### 3. Dem Developer Bescheid geben

Sag dem Developer:

```
Resume-Datei geschrieben. Der Turmwaechter wird autonom weitermachen wo du aufgehoert hast.

Tippe jetzt /exit um die Session zu beenden. Der autonome Agent startet danach automatisch.
```

### Wichtig
- Sei PRAEZISE in der Resume-Datei — der autonome Agent hat KEINEN Kontext ausser dieser Datei und dem Conversation-History via `claude -c`
- Liste konkret auf welche Dateien beruehrt wurden
- Beschreibe den naechsten Schritt so, dass ein Agent ihn ohne Rueckfragen ausfuehren kann
