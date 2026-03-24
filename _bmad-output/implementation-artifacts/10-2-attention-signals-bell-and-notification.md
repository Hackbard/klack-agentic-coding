# Story 10.2: Attention Signals — Bell & macOS Notification

Status: review

## Story

**As a** developer running parallel Klack pipelines,
**I want** to receive a terminal bell and macOS notification when an agent needs my attention,
**so that** I notice questions, failures, and interactive prompts without constantly watching the status pane.

## Acceptance Criteria

### AC1: Terminal Bell on Waiting
- [x] When any Turmwächter enters `waiting` state (writes `waiting.flag`), a terminal bell (`\a`) is triggered
- [x] The bell fires once when entering wait state, not repeatedly every poll cycle
- [x] The bell works regardless of which tmux window/pane is focused

### AC2: macOS Notification on Waiting
- [x] When any Turmwächter enters `waiting` state, a macOS notification is sent via `osascript`
- [x] Notification title: "Klack — {TICKET}"
- [x] Notification body includes: ticket ID and first line of `question.txt`
- [x] If `osascript` is not available (Linux), the notification is silently skipped
- [x] Notification fires once per wait event, not repeatedly

### AC3: Bell on Step Failure
- [x] When `ask_on_failure()` is called, a terminal bell is triggered before entering the poll loop
- [x] macOS notification is sent with ticket ID, failed step name, and exit code

### AC4: Bell After Interactive Step Exit
- [x] When an interactive `claude -c` session ends and the Turmwächter needs a decision, a bell is triggered
- [x] macOS notification: "Klack — {TICKET}: Interaktiver Step beendet. Entscheidung noetig."

### AC5: No Spam
- [x] Bell fires maximum once per state transition (entering wait, not during wait)
- [x] No bell during normal autonomous operation
- [x] No notification during normal autonomous operation

## Tasks

- [x] Create `notify_attention()` helper function in `ticket-run.sh`
  - Parameters: `title` and `body`
  - Sends terminal bell: `printf '\a'`
  - Sends macOS notification: `osascript -e "display notification \"$body\" with title \"$title\""` (skip if osascript missing)
  - Log the notification to activity.log
- [x] Call `notify_attention` in `check_waiting()` — once on first detection of `waiting.flag`, before entering the poll loop
- [x] Call `notify_attention` in `ask_on_failure()` — once when writing `question.txt`, before entering the poll loop
- [x] Call `notify_attention` after interactive `claude -c` exits in `--review` mode, before the "autonom weiter?" prompt
- [x] Verify bell fires only once per event (not every 5-second poll cycle)

## Dev Agent Record

### Implementation Plan
Single function `notify_attention()` added to helpers section of ticket-run.sh. Called from 3 locations: check_waiting (before poll loop), ask_on_failure (after writing waiting.flag), and --review mode (after claude -c exits).

### Completion Notes
- `notify_attention()` at line 56: printf '\a' + osascript with `command -v` guard
- `check_waiting()` at line 67: if-block before while-loop ensures single fire
- `ask_on_failure()` at line 108: after touch waiting.flag, before while-loop
- Review mode at line 310: after claude -c exit, before resume.md check
- All calls are outside poll loops — guaranteed single fire per event

### Debug Log
No issues encountered.

## File List

- `lib/scripts/ticket-run.sh` (modified — added notify_attention helper, 4 call sites)

## Change Log

- 2026-03-24: Implemented attention signals. Bell + macOS notification at 3 trigger points. Single-fire guaranteed.

## Dev Notes

- `check_waiting()` currently enters a `while` loop with `sleep 5`. The bell must fire BEFORE the loop, not inside it.
- `ask_on_failure()` already writes `question.txt` and `waiting.flag` before its poll loop — add notification after writing these files.
- `printf '\a'` sends BEL character — tmux propagates this to the terminal, which may flash the tab or play a sound depending on terminal settings.
- `osascript` is macOS-only. Guard with `command -v osascript &>/dev/null` before calling.
- For the interactive step exit notification (AC4): this touches the `--review` mode block of `ticket-run.sh`. The notification goes after `claude -c` exits but before checking for `resume.md`.
- Keep the helper function simple — no dependencies, no external tools beyond osascript.
