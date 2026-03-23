# Der Klack – Konzept

Dieses Dokument beschreibt die Architektur eines autonomen Multi-Ticket-Entwicklungssystems auf Basis von Claude Code, BMAD-Method und einem Filesystem-basierten Message Bus. Es richtet sich an einen Coding Agent der das System implementiert.

Die Namensgebung orientiert sich an der Scheibenwelt von Terry Pratchett. Der Klack ist das optische Telegraphennetzwerk der Scheibenwelt – Semaphor-Türme die Nachrichten über große Distanzen übertragen. Eine passende Metapher für ein System das Informationen zwischen autonomen Prozessen weiterreicht.

---

## Komponenten-Übersicht

| Name | Technische Rolle |
|------|-----------------|
| Der Postmeister | `cc-crew` Shell Script – startet alles |
| Der Klack | tmux Session – die gesamte Infrastruktur |
| Ankh-Morpork Hauptturm | Window 0 – Mayor Dashboard |
| Türme | Ticket-Windows – je ein tmux Window pro Ticket |
| Turmwächter | `ticket-run.sh` – Orchestrator pro Ticket |
| Klack-Signale | `.crew/` Verzeichnis – Message Bus zwischen Prozessen |
| Semaphor | `status.json` – Zustandsdatei pro Ticket |
| Rücksignal | `answer.txt` – Antwort des Entwicklers auf Rückfragen |

---

## Ziel

Der Entwickler gibt eine Liste von Jira-Ticket-IDs ein und lehnt sich zurück. Das System arbeitet alle Tickets autonom ab – von der Story-Analyse bis zum fertigen GitLab Merge Request. Der Entwickler wird nur bei echten Entscheidungen gefragt, die er direkt im Ankh-Morpork Hauptturm beantwortet.

---

## Kernprinzipien

**Saubere Kontexttrennung**: Jeder BMAD-Method-Step läuft als eigener Claude-Prozess mit leerem Kontext. Es gibt kein `/clear` innerhalb einer Session. Neuer Prozess = automatisch frischer Kontext. Das ist bewusst so – der Reviewer soll nicht wissen wie der Code entstanden ist.

**Klack-Signale als Message Bus**: Zwischen den Sessions kommunizieren die Prozesse ausschließlich über Dateien in `.crew/`. Kein IPC, keine Sockets, kein geteilter Speicher. Einfach, debuggbar, robust.

**Zwei Ebenen der Parallelität**: Ebene 1 – der Entwickler entscheidet welche Tickets parallel laufen (separate Türme, separate Claude-Instanzen). Ebene 2 – Claude entscheidet innerhalb eines Tickets was parallel bearbeitet wird (native Sub-Agents). Beide Ebenen sind unabhängig voneinander.

**BMAD-Method bleibt unangetastet**: Die bestehenden BMAD-Method-Definitionen unter `_bmad/` werden nicht verändert. Der Klack baut drumherum, nicht darüber.

**Sub-Agents sind erlaubt**: Innerhalb jedes Steps darf Claude native Sub-Agents einsetzen wenn es sinnvoll ist. Claude entscheidet das selbst – es wird nicht erzwungen.

---

## Systemkomponenten

### Der Postmeister (cc-crew)

Der einzige manuelle Einstiegspunkt. Der Entwickler ruft ihn mit Ticket-Typ und Ticket-IDs auf. Der Postmeister legt den Klack als tmux-Session an, öffnet den Ankh-Morpork Hauptturm als Window 0 und startet für jedes Ticket einen eigenen Turm.

Der Ticket-Typ wird beim Aufruf mitgegeben und bestimmt das Branch-Naming. Mögliche Typen: feat, fix, hot.

Innerhalb des Postmeisters werden die Model-Umgebungsvariablen gesetzt bevor irgendwas startet. Haiku für Sub-Agents, Sonnet als Standard, Opus für den Review-Step.

Aufruf-Beispiel:
```
cc-crew feat IN-2262 fix IN-2200 hot IN-2199
```

### Ankh-Morpork Hauptturm (Window 0)

Ein dauerhaft laufendes Watch-Script das den Zustand aller laufenden Türme anzeigt. Es liest kontinuierlich die Semaphore aus den Klack-Signalen und zeigt pro Ticket: aktueller Step, Fortschrittsbalken, letzter Log-Eintrag.

Wenn ein Turmwächter ein Rücksignal braucht erscheint die Frage prominent im Hauptturm. Der Entwickler tippt die Antwort direkt ein. Das Script schreibt sie in die entsprechende Rücksignal-Datei und löscht das Waiting-Flag. Der blockierte Turmwächter läuft dann automatisch weiter.

Aus dem Hauptturm heraus kann der Entwickler auch neue Tickets zur laufenden Crew hinzufügen. Das öffnet einen neuen Turm und startet den Turmwächter für das neue Ticket.

### Türme (Ticket-Windows)

Je ein tmux-Window pro Ticket. Läuft der Turmwächter als Prozess. Der Entwickler kann in den Turm wechseln um den rohen Claude-Output zu sehen – muss es aber nicht.

### Turmwächter (ticket-run.sh)

Läuft in jedem Turm. Startet die BMAD-Method-Steps sequenziell als separate Claude-Prozesse. Schreibt nach jedem Step den Semaphor in die Klack-Signale. Wartet bei einem Waiting-Flag bis ein Rücksignal vorliegt. Bricht bei hartem Fehler ab und markiert den Turm im Hauptturm als fehlgeschlagen.

### Klack-Signale (.crew/)

Das Herzstück des Systems. Pro Ticket ein Unterverzeichnis. Darin:

| Datei | Inhalt |
|-------|--------|
| `story.md` | Aufbereitete Story aus Jira |
| `review.md` | Ergebnis des Code Reviews |
| `status.json` | Semaphor – aktueller Step und Status |
| `question.txt` | Rückfrage des Turmwächters |
| `answer.txt` | Rücksignal des Entwicklers |
| `waiting-for-answer.flag` | Gesetzt solange auf Antwort gewartet wird |
| `error.log` | Fehlerprotokoll bei Abbruch |

### BMAD-Method Steps als separate Commands

Fünf Commands unter `.claude/commands/`. Jeder ist eine eigenständige Markdown-Datei die Claude Code als Slash-Command kennt. Jeder startet als frischer Prozess ohne Vorkontext.

**ticket-story**: Liest das Jira-Ticket via Atlassian MCP vollständig ein. Reichert die Story nach BMAD-Method-Standard an. Klärt alle Unklarheiten – entweder durch Rückfrage an den Entwickler via Rücksignal-Mechanismus oder durch eigenständige Entscheidung wenn der Kontext eindeutig ist. Schreibt das Ergebnis als strukturierte Story nach `.crew/TICKET/story.md`. Erst wenn alle Fragen geklärt sind und die Story vollständig ist darf dieser Step als fertig markiert werden.

**ticket-dev**: Liest ausschließlich `story.md` aus den Klack-Signalen. Stellt sicher dass ein Git-Worktree für den Branch existiert und arbeitet darin. Branch-Name wird aus Ticket-Typ, Ticket-ID und einem Slug aus dem Story-Titel gebildet. Implementiert die Story nach den Coding Standards des Projekts. Schreibt keinen Test-Code – das ist Aufgabe des nächsten Steps. Committet am Ende.

**ticket-qa**: Liest `story.md` und den aktuellen Code-Stand. Schreibt Tests mit PEST. Testdaten sind domänenspezifisch und realistisch – kein reiner Faker-Zufall. Es gibt immer Happy-Path-Tests und Negativ-Tests für jeden relevanten Edge Case. Danach läuft der Quality Gate Loop: PHP-CS-Fixer fixen, PHPStan analysieren, PEST ausführen mit Coverage-Prüfung. Bei Fehlern zurück in den Fix-Loop. Maximal drei Iterationen, danach Abbruch mit Fehlerbericht. Die CI-Konfiguration aus `.gitlab-ci.yml` wird zu Beginn gelesen um die exakten Commands, Parameter und Schwellwerte zu kennen – insbesondere das Coverage-Minimum von 95 Prozent mit pcov und den PHPStan Memory-Limit.

**ticket-review**: Bekommt ausschließlich den Git-Diff als Input – keinen Story-Kontext, keine Entwicklungsgeschichte. Reviewt als externer Entwickler der den Code zum ersten Mal sieht. Läuft auf Opus. Prüft auf Edge Cases, Security, Performance, SOLID-Verletzungen und Abweichungen von den Projektstandards. Schreibt das Ergebnis als strukturiertes Review nach `.crew/TICKET/review.md`. Bei kritischen Findings blockiert dieser Step und sendet ein Rücksignal an den Entwickler.

**ticket-release**: Liest `review.md`. Wenn das Review grün ist: erstellt den Merge Request via glab CLI gegen develop. MR-Titel und Beschreibung werden aus Story und Review generiert. Schreibt einen Kommentar ins Jira-Ticket mit einer kurzen Zusammenfassung und einem freundlichen KI-Gruß. Markiert den Turm im Hauptturm als fertig.

---

## Branch-Naming

Drei Typen, alle mit Worktree-Präfix:

- `worktree-feat/IN-XXXX-slug-aus-story-titel`
- `worktree-fix/IN-XXXX-slug-aus-story-titel`
- `worktree-hot/IN-XXXX-slug-aus-story-titel`

Der Slug wird aus dem Story-Titel generiert: Kleinbuchstaben, Leerzeichen durch Bindestriche, Sonderzeichen entfernt, maximal 40 Zeichen. Der Ticket-Typ kommt vom Entwickler beim Postmeister-Aufruf.

---

## Quality Gate

Die exakten Commands kommen aus `.gitlab-ci.yml` – das ist die einzige Quelle der Wahrheit. Lokal gelten folgende Abweichungen von der CI:

PHP-CS-Fixer läuft lokal ohne `--dry-run` – es wird direkt gefixt, nicht nur geprüft. In der CI läuft es mit `--dry-run --diff` zum reinen Prüfen.

PHPStan läuft mit `memory_limit=1024M` und `-vvv` exakt wie in der CI.

PEST läuft mit `--parallel`. Coverage-Minimum ist 95 Prozent mit pcov, exakt wie im `code-coverage-job` der CI definiert.

Bei Fehlern geht der Loop zurück zum Coder, nicht zum Story-Step. Maximal drei Iterationen. Danach Abbruch mit Fehlerbericht ins `error.log` und Rücksignal an den Entwickler.

---

## Model-Konfiguration

Wird vom Postmeister als Umgebungsvariablen gesetzt, nicht in Konfig-Dateien.

Sonnet ist der Standard für alle Haupt-Agents. Haiku läuft für Sub-Agents – parallele kleine Tasks wie Semaphor schreiben, Dateien lesen, Commands ausführen. Opus läuft für den Review-Step.

Die Umgebungsvariable `CLAUDE_CODE_SUBAGENT_MODEL` steuert das Sub-Agent-Model nativ in Claude Code ohne eigenen Router.

---

## Rücksignal-Mechanismus

Wenn ein Turmwächter eine Frage hat die der Entwickler beantworten muss: `question.txt` schreiben, `waiting-for-answer.flag` setzen, in eine Poll-Schleife gehen. Der Turmwächter blockiert den nächsten Step solange das Flag gesetzt ist.

Der Ankh-Morpork Hauptturm zeigt die Frage prominent. Der Entwickler tippt die Antwort. Der Hauptturm schreibt sie nach `answer.txt` und löscht das Flag. Der Turmwächter liest die Antwort und arbeitet weiter.

Dieser Mechanismus ist der einzige Kommunikationskanal zwischen dem Entwickler und den laufenden Türmen.

---

## Was BMAD-Method bereits definiert

Die bestehenden BMAD-Method-Definitionen unter `_bmad/` regeln Persona-Verhalten, Workflow-Struktur, Review-Kriterien und Qualitätsstandards. Diese werden von den ticket-*.md Commands referenziert aber nicht dupliziert. Wenn BMAD-Method etwas definiert wird es dort gelesen – nicht nochmal in den Commands geschrieben.

---

## Was der Klack neu definiert

Branch-Naming-Schema, Worktree-Erstellung und -Prüfung, Quality Gate Loop mit CI-Parität, Rücksignal-Mechanismus via Klack-Signale, Ankh-Morpork Hauptturm Dashboard, Model-Konfiguration pro Step, PR-Erstellung via glab, Jira-Kommentar mit KI-Gruß, sequenzielle Session-Orchestrierung mit sauberem Kontextschnitt zwischen Steps.

---

## Pflichtanforderungen – immer gültig

**Git Worktrees**: Jeder Turmwächter arbeitet ausnahmslos in einem Git Worktree. Niemals im Haupt-Repository. Der Worktree wird zu Beginn des ticket-dev Steps angelegt falls er nicht existiert. Die Prüfung ob man im Worktree ist erfolgt über `.git` als Datei statt als Verzeichnis. Bei Fehler sofortiger Abbruch.

**Dangerous Permissions**: Alle Claude-Prozesse starten mit `--dangerously-skip-permissions`. Kein manuelles Bestätigen von Tool-Aufrufen. Der Postmeister setzt dieses Flag für jeden Turmwächter-Start ohne Ausnahme.

**Chrome**: Alle Claude-Prozesse starten mit dem Chrome-Flag. Browserbasierte Tools und Playwright-Tests stehen damit zur Verfügung.

Der vollständige Start-Command für jeden Turmwächter lautet damit:
```
claude --dangerously-skip-permissions --chrome -p "$(cat .claude/commands/ticket-STEP.md)"
```

---

## Nicht in Scope

Jira-Status-Updates während der Bearbeitung, automatische Dependency-Analyse zwischen Tickets, Konflikt-Erkennung bei parallelen Türmen die dieselben Dateien anfassen. Diese können später ergänzt werden.
