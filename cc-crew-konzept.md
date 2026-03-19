# cc-crew – Konzept

Dieses Dokument beschreibt die Architektur eines autonomen Multi-Ticket-Entwicklungssystems auf Basis von Claude Code, BMAD-METHOD und einem Filesystem-basierten Message Bus. Es richtet sich an einen Coding Agent der das System implementiert.

---

## Ziel

Der Entwickler gibt eine Liste von Jira-Ticket-IDs ein und lehnt sich zurück. Das System arbeitet alle Tickets autonom ab – von der Story-Analyse bis zum fertigen GitLab Merge Request. Der Entwickler wird nur bei echten Entscheidungen gefragt, die er direkt in einem zentralen Status-Dashboard beantwortet.

---

## Kernprinzipien

**Saubere Kontexttrennung**: Jeder BMAD-Step läuft als eigener Claude-Prozess mit leerem Kontext. Es gibt kein `/clear` innerhalb einer Session. Neuer Prozess = automatisch frischer Kontext. Das ist bewusst so – der Reviewer soll nicht wissen wie der Code entstanden ist.

**Filesystem als Message Bus**: Zwischen den Sessions kommunizieren die Prozesse ausschließlich über Dateien in einem `.crew/` Verzeichnis. Kein IPC, keine Sockets, kein geteilter Speicher. Einfach, debuggbar, robust.

**Zwei Ebenen der Parallelität**: Ebene 1 – der Entwickler entscheidet welche Tickets parallel laufen (separate tmux Windows, separate Claude-Instanzen). Ebene 2 – Claude entscheidet innerhalb eines Tickets was parallel bearbeitet wird (native Sub-Agents). Beide Ebenen sind unabhängig voneinander.

**BMAD bleibt unangetastet**: Die bestehenden BMAD-Definitionen unter `_bmad/` werden nicht verändert. Das System baut drumherum, nicht darüber.

**Sub-Agents sind erlaubt**: Innerhalb jedes Steps darf Claude native Sub-Agents einsetzen wenn es sinnvoll ist. Claude entscheidet das selbst – es wird nicht erzwungen.

---

## Systemkomponenten

### 1. cc-crew (Shell Script)

Der einzige manuelle Einstiegspunkt. Der Entwickler ruft es mit Ticket-Typ und Ticket-IDs auf. Das Script legt die tmux-Session an, öffnet Window 0 als Mayor-Dashboard und startet für jedes Ticket ein eigenes tmux-Window mit dem Orchestrator-Script.

Der Ticket-Typ wird beim Aufruf mitgegeben und bestimmt das Branch-Naming. Mögliche Typen: feat, fix, hot.

Innerhalb des Scripts werden die Model-Umgebungsvariablen gesetzt bevor irgendwas startet. Haiku für Sub-Agents, Sonnet als Standard, Opus für den Review-Step.

### 2. Window 0 – Mayor Dashboard

Ein dauerhaft laufendes Watch-Script das den Zustand aller laufenden Tickets anzeigt. Es liest kontinuierlich die Status-Dateien aus `.crew/` und zeigt pro Ticket: aktueller Step, Fortschrittsbalken, letzter Log-Eintrag.

Wenn eine Session eine Rückfrage hat erscheint sie prominent im Dashboard. Der Entwickler tippt die Antwort direkt im Dashboard ein. Das Script schreibt sie in die entsprechende Answer-Datei und löscht das Waiting-Flag. Die blockierte Session läuft dann automatisch weiter.

Aus Window 0 heraus kann der Entwickler auch neue Tickets zur laufenden Crew hinzufügen. Das öffnet ein neues tmux-Window und startet den Orchestrator für das neue Ticket.

### 3. ticket-run.sh (Orchestrator pro Ticket)

Läuft in jedem Ticket-Window. Startet die BMAD-Steps sequenziell als separate Claude-Prozesse. Schreibt nach jedem Step den Status in `.crew/`. Wartet bei einem Waiting-Flag bis eine Antwort vorliegt. Bricht bei hartem Fehler ab und markiert das Ticket im Dashboard als fehlgeschlagen.

### 4. BMAD Steps als separate Commands

Fünf Commands unter `.claude/commands/`. Jeder ist eine eigenständige Markdown-Datei die Claude Code als Slash-Command kennt. Jeder startet als frischer Prozess ohne Vorkontext.

**ticket-story**: Liest das Jira-Ticket via Atlassian MCP vollständig ein. Reichert die Story nach BMAD-Standard an. Klärt alle Unklarheiten – entweder durch Rückfrage an den Entwickler via Answer-File-Mechanismus oder durch eigenständige Entscheidung wenn der Kontext eindeutig ist. Schreibt das Ergebnis als strukturierte Story-Datei in `.crew/TICKET/story.md`. Erst wenn alle Fragen geklärt sind und die Story vollständig ist darf dieser Step als fertig markiert werden.

**ticket-dev**: Liest ausschließlich `story.md` aus `.crew/`. Stellt sicher dass ein Git-Worktree für den Branch existiert und arbeitet darin. Branch-Name wird aus Ticket-Typ und Ticket-ID und einem Slug aus dem Story-Titel gebildet. Implementiert die Story nach den Coding Standards des Projekts. Schreibt keinen Test-Code – das ist Aufgabe des nächsten Steps. Committet am Ende.

**ticket-qa**: Liest `story.md` und den aktuellen Code-Stand. Schreibt Tests mit PEST. Testdaten sind domänenspezifisch und realistisch – kein reiner Faker-Zufall. Es gibt immer Happy-Path-Tests und Negativ-Tests für jeden relevanten Edge Case. Danach läuft der Quality Gate Loop: PHP-CS-Fixer fixen, PHPStan analysieren, PEST ausführen mit Coverage-Prüfung. Bei Fehlern zurück in den Fix-Loop. Maximal drei Iterationen, danach Abbruch mit Fehlerbericht. Die CI-Konfiguration aus `.gitlab-ci.yml` wird zu Beginn gelesen um die exakten Commands, Parameter und Schwellwerte zu kennen – insbesondere das Coverage-Minimum von 95 Prozent mit pcov und den PHPStan Memory-Limit.

**ticket-review**: Bekommt ausschließlich den Git-Diff als Input – keinen Story-Kontext, keine Entwicklungsgeschichte. Reviewt als externer Entwickler der den Code zum ersten Mal sieht. Läuft auf Opus. Prüft auf Edge Cases, Security, Performance, SOLID-Verletzungen und Abweichungen von den Projektstandards. Schreibt das Ergebnis als strukturiertes Review nach `.crew/TICKET/review.md`. Bei kritischen Findings blockiert dieser Step und fragt den Entwickler.

**ticket-release**: Liest `review.md`. Wenn das Review grün ist: erstellt den Merge Request via glab CLI gegen develop. MR-Titel und Beschreibung werden aus Story und Review generiert. Schreibt einen Kommentar ins Jira-Ticket mit einer kurzen Zusammenfassung und einem freundlichen KI-Gruß. Markiert das Ticket im Dashboard als fertig.

### 5. .crew/ Verzeichnisstruktur

Pro Ticket ein Unterverzeichnis. Darin: story.md, review.md, status.json, question.txt, answer.txt, waiting-for-answer.flag, error.log. Das Verzeichnis ist das einzige geteilte Medium zwischen allen Prozessen und dem Dashboard.

---

## Branch-Naming

Drei Typen, alle mit Worktree-Präfix:

- `worktree-feat/IN-XXXX-slug-aus-story-titel`
- `worktree-fix/IN-XXXX-slug-aus-story-titel`
- `worktree-hot/IN-XXXX-slug-aus-story-titel`

Der Slug wird aus dem Story-Titel generiert: Kleinbuchstaben, Leerzeichen durch Bindestriche, Sonderzeichen entfernt, maximal 40 Zeichen. Der Ticket-Typ kommt vom Entwickler beim cc-crew Aufruf.

---

## Quality Gate

Die exakten Commands kommen aus `.gitlab-ci.yml` – das ist die einzige Quelle der Wahrheit. Lokal gelten folgende Abweichungen von der CI:

PHP-CS-Fixer läuft lokal ohne `--dry-run` – es wird direkt gefixt, nicht nur geprüft. In der CI läuft es mit `--dry-run --diff` zum reinen Prüfen.

PHPStan läuft mit `memory_limit=1024M` und `-vvv` exakt wie in der CI.

PEST läuft mit `--parallel`. Coverage-Minimum ist 95 Prozent mit pcov, exakt wie im `code-coverage-job` der CI definiert.

Bei Fehlern geht der Loop zurück zum Coder, nicht zum Story-Step. Maximal drei Iterationen. Danach Abbruch.

---

## Model-Konfiguration

Wird in cc-crew als Umgebungsvariablen gesetzt, nicht in Konfig-Dateien.

Sonnet ist der Standard für alle Haupt-Agents. Haiku läuft für Sub-Agents – parallele kleine Tasks wie Status schreiben, Dateien lesen, Commands ausführen. Opus läuft für den Review-Step.

Die Umgebungsvariable `CLAUDE_CODE_SUBAGENT_MODEL` steuert das Sub-Agent-Model nativ in Claude Code ohne eigenen Router.

---

## Rückfrage-Mechanismus

Wenn eine Session eine Frage hat die der Entwickler beantworten muss: Question-Datei schreiben, Waiting-Flag setzen, in eine Poll-Schleife gehen. Der Orchestrator erkennt das Flag und blockiert den nächsten Step.

Window 0 zeigt die Frage prominent. Der Entwickler tippt die Antwort. Das Dashboard schreibt sie in die Answer-Datei und löscht das Flag. Die Session liest die Antwort und arbeitet weiter.

Dieser Mechanismus ist der einzige Kommunikationskanal zwischen dem Entwickler und den laufenden Sessions.

---

## Was BMAD bereits definiert

Die bestehenden BMAD-Definitionen unter `_bmad/` regeln Persona-Verhalten, Workflow-Struktur, Review-Kriterien und Qualitätsstandards. Diese werden von den ticket-*.md Commands referenziert aber nicht dupliziert. Wenn BMAD etwas definiert wird es dort gelesen – nicht nochmal in den Commands geschrieben.

---

## Was dieses System neu definiert

Branch-Naming-Schema, Worktree-Erstellung und -Prüfung, Quality Gate Loop mit CI-Parität, Rückfrage-Mechanismus via Filesystem, Mayor-Dashboard, Model-Konfiguration pro Step, PR-Erstellung via glab, Jira-Kommentar mit KI-Gruß, sequenzielle Session-Orchestrierung mit sauberem Kontextschnitt zwischen Steps.

---

## Nicht in Scope

Jira-Status-Updates während der Bearbeitung, automatische Dependency-Analyse zwischen Tickets, Konflikt-Erkennung bei parallelen Worktrees die dieselben Dateien anfassen. Diese können später ergänzt werden.
