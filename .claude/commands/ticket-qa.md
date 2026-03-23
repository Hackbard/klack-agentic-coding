# ticket-qa — Quality Assurance

## 1. Protokoll laden

Lies zuerst vollstaendig: `commands/klack-protocol.md`

## 2. Dein Step: `qa`

Der Turmwaechter hat status.json bereits auf `running` gesetzt.

## 3. Setup

1. Lies `$KLACK_DIR/status.json` → `worktree_path`
2. Navigiere in den Worktree
3. Worktree-Verifikation (siehe Protokoll)

## 4. BMAD-Method Skill ausfuehren: Testgenerierung

Lade und befolge:

```
.claude/skills/bmad-qa-generate-e2e-tests/workflow.md
```

**Anpassungen:**
- Teste gegen die Acceptance Criteria aus `$KLACK_DIR/story.md`
- Arbeite im Worktree
- Framework-Erkennung dem BMAD-Method Workflow ueberlassen

## 5. Quality Gate Loop (max 3 Iterationen)

Nach der BMAD-Method-Testgenerierung: CI-Paritaet herstellen.

1. Lies `.gitlab-ci.yml` fuer exakte Befehle und Schwellenwerte
2. Pro Iteration:
   - PHP-CS-Fixer (OHNE `--dry-run`)
   - PHPStan (`memory_limit=1024M -vvv`)
   - PEST (`--parallel`, 95% Coverage, pcov)
3. Bei Fehlern: fixen und naechste Iteration
4. Nach 3 gescheiterten Iterationen → Ruecksignal an Developer

## 6. Abschluss

- Tests und Fixes committen
- `exit 0` → Turmwaechter setzt `done`
