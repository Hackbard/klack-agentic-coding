# ticket-pipeline — CI Pipeline Watch

## 1. Protokoll laden

Lies zuerst vollstaendig: `commands/klack-protocol.md`
Lies `.klack.yml` fuer `ci_tool` und `pr_tool`.

## 2. Dein Step: `pipeline`

Der Turmwaechter hat status.json bereits auf `running` gesetzt.

## 3. MR-URL lesen

Lies `$KLACK_DIR/status.json` → `mr_url` und `branch`.
Navigiere in den Worktree (`worktree_path`).

## 4. Pipeline ueberwachen

Pruefe die CI-Pipeline im 60-Sekunden-Takt.

**gitlab:**
```bash
glab ci status --branch <branch>
glab ci list --branch <branch> -p 1
```

**github:**
```bash
gh run list --branch <branch> -L 1
gh run view <run-id>
```

**Schleife:**
1. Pipeline-Status pruefen
2. `status.json → log` updaten mit aktuellem Pipeline-Status (z.B. "Pipeline running: Stage build...", "Pipeline: 3/5 Jobs passed")
3. 60 Sekunden warten
4. Wiederholen bis Pipeline fertig (success/failed)

## 5. Bei Erfolg (Pipeline gruen)

- MR/PR von Draft auf Ready setzen:
  - **gitlab:** `glab mr update <mr-id> --ready`
  - **github:** `gh pr ready <pr-number>`
- Optional: Ticket-Kommentar (gemaess `ticket_source`): "Pipeline gruen, MR/PR bereit fuer Review"
- `status.json → log`: "Pipeline passed. MR ready: <url>"
- `exit 0`

## 6. Bei Fehlschlag (Pipeline rot) — Fix-Loop

Pipeline-Fehler muessen analysiert und gefixt werden — NICHT ignoriert.

### 6.1 Fehler analysieren

```bash
glab ci view <pipeline-id>
# Fehlgeschlagenen Job identifizieren und Logs lesen
glab ci trace <job-id>
```

Bestimme ob der Fehler **durch die neuen Aenderungen verursacht** wurde:
- Lies den `git diff` der neuen Aenderungen
- Vergleiche mit dem fehlgeschlagenen Job-Log
- Wenn der Fehler in einer Datei/Funktion liegt die im Diff vorkommt → FIX NOETIG

### 6.2 Autonomer Fix (max 3 Iterationen)

**VERBOTEN: Fehler durch .gitlab-ci.yml Aenderungen, Test-Skips, oder Ignore-Regeln "fixen".**

Fuer jeden Fix-Versuch:
1. `status.json → log`: "CI Fix Iteration X/3: <was wird gefixt>"
2. Navigiere in den Worktree
3. Fixe den Code (NICHT die CI-Config, NICHT die Tests auskommentieren)
4. Commit: `fix($KLACK_TICKET): <was gefixt wurde>`
5. Push: `git push`
6. Warte auf neue Pipeline (zurueck zu Step 4 — 60s-Polling)

### 6.3 Nach 3 gescheiterten Fix-Versuchen

Ruecksignal an Developer:
- Welcher Job schlaegt fehl?
- Was wurde in den 3 Versuchen probiert?
- Job-Log-Auszug
- Optionen: "nochmal" (3 weitere Versuche), "manuell" (Developer fixt), "abort"

### 6.4 Wenn Fehler NICHT durch neue Aenderungen verursacht

Wenn der fehlgeschlagene Job nichts mit dem Diff zu tun hat (pre-existing failure):
- Ruecksignal: "Pipeline-Fehler in <Job> scheint pre-existing (nicht durch dieses Ticket verursacht). Trotzdem fixen oder ignorieren?"
- Bei "fixen" → Fix-Loop
- Bei "ignorieren" → MR trotzdem auf Ready setzen, aber im Jira-Kommentar vermerken

## Regeln
- Pruefe MAXIMAL 30 Minuten (30 Iterationen) pro Pipeline-Run — danach Ruecksignal
- Update `status.json → log` bei JEDER Iteration
- Der MR bleibt Draft bis Pipeline gruen
- **NIEMALS** CI-Config aendern, Tests skippen, oder Ignore-Regeln hinzufuegen um Pipeline gruen zu machen
- **NIEMALS** bestehende Tests anpassen die nicht zum direkten Ticket-Kontext gehoeren — wenn ein alter Test bricht, ist das ein Code-Problem, kein Test-Problem
- Nur echte Code-Fixes sind erlaubt
- Kein BMAD-Method Skill noetig — rein Klack-spezifisch
