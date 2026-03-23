# Der Klack — Workflow Guide

How you actually work with this thing. Day to day. Ticket to ticket.

## The Two Modes

### Autonomous Mode (Default)

```bash
klack feat IN-1356 fix IN-2200
```

You type one command. Walk away. Come back to finished MRs with green CI.

Each ticket runs through the full pipeline — story, dev, qa, review, release, CI watch — without you touching anything. The agents use BMAD-Method workflows, create worktrees, write tests, review their own code on Opus, create draft MRs, monitor the pipeline, fix CI failures, and mark the MR as ready when green.

**When do agents ask you?**
- A Jira ticket is genuinely ambiguous (Rücksignal: question appears in Hauptturm)
- Code review found critical issues (agent blocks, asks you to decide)
- CI failed 3 times and the agent can't fix it
- Something unexpected happened (exit code != 0)

You answer in the Hauptturm by talking to the Claude command center:
> "answer IN-1356: only apply to new users, not existing ones"

### Review Mode (+review)

```bash
klack feat IN-1356+review
```

Same pipeline, but after each step the agent pauses and you get an **interactive Claude session** with the full conversation context. You can:

- Inspect what was done
- Ask questions ("why did you use this approach?")
- Make changes yourself
- Create additional artifacts (epics, specs, whatever)
- Run BMAD-Method workflows interactively

When you're done reviewing, two options:

**Option A: Just move on**
Type `/exit`. The pipeline advances to the next step. Your review is done, the agent's work stands as-is.

**Option B: Hand off to autonomous agent**
Type `/klack-next`. Claude writes a resume file with your current state — what you did, what's still open, what the next step should be. Then type `/exit`. The Turmwächter picks up the resume and starts an autonomous Claude agent that continues where you left off, with full conversation context via `claude -c`.

### Mix and Match

```bash
klack feat IN-1356+review fix IN-2200 feat IN-3000+review
```

Three tickets. IN-1356 and IN-3000 run with review pauses. IN-2200 runs fully autonomous. All in parallel.

## Life of a Ticket

Here's what happens to IN-1356 when you run `klack feat IN-1356`:

### Step 1: Story (ticket-story)

```
[IN-1356] ⠹ STORY → · DEV → · QA → · REVIEW → · RELEASE → · CI
```

- Agent reads your ticket from Jira (or GitHub, GitLab, Linear — whatever `.klack.yml` says)
- Loads the BMAD-Method `create-story` workflow
- Produces a complete, implementation-ready `story.md`
- Resolves ambiguities autonomously or asks you via Rücksignal

### Step 2: Dev (ticket-dev)

```
[IN-1356] ✓ STORY → ⠹ DEV → · QA → · REVIEW → · RELEASE → · CI
```

- Creates a git worktree: `worktree-feat/IN-1356-<slug>`
- Reads ONLY `story.md` — no Jira, no other context
- Loads the BMAD-Method `dev-story` workflow
- Implements all acceptance criteria
- Commits: `feat(IN-1356): <description>`
- Writes NO tests (that's QA's job)

### Step 3: QA (ticket-qa)

```
[IN-1356] ✓ STORY → ✓ DEV → ⠹ QA → · REVIEW → · RELEASE → · CI
```

- Loads BMAD-Method `qa-generate-e2e-tests` workflow
- Writes tests for every acceptance criterion
- Runs the quality gate loop (max 3 iterations):
  - Linter (fix, not dry-run)
  - Static analysis
  - Tests with coverage
- Fixes issues and re-runs until all pass
- After 3 failures: asks you

### Step 4: Review (ticket-review) — ON OPUS

```
[IN-1356] ✓ STORY → ✓ DEV → ✓ QA → ⠹ REVIEW → · RELEASE → · CI
```

- **Intentionally runs on Opus** (strongest model)
- **Intentionally sees ONLY the git diff** (no story, no dev history)
- Loads BMAD-Method `code-review` workflow with multi-layer adversarial analysis
- Reviews for: edge cases, security, performance, SOLID, project standards
- Non-blocking findings: noted, pipeline continues
- Critical findings: **blocks** and asks you to decide

### Step 5: Release (ticket-release)

```
[IN-1356] ✓ STORY → ✓ DEV → ✓ QA → ✓ REVIEW → ⠹ RELEASE → · CI
```

- Pushes branch
- Creates **draft** MR/PR (not ready yet — CI hasn't run)
- Posts a comment on your ticket with the MR link
- Records the MR URL in status

### Step 6: Pipeline (ticket-pipeline)

```
[IN-1356] ✓ STORY → ✓ DEV → ✓ QA → ✓ REVIEW → ✓ RELEASE → ⠹ CI
```

- Monitors your CI pipeline every 60 seconds
- Pipeline green → marks MR as ready (removes draft)
- Pipeline red → analyzes the failure:
  - Is it caused by our changes? → **Fix the code** (NOT the tests, NOT the CI config)
  - Push, watch new pipeline
  - Max 3 fix attempts, then asks you
  - Pre-existing failure? → Asks you whether to fix or ignore

**What's NEVER allowed in the fix loop:**
- Changing CI configuration
- Skipping or disabling tests
- Adding ignore rules
- Modifying tests that aren't related to this ticket

If an old test breaks because of new code, that's a code problem. Fix the code.

## The Hauptturm (Command Center)

Window 0 in your tmux session. Has three zones:

**Top:** Header with animated status bar (rainbow in unicorn mode, red scanner in cylon mode)

**Middle:** Activity log + ticket status cards showing the pipeline progress

**Bottom:** Interactive Claude session. Talk to it naturally:

| You say | What happens |
|---------|-------------|
| "wie läuft's?" | Shows status of all tickets |
| "gibt es Fragen?" | Checks all tickets for pending questions |
| "was macht IN-1356?" | Reads that ticket's status.json + last log entries |
| "answer IN-1356: nur neue User" | Writes answer, clears waiting flag |
| "add feat IN-3000" | Adds new ticket to running session |
| "error IN-1356" | Shows full error log |
| "theme cylon" | Switches to Cylon color scheme |
| "kill alles" | Stops everything |
| "neustart IN-1356" | Kills and restarts that ticket |

## The /klack-next Handoff

This is the bridge between interactive work and autonomous execution.

**Scenario:** You're in a `+review` session after the story step. You realize the story needs more work — you start creating epics, discussing architecture, writing specs. After 20 minutes of interactive work, you've got a solid plan but don't want to finish the implementation manually.

**What you do:**

```
> /klack-next
```

Claude analyzes your conversation, writes a resume file:

```markdown
# Resume: Autonome Weiterarbeit

## Was wurde gemacht
- Epic 3 Architektur diskutiert und entschieden
- story.md um technische Constraints ergaenzt
- Neues Acceptance Criterion hinzugefuegt

## Was noch offen ist
- Implementation der geaenderten Story
- Tests muessen die neuen ACs abdecken

## Naechster Schritt
Implementiere die aktualisierte story.md im Worktree.
Beachte: Das neue AC #4 erfordert eine Migration.
```

Then tells you to `/exit`. You do. The Turmwächter sees the resume file, starts `claude -c` (continue — same conversation context!) with the resume as instruction. The agent picks up exactly where you left off and works autonomously.

**What if you just `/exit` without `/klack-next`?**
Normal behavior. Pipeline moves to the next step. Your interactive work is preserved in the conversation history but the agent doesn't try to "continue" anything.

**What if you were just chatting, not doing real work?**
Don't use `/klack-next`. Just `/exit`. The pipeline doesn't know or care what you discussed — it moves to the next step based on the files on disk.

## Resuming After Interruption

Power outage? Terminal crashed? Just run again:

```bash
cd /path/to/project
klack
```

No arguments → reads `.klack/session.json` → restores. The Turmwächter checks each ticket's `status.json`:

- `complete/done` → skip, nothing to do
- `release/done` → skip to pipeline step
- `qa/error` → restart from qa
- `dev/running` → restart from dev
- `init/pending` → start from beginning

The filesystem is the truth. Nothing is lost.

## Watching Agents Work

Switch to a ticket's tmux window to see the raw Claude output:

```
Ctrl-b 1    ← Window 1 (first ticket)
Ctrl-b 2    ← Window 2 (second ticket)
Ctrl-b 0    ← Back to Hauptturm
```

Or ask the Hauptturm: "was macht IN-1356 gerade?" — it reads `status.json` and the agent output log.

## Multiple Tickets, Real Parallelism

Each ticket gets:
- Its own tmux window
- Its own git worktree (isolated filesystem)
- Its own `.klack/signale/{TICKET}/` directory
- Its own Turmwächter process
- Its own Claude agents (one per step, sequential within ticket)

Tickets run in parallel, steps run sequentially within a ticket. No conflicts, no shared state, no race conditions.

```
Window 0: Hauptturm (you)
Window 1: IN-1356 → story ✓ → dev ⠹ → qa · → ...
Window 2: IN-2200 → story ✓ → dev ✓ → qa ✓ → review ⠹ → ...
Window 3: IN-3000 → story ⠹ → ...
```

## Configuration Cheat Sheet

**`.klack.yml`** in your project root:

```yaml
ticket_source: jira       # jira | github | gitlab | linear | markdown
pr_tool: gitlab            # gitlab | github
pr_target_branch: develop  # main | develop | whatever
ci_tool: gitlab            # gitlab | github
qa_ci_config: .gitlab-ci.yml
```

**`.mcp.json`** in your project root — MCP servers your agents need:

```json
{
  "mcpServers": {
    "your-tool": {
      "command": "your-command",
      "args": ["--your-flags"]
    }
  }
}
```

**Themes:** unicorn (default), cylon, kitt, shufflepuck, monochrome
Switch with: tell the Hauptturm "theme <name>"

---

*"A man is not dead while his name is still spoken."*
*The overhead. GNU Terry Pratchett.*
