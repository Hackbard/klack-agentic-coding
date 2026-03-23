# Integrating Your Tools with Der Klack

This guide is for AI agent developers who want to connect their own ticket systems, CI tools, MCP servers, or custom pipeline steps to Der Klack.

## How Agents Discover Tools

Every Claude agent process in Der Klack automatically discovers MCP servers from three sources (merged at startup):

1. **Your project's `.mcp.json`** — project-specific tools (e.g., laravel-boost, database access)
2. **Your Claude plugin cache** (`~/.claude/plugins/cache/`) — globally installed plugins (Playwright, Atlassian, etc.)
3. **User-level `.mcp.json`** (`~/.claude/.mcp.json`) — personal tool configurations

The Turmwächter merges all three into a single config file and passes it to every agent via `--mcp-config`. You don't need to configure anything per-agent.

### Adding a Project MCP Server

Create `.mcp.json` in your project root:

```json
{
  "mcpServers": {
    "my-database": {
      "command": "node",
      "args": ["./tools/db-mcp-server.js"]
    },
    "my-api": {
      "type": "http",
      "url": "https://internal-api.company.com/mcp",
      "headers": {
        "Authorization": "Bearer ${MY_API_TOKEN}"
      }
    }
  }
}
```

All agents will have access to these tools immediately.

## Connecting a Ticket System

### Step 1: Configure `klack.yaml`

```yaml
ticket_source: your-system
```

### Step 2: Edit `ticket-story.md`

Add your system under "## 3. Ticket einlesen":

```markdown
- **your-system**: Use your-tool MCP → `your_tool__getTicket` with KLACK_TICKET
```

Or if it's CLI-based:
```markdown
- **your-system**: `your-cli ticket view KLACK_TICKET --format json`
```

Or if tickets are files:
```markdown
- **your-system**: Read `tickets/KLACK_TICKET.md` from project root
```

### Step 3: Edit `ticket-release.md`

Add comment posting for your system under "## 5. Ticket-Kommentar":

```markdown
- **your-system**: Use your-tool MCP → `your_tool__addComment`
```

That's it. The rest of the pipeline (implementation, testing, review) doesn't care where the ticket came from — it works from `story.md`.

## Connecting a CI System

### Step 1: Configure `klack.yaml`

```yaml
ci_tool: your-ci
```

### Step 2: Edit `ticket-pipeline.md`

Add your CI under "## 4. Pipeline ueberwachen":

```markdown
**your-ci:**
\```bash
your-ci-cli pipeline status --branch <branch>
your-ci-cli pipeline logs <pipeline-id>
\```
```

And under "## 5. Bei Erfolg":

```markdown
- **your-ci:** `your-ci-cli mr ready <mr-id>` (or equivalent)
```

## Connecting a PR/MR System

### Step 1: Configure `klack.yaml`

```yaml
pr_tool: your-forge
pr_target_branch: main
```

### Step 2: Edit `ticket-release.md`

Add your forge under "## 4. Branch pushen & MR/PR erstellen":

```markdown
**your-forge:**
\```bash
your-forge-cli pr create \
  --title "Draft: $KLACK_TYPE($KLACK_TICKET): <title>" \
  --target main \
  --draft
\```
```

## Adding Custom Pipeline Steps

### Step 1: Add to `ticket-run.sh`

Edit the `STEPS` array:

```bash
STEPS=(story dev qa review release pipeline your-step)
```

### Step 2: Create the Command File

Create `commands/ticket-your-step.md`:

```markdown
# ticket-your-step — Your Custom Step

## 1. Protokoll laden

Lies zuerst vollstaendig: `commands/klack-protocol.md`

## 2. Dein Step: `your-step`

Der Turmwaechter hat status.json bereits auf `running` gesetzt.

## 3. Do Your Thing

[Your instructions here]

## 4. Abschluss

- `exit 0` → Turmwaechter setzt `done`
- Bei Fehler → error.log + `exit 1`
```

### Step 3: Install

Run `./install.sh /path/to/project` again, or manually copy the file to `.claude/commands/`.

## Replacing BMAD-Method Skills

Each pipeline step loads a BMAD-Method skill for its core logic. You can replace these with your own:

| Step | Default BMAD-Method Skill | Replace With |
|------|-------------------|-------------|
| story | `bmad-create-story` | Your story/spec creation workflow |
| dev | `bmad-dev-story` | Your implementation workflow |
| qa | `bmad-qa-generate-e2e-tests` | Your test generation workflow |
| review | `bmad-code-review` | Your code review workflow |

To replace, edit the corresponding `ticket-{step}.md` and change the skill path:

```markdown
## 4. BMAD-Method Skill ausfuehren

Lade und befolge:
\```
.claude/skills/your-custom-skill/workflow.md
\```
```

## The Communication Protocol

All agents follow the Klack Protocol (`commands/klack-protocol.md`). Key concepts:

### Status Reporting

Agents update `$KLACK_DIR/status.json` → `log` field frequently. This is the only way the Hauptturm knows what's happening. Good agents log often:

```
"Reading ticket..."
"Found 3 acceptance criteria"
"Creating worktree..."
"Implementing UserController"
"PHPStan: 2 errors, fixing..."
```

### Rücksignal (Asking the Developer)

When an agent needs human input:

```
1. Write question.txt          ← the question
2. Update status.json → waiting ← mark as blocked
3. Touch waiting.flag           ← MUST BE LAST (this is the trigger)
```

The Hauptturm detects the flag, shows the question, developer answers, flag is removed, agent continues.

### Exit Codes

- `exit 0` → Turmwächter marks step as `done`, advances to next step
- `exit 1` → Turmwächter marks step as `error`, asks developer: retry/skip/abort

The agent does NOT write `done` or `error` to status.json — the Turmwächter does.

## Architecture for Non-Claude Agents

The orchestration layer (bash scripts, tmux, filesystem message bus) is AI-agnostic. To use a different AI:

1. Replace `claude ... -p "$prompt"` in `ticket-run.sh` with your AI's CLI invocation
2. Rewrite the command files (`ticket-{step}.md`) for your AI's prompt format
3. Keep the Klack Protocol structure — status.json, Rücksignal, and worktree verification work with any AI that can read/write files

The Hauptturm (command center) currently requires Claude CLI, but could be replaced with any interactive AI that understands the protocol.
