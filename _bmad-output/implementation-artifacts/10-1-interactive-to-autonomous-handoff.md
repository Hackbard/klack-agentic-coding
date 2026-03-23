# Story 10.1: Interactive-to-Autonomous Handoff

Status: done

## Story

As a developer using +review mode,
I want to hand off my interactive session to the autonomous pipeline,
so that the agent continues where I left off without me re-explaining the context.

## Acceptance Criteria

1. Developer types `/klack next` in the interactive Claude session
2. Claude writes a resume file (`$KLACK_DIR/resume.md`) with current state summary
3. Claude tells the developer to /exit
4. After /exit, the Turmwächter detects `resume.md` and starts `claude -c` autonomously
5. If no `resume.md` exists after /exit, Turmwächter proceeds to next step normally
6. If developer just /exit without `/klack next`, next step starts (current behavior)

## Tasks

- [x] Create `/klack next` as a Claude slash command (skill)
- [x] Turmwächter: after interactive session, check for resume.md
- [x] If resume.md exists: `claude -c -p "Continue: $(cat resume.md)"`
- [x] Clean up resume.md after autonomous run

## Dev Agent Record

### Implementation Plan
All tasks were already implemented prior to story creation.

### Completion Notes
- All 4 tasks verified as complete by code inspection (2026-03-23)
- `/klack-next` skill exists at `.claude/skills/klack-next/SKILL.md`
- Turmwächter resume detection implemented in `lib/scripts/ticket-run.sh` lines 295-345
- Resume cleanup at lines 297 (before interactive session) and 315 (after reading)
- Error handling for failed autonomous continuation at lines 332-341

### Debug Log
No issues — implementation pre-existed story creation.

## File List

- `.claude/skills/klack-next/SKILL.md` (existing, verified)
- `lib/scripts/ticket-run.sh` (existing, verified — lines 295-345)

## Change Log

- 2026-03-23: Story verified as already implemented. All ACs satisfied. Marked done.
