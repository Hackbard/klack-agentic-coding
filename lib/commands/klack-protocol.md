# Klack Protocol — Agent Communication Layer

Du bist ein autonomer Agent innerhalb von **Der Klack**, einer automatisierten Entwicklungs-Pipeline. Dieses Dokument ist dein Betriebshandbuch. Lies es vollstaendig bevor du irgendetwas anderes tust.

## Projekt-Konfiguration

Lies als erstes `klack.yaml` im Projektroot (falls vorhanden). Die Config sagt dir:
- **`ticket_source`**: Wo Tickets leben (jira, github, gitlab, linear, markdown)
- **`pr_tool`**: Wie MRs/PRs erstellt werden (gitlab → `glab`, github → `gh`)
- **`pr_target_branch`**: Ziel-Branch fuer MRs/PRs (z.B. develop, main)
- **`ci_tool`**: Welche CI ueberwacht wird (gitlab, github)
- **`qa_ci_config`**: Welche CI-Config fuer den Quality Gate gilt

Falls keine `klack.yaml` existiert, nimm die Defaults: jira + gitlab + develop.

## Deine Umgebung

Du laeuft als **frischer Claude-Prozess** in einem tmux-Window. Du hast keinen vorherigen Kontext. Der Turmwaechter hat dir Ticket-Daten am Ende deines Prompts injiziert (nach `---`):

```
---
KLACK_TICKET: IN-2262
KLACK_TYPE: feat
KLACK_DIR: /absolute/path/to/.klack/signale/IN-2262
```

- **`KLACK_DIR`** ist dein Filesystem-Anker. Alle Pfade gehen von hier aus. Nie relative Pfade, nie raten.
- **`KLACK_TICKET`** ist die Ticket-ID (fuer Branch-Naming, Commits, etc.).
- **`KLACK_TYPE`** ist `feat`, `fix`, oder `hot`.

## Die Pipeline

Du bist einer von 5 sequentiellen Steps. Jeder Step ist ein eigener Claude-Prozess:

```
ticket-story → ticket-dev → ticket-qa → ticket-review → ticket-release → ticket-pipeline
  (Sonnet)      (Sonnet)     (Sonnet)     (Opus)         (Sonnet)        (Sonnet)
```

Dein Step steht in deinem Command-File. Du kennst nur deinen Step — was vorher/nachher passiert, ist nicht dein Problem.

## Dateien in KLACK_DIR

| Datei | Wer schreibt | Wer liest | Wann |
|-------|-------------|-----------|------|
| `story.md` | ticket-story | ticket-dev, ticket-qa, ticket-release | Story fertig → Dev liest sie |
| `review.md` | ticket-review | ticket-release | Review fertig → Release liest sie |
| `status.json` | Jeder Step | Turmwaechter, Hauptturm | Immer aktuell halten! |
| `question.txt` | Jeder Step | Hauptturm (Developer) | Wenn du eine Frage hast |
| `answer.txt` | Developer (via Hauptturm) | Jeder Step | Antwort auf deine Frage |
| `waiting.flag` | Jeder Step | Turmwaechter, Hauptturm | Signal: "Ich warte" |
| `error.log` | Jeder Step | Developer | Bei Fehlern |

## status.json — Wer schreibt was?

Schema:

```json
{
  "step": "story|dev|qa|review|release",
  "status": "running|waiting|done|error",
  "log": "Kurze Beschreibung was gerade passiert",
  "updated_at": "2026-03-20T14:32:01Z",
  "mr_url": null,
  "worktree_path": null,
  "branch": null
}
```

### Verantwortlichkeiten (WICHTIG — keine Doppel-Writes!)

**Der Turmwaechter** (ticket-run.sh) setzt:
- `step` und `status: "running"` **vor** deinem Start
- `status: "done"` **nach** deinem erfolgreichen Exit
- `status: "error"` **nach** deinem Exit mit Fehler

**Du** (der Agent) setzt NUR:
- `status: "waiting"` + `log` wenn du eine Frage stellst (Ruecksignal)
- `log` um Fortschritt zu melden (z.B. "Implementing UserController...")
- `worktree_path` und `branch` (nur ticket-dev)
- `mr_url` (nur ticket-release)

**Du setzt NICHT `running`, `done` oder `error` in status.json** — das macht der Turmwaechter. Dein Exit-Code entscheidet: `exit 0` = Turmwaechter setzt done, `exit 1` = Turmwaechter setzt error.

### Fehler melden

```bash
echo "Fehlerbeschreibung" >> "$KLACK_DIR/error.log"
exit 1   # Turmwaechter erkennt den Exit-Code und setzt status → error
```

## Ruecksignal — Wenn du den Developer fragen musst

Nutze das NUR wenn du wirklich nicht weiterkommst. Autonomes Handeln ist bevorzugt.

### Frage stellen (REIHENFOLGE KRITISCH!)

```bash
# 1. Frage schreiben
echo "Deine Frage hier" > "$KLACK_DIR/question.txt"

# 2. Status aktualisieren
# status.json → status: "waiting", log: "Frage: <zusammenfassung>"

# 3. Flag setzen — MUSS LETZTER SCHRITT SEIN (ist der Trigger!)
touch "$KLACK_DIR/waiting.flag"
```

### Auf Antwort warten

```bash
# Poll bis Flag weg ist
while [ -f "$KLACK_DIR/waiting.flag" ]; do
  sleep 5
done

# Antwort lesen
answer=$(cat "$KLACK_DIR/answer.txt")

# Status zuruecksetzen → "running"
```

**Warum diese Reihenfolge?** `waiting.flag` ist das kanonische Signal. Erst wenn es existiert, weiss der Hauptturm dass eine Frage da ist. Erst wenn es weg ist, darfst du die Antwort lesen. Andersrum = Race Condition.

## Worktree-Verifikation (fuer dev/qa/review/release)

Wenn du in einem Git-Worktree arbeitest, MUSST du zuerst pruefen:

```bash
if [ -d ".git" ]; then
  echo "ERROR: Nicht in einem Git-Worktree (.git ist ein Verzeichnis, nicht eine Datei)" >&2
  echo "Worktree-Verifikation fehlgeschlagen" > "$KLACK_DIR/error.log"
  # status.json → error
  exit 1
fi
```

`.git` als **Datei** (nicht Verzeichnis) = du bist im Worktree. `.git` als **Verzeichnis** = du bist im Hauptrepo = FALSCH.

## Branch-Naming (fuer ticket-dev)

Format: `worktree-{KLACK_TYPE}/{KLACK_TICKET}-{slug}`

Slug aus Story-Titel generieren:
1. Titel aus `story.md` (erste `#`-Zeile)
2. Alles lowercase
3. Leerzeichen → Bindestriche
4. Nur `a-z`, `0-9`, `-` behalten
5. Mehrfach-Bindestriche kollabieren
6. Max 40 Zeichen (an Wortgrenze abschneiden)

## BMAD-Method-Integration

Nach dem Laden dieses Protokolls laedt dein Command-File einen **BMAD-Method Skill** (z.B. `bmad-dev-story`, `bmad-code-review`). Der BMAD-Method Skill ist dein Werkzeug fuer die fachliche Arbeit. Dieses Protokoll ist deine Infrastruktur-Schicht.

```
┌─────────────────────────────────────┐
│  BMAD-Method Skill (fachliche Logik) │  ← Was du tust
├─────────────────────────────────────┤
│  Klack-Protocol (Kommunikation)     │  ← Wie du kommunizierst
├─────────────────────────────────────┤
│  Turmwaechter (Orchestrierung)      │  ← Wer dich startet
└─────────────────────────────────────┘
```

**Wenn der BMAD-Method Skill "WAIT FOR INPUT" oder einen interaktiven Checkpoint hat:**
→ Nutze stattdessen das Ruecksignal (question.txt → waiting.flag) wenn du wirklich nicht weiterkommst
→ Oder entscheide autonom wenn die Antwort offensichtlich ist

**Wenn der BMAD-Method Skill Dateien an Standard-Pfade schreibt:**
→ Kopiere/schreibe das Ergebnis zusaetzlich nach `KLACK_DIR` (story.md, review.md)

## Fortschritts-Logging (WICHTIG!)

Der Hauptturm kann NICHT in dein Terminal reinschauen. Er sieht NUR was in `status.json` steht. Deshalb: **update das `log`-Feld haeufig!**

```python
# Bei jedem wichtigen Zwischen-Schritt:
python3 -c "
import json
from datetime import datetime, timezone
d = json.load(open('$KLACK_DIR/status.json'))
d['log'] = 'Jira-Ticket wird gelesen...'
d['updated_at'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
json.dump(d, open('$KLACK_DIR/status.json', 'w'), indent=2)
"
```

Beispiele fuer gute Log-Updates:
- `"Jira-Ticket wird gelesen..."`
- `"3 Unklarheiten gefunden, klaere autonom..."`
- `"BMAD-Method Workflow gestartet..."`
- `"Story-Sektionen werden geschrieben..."`
- `"Worktree erstellt: worktree-feat/IN-2262-auth"`
- `"PHPStan: 2 Fehler, Iteration 2/3..."`

Ohne diese Updates ist der Hauptturm blind — der Developer denkt es haengt.

## Zusammenfassung deiner Pflichten

1. **Lies dieses Protokoll** vollstaendig
2. **Lade den BMAD-Method Skill** den dein Command-File angibt
3. **Fuehre die fachliche Arbeit aus** (BMAD-Method Skill als Engine)
4. **Update `status.json → log` haeufig** damit der Hauptturm sieht was passiert
5. **Kommuniziere via Signale-Dateien** (nicht stdout, nicht stderr fuer den User)
6. **Bei Fragen → Ruecksignal**, bei Fehlern → `error.log` + `exit 1`
