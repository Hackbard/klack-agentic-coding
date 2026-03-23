# Story 10.1: Interactive-to-Autonomous Handoff

Status: ready-for-dev

## Story

As a developer using +review mode,
I want to hand off my interactive session to the autonomous pipeline,
so that the agent continues where I left off without me re-explaining the context.

## Acceptance Criteria

1. Developer types `/klack weiter` in the interactive Claude session
2. Claude writes a resume file (`$KLACK_DIR/resume.md`) with current state summary
3. Claude tells the developer to /exit
4. After /exit, the Turmwächter detects `resume.md` and starts `claude -c` autonomously
5. If no `resume.md` exists after /exit, Turmwächter proceeds to next step normally
6. If developer just /exit without `/klack weiter`, next step starts (current behavior)

## Tasks

- [ ] Create `/klack weiter` as a Claude slash command (skill)
- [ ] Turmwächter: after interactive session, check for resume.md
- [ ] If resume.md exists: `claude -c -p "Continue: $(cat resume.md)"`
- [ ] Clean up resume.md after autonomous run
