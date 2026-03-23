---
name: klack-next
description: Hand off to the autonomous Klack agent. Writes current state into a resume file so the Turmwaechter can continue autonomously.
---

You are in an interactive Klack review session. The developer wants you to continue autonomously from here.

## What you need to do:

### 1. Summarize current state

Analyze the conversation so far and write a precise resume file. Find `KLACK_DIR` from the system prompt or environment.

If KLACK_DIR is unknown: search for `.klack/signale/*/status.json` in the current directory and identify the active ticket.

### 2. Write resume file

Write to `$KLACK_DIR/resume.md`:

```markdown
# Resume: Autonomous Continuation

## What was done
- [List of completed work from the interactive session]

## What is still open
- [List of remaining tasks]

## Current state
- [Which files were created/changed]
- [Which branch, which worktree]
- [Open items]

## Next step
[Concrete instructions for what the autonomous agent should do next]
```

### 3. Inform the developer

Tell the developer:

```
Resume file written. The Turmwaechter will continue autonomously where you left off.

Type /exit now to end the session. The autonomous agent starts automatically after that.
```

### Important
- Be PRECISE in the resume file — the autonomous agent has NO context besides this file and the conversation history via `claude -c`
- List concretely which files were touched
- Describe the next step so an agent can execute it without follow-up questions
