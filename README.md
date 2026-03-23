# ⚡ klack

**Parallel agentic coding. One command to orchestrate them all.**

```bash
klack feat IN-2262 fix IN-2200 feat IN-3000
```

Three tickets start processing simultaneously. Each one runs through the full development lifecycle — story analysis, implementation, testing, code review, release, CI monitoring — completely autonomously. You sit in the command center, watch the towers work, and intervene only when it matters.

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ ⚡ DER KLACK │ 3 Tuerme  ▶ 2  ✓ 1  │ 14:32  [unicorn]              ┃
┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┃
┃ Activity Log                    ┃ ┌─ IN-2262   ▶ running            ┃
┃                                 ┃ │  [✓ STORY][⠹ DEV  ][· QA   ]   ┃
┃ 14:31 [IN-2262] Worktree...    ┃ │  Implementing controller...     ┃
┃ 14:32 [IN-2200] ✓ QA passed    ┃ └──────────────────────────────   ┃
┃ 14:32 [IN-3000] Reading Jira   ┃ ┌─ IN-2200   ✓ DONE              ┃
┃ 14:33 [IN-2262] Committing...  ┃ │  [✓ STORY][✓ DEV ][✓ QA   ]   ┃
┃                                 ┃ │  Release complete. MR: ...      ┃
┃                                 ┃ └──────────────────────────────   ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ Claude › wie läuft's?                                               ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

## What This Is

Der Klack is a **tmux-based orchestration layer** that runs multiple Claude Code agents in parallel — each processing a ticket through a complete, audited development pipeline:

```
ticket-story → ticket-dev → ticket-qa → ticket-review → ticket-release → ticket-pipeline
  Read ticket    Implement    Write tests   Code review    Create MR       Watch CI
  Write story    in worktree  Quality gate  (on Opus!)     Post comment    Fix failures
                 Commit       CI parity     Block if bad   Draft → Ready   Auto-retry
```

**Every step is a fresh Claude process.** Clean context, no bleed-over, no hallucinated state from three steps ago. Each agent loads the Klack Protocol (how to communicate) and a BMAD-Method skill (what to do). The Turmwächter orchestrates — starts, monitors, retries, asks you when stuck.

## Why This Exists

AI coding agents are powerful one-at-a-time. But real work is parallel — you have 5 tickets in a sprint, not 1. And shipping code isn't just "write it" — it's story → implement → test → review → release → verify CI. Every step matters. Skip one and you ship garbage.

Der Klack gives you:

- **True parallelism.** 3 tickets, 3 tmux windows, 3 independent Claude agents. Each in its own git worktree. No conflicts.
- **A real pipeline.** Nothing ships without tests. Nothing ships without review. Nothing ships without green CI. The pipeline enforces this.
- **The [BMAD-Method](https://github.com/bmad-code-org/BMAD-METHOD/) on steroids.** The BMAD-Method is a structured AI-agent workflow framework that turns chaotic AI coding into disciplined, repeatable processes — from product brief to production code. Klack takes every BMAD-Method workflow and runs it autonomously at scale: `bmad-create-story` for story analysis, `bmad-dev-story` for implementation, `bmad-code-review` for multi-layer adversarial review. No improvised prompts. Battle-tested workflows. The framework does the thinking, Klack does the orchestration.
- **A command center, not a black box.** The Hauptturm shows you everything — which ticket is where, what's running, what's waiting. A live Claude session at the bottom where you talk naturally: "how's it going?", "answer IN-2262: only new users", "add feat IN-3000".
- **Error recovery, not error hiding.** When CI breaks, the pipeline agent analyzes the failure, fixes the code (not the tests, not the CI config), pushes, and watches again. Max 3 attempts, then it asks you. No silent failures. No ignored tests.

## Quick Start

### Prerequisites

- `tmux` (3.2+ recommended)
- `claude` CLI (authenticated)
- `glab` or `gh` (for MR/PR creation)
- A ticket system (Jira, GitHub Issues, GitLab Issues, Linear, or local markdown)

### Install

```bash
npm install -g klack
```

Or without installing:

```bash
npx klack feat TICKET-1
```

### Configure

In your project directory:

```bash
klack init
```

This creates `.klack.yml` — the only file you commit. Edit it:

```yaml
# .klack.yml
ticket_source: jira          # jira | github | gitlab | linear | markdown
pr_tool: gitlab               # gitlab | github
pr_target_branch: develop      # target branch for MRs/PRs
ci_tool: gitlab                # gitlab | github
qa_ci_config: .gitlab-ci.yml  # your CI config file
```

### Run

```bash
cd /path/to/your/project

# Process tickets autonomously (default)
klack feat TICKET-1 fix TICKET-2

# With interactive review after each step
klack feat TICKET-1+review

# Mix: one autonomous, one with review
klack feat TICKET-1 fix TICKET-2+review
```

### Inside the Session

You land in the **Hauptturm** — a tmux pane layout with status display, activity log, and a Claude chat session. Talk to it naturally:

- "wie läuft's?" — status of all tickets
- "gibt es Fragen?" — checks for pending questions from agents
- "answer IN-2262: only new users" — answers an agent's question
- "add feat IN-3000" — adds a new ticket to the running session
- "theme cylon" — switches to the Cylon color scheme (yes, really)
- "kill alles" — stops everything

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  klack.sh                                               │
│  Entrypoint: parse args, create tmux session,           │
│  start one Turmwächter per ticket                       │
├──────────┬──────────┬──────────┬────────────────────────┤
│ Window 0 │ Window 1 │ Window 2 │ Window 3              │
│ Hauptturm│ IN-2262  │ IN-2200  │ IN-3000               │
│ (you)    │ (agent)  │ (agent)  │ (agent)               │
├──────────┴──────────┴──────────┴────────────────────────┤
│  .klack/signale/{TICKET}/                               │
│  Filesystem message bus — status.json, story.md,        │
│  review.md, question.txt, answer.txt, waiting.flag      │
└─────────────────────────────────────────────────────────┘
```

**No sockets. No IPC. No databases.** All communication happens through files in `.klack/signale/`. Every agent reads and writes to its ticket's directory. The Turmwächter polls `status.json`. The Hauptturm displays what's in the files. Simple, debuggable, resilient.

**Each agent is a fresh Claude process** that loads:

1. **Klack Protocol** (`klack-protocol.md`) — how to communicate (status.json, Rücksignal, worktree verification)
2. **Step Command** (`ticket-{step}.md`) — what to do, which BMAD-Method skill to load
3. **BMAD-Method Skill** (loaded by the command) — the actual workflow logic
4. **Ticket Context** (injected by Turmwächter) — KLACK_TICKET, KLACK_TYPE, KLACK_DIR

## The Pipeline in Detail

| Step | Agent | Model | What Happens |
|------|-------|-------|-------------|
| **story** | ticket-story | Sonnet | Reads ticket from your tracker. Runs `bmad-create-story` workflow. Produces implementation-ready `story.md`. |
| **dev** | ticket-dev | Sonnet | Creates git worktree. Runs `bmad-dev-story` workflow. Implements all acceptance criteria. Commits. |
| **qa** | ticket-qa | Sonnet | Runs `bmad-qa-generate-e2e-tests`. Then quality gate loop: linter → static analysis → tests. Max 3 iterations. |
| **review** | ticket-review | **Opus** | Runs `bmad-code-review` with multi-layer adversarial review. Only sees the diff — blind review. Blocks on critical findings. |
| **release** | ticket-release | Sonnet | Pushes branch. Creates draft MR/PR. Posts ticket comment. |
| **pipeline** | ticket-pipeline | Sonnet | Monitors CI every 60s. Pipeline fails → analyzes, fixes code (NOT tests/CI config), pushes, watches again. Pipeline green → MR ready. |

**The review step runs on Opus intentionally.** Fresh context, strongest model, sees only the diff. No familiarity bias from the implementation agent.

## Error Philosophy

When something breaks, Der Klack doesn't silently continue or hack around it:

1. **Agent fails →** Turmwächter shows you the last 20 lines of output + asks: retry / skip / abort
2. **CI fails →** Pipeline agent analyzes the diff vs the failure, fixes the code, pushes, watches again
3. **3 fix attempts fail →** Asks you what to do
4. **Never allowed:** Changing CI config, skipping tests, adding ignore rules, modifying tests that aren't related to the ticket

If an old test breaks because of your new code, that's a code problem — fix the code, not the test.

## Themes

Because work should look good.

| Theme | Vibe |
|-------|------|
| `unicorn` (default) | Rainbow — each ticket gets its own color from the spectrum |
| `cylon` | Dark industrial with red scanner sweep (BSG Cylon eye) |
| `kitt` | KITT dashboard — amber on black with red scanner block |
| `shufflepuck` | Neon arcade (Shufflepuck Café 1989 energy) |
| `monochrome` | Green phosphor on black. For the purists. |

Switch anytime: tell the Hauptturm "theme cylon".

## For AI Agent Developers: Connecting Your Tools

Der Klack is tool-agnostic. The agents discover MCP servers automatically from your Claude plugin cache and project `.mcp.json`. But if you want to connect custom tools:

### Adding MCP Servers

Create or edit `.mcp.json` in your project root:

```json
{
  "mcpServers": {
    "your-tool": {
      "command": "npx",
      "args": ["your-mcp-server"]
    },
    "your-api": {
      "type": "http",
      "url": "https://your-api.com/mcp"
    }
  }
}
```

Every agent process automatically picks this up — no per-agent configuration needed.

### Adding a Ticket Source

1. Set `ticket_source: your-system` in `.klack.yml`
2. Edit `commands/ticket-story.md` — add a section for your system under "## 3. Ticket einlesen"
3. Edit `commands/ticket-release.md` — add comment posting for your system under "## 5. Ticket-Kommentar"

The agent reads `.klack.yml` and follows the branch for your system. Everything else (story creation, implementation, testing, review) is ticket-source-agnostic.

### Adding a CI System

1. Set `ci_tool: your-ci` in `.klack.yml`
2. Edit `commands/ticket-pipeline.md` — add CLI commands for checking pipeline status and retrying

### Custom BMAD-Method Skills

The agents load BMAD-Method skills from `.claude/skills/`. To customize:

- **Story creation:** Edit or replace `.claude/skills/bmad-create-story/`
- **Implementation:** Edit or replace `.claude/skills/bmad-dev-story/`
- **Test generation:** Edit or replace `.claude/skills/bmad-qa-generate-e2e-tests/`
- **Code review:** Edit or replace `.claude/skills/bmad-code-review/`

Each command file (`ticket-{step}.md`) references its BMAD-Method skill by path. Change the path, change the skill.

### The Klack Protocol

Every agent loads `commands/klack-protocol.md` as its first context. This teaches the agent:

- Where files live (`KLACK_DIR`)
- How to report status (`status.json`)
- How to ask the developer questions (Rücksignal: `question.txt` → `waiting.flag`)
- How to verify it's in a worktree
- How to generate branch names

If you're building a custom step, read the protocol. Follow it. The Turmwächter depends on it.

## Project Structure

```
your-project/
├── klack.sh                          ← Run this
├── .klack.yml                        ← Your config
├── .mcp.json                         ← MCP servers
├── .claude/
│   └── commands/
│       ├── klack-protocol.md         ← Agent communication protocol
│       ├── hauptturm.md              ← Command center Claude prompt
│       ├── ticket-story.md           ← Step 1: Story analysis
│       ├── ticket-dev.md             ← Step 2: Implementation
│       ├── ticket-qa.md              ← Step 3: Quality assurance
│       ├── ticket-review.md          ← Step 4: Code review
│       ├── ticket-release.md         ← Step 5: Release
│       └── ticket-pipeline.md        ← Step 6: CI monitoring
└── .klack/
    ├── scripts/
    │   ├── ticket-run.sh             ← Turmwächter (step orchestrator)
    │   └── hauptturm/                ← Pane scripts (header, log, status, etc.)
    ├── signale/{TICKET}/             ← Runtime state (gitignored)
    ├── activity.log                  ← Event log (gitignored)
    └── session.json                  ← Session state (gitignored)
```

## Powered by the BMAD-Method

Klack doesn't invent its own AI workflows. It stands on the shoulders of the **[BMAD-Method](https://github.com/bmad-code-org/BMAD-METHOD/)** — a battle-tested framework for structured AI-agent development.

**What the BMAD-Method gives you:**

- **Structured story creation** — not "write code for this ticket" but a multi-step workflow that analyzes requirements, identifies gaps, resolves ambiguities, and produces implementation-ready specs with acceptance criteria
- **Disciplined implementation** — the dev agent follows a checklist, not vibes. Every acceptance criterion gets implemented, every task gets checked off
- **Adversarial code review** — three independent review layers (Blind Hunter, Edge Case Hunter, Acceptance Auditor) that catch what a single-pass review misses
- **Test generation from acceptance criteria** — not random test coverage, but tests that verify exactly what the story promised

**What Klack adds on top:**

- Parallel execution across multiple tickets
- tmux-based orchestration with visual status
- Filesystem message bus for agent communication
- Automatic CI monitoring and fix loops
- Interactive ↔ autonomous handoff (`/klack-next`)

Without BMAD-Method, each agent would need its own prompt engineering. With it, you get proven workflows out of the box. Klack just runs them faster and in parallel.

**Install BMAD-Method skills:**
```bash
# BMAD-Method skills are included with klack
# Or install separately: https://github.com/bmad-code-org/BMAD-METHOD/
```

## FAQ

**Q: Can I run this with Gemini/GPT instead of Claude?**
A: The orchestration (bash scripts, tmux) is AI-agnostic. The command files and protocol are Claude-specific (Claude CLI, MCP, BMAD-Method skills). You'd need to adapt the agent invocation in `ticket-run.sh` and rewrite the command files for your AI's interface.

**Q: What if I don't use BMAD-Method?**
A: Replace the BMAD-Method skill references in the command files with your own instructions. The command files are just markdown prompts — put whatever workflow you want in there.

**Q: Can I add custom pipeline steps?**
A: Yes. Add the step name to the `STEPS` array in `ticket-run.sh`, create `commands/ticket-{step}.md`, done.

**Q: What if a ticket needs human work mid-pipeline?**
A: Use `+review` mode: `klack feat IN-2262+review`. After each step, you get an interactive Claude session with full context. Do your thing, `/exit`, pipeline continues.

**Q: Does it work with monorepos?**
A: Each ticket gets its own git worktree. As long as your tooling works in worktrees, Klack works in monorepos.

---

*Named after the Clacks towers from Terry Pratchett's Discworld — a network of semaphore towers that relay messages across the continent. Each tower passes the message to the next. The message is the medium.*

*GNU Terry Pratchett*
