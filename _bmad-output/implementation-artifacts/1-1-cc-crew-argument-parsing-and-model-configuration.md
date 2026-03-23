# Story 1.1: Argument-Parsing and Model Configuration

Status: done

## Story

As a developer,
I want to call `klack.sh feat IN-2262 fix IN-2200` with ticket type and IDs,
so that the system validates my input and sets the correct model environment before anything starts.

## Acceptance Criteria

1. **Given** the developer calls `klack.sh` with valid ticket type(s) (`feat`/`fix`/`hot`) and ticket ID(s)
   **When** the script starts
   **Then** `ANTHROPIC_MODEL` is exported (Sonnet), `CLAUDE_CODE_SUBAGENT_MODEL` is exported (Haiku), and the Opus model variable for the review step is exported

2. **Given** the developer calls `klack.sh` with an invalid ticket type (not `feat`/`fix`/`hot`)
   **When** the script starts
   **Then** an error message is shown to stderr and the script exits with code 1

3. **Given** the developer calls `klack.sh` with no arguments
   **When** the script starts
   **Then** a usage hint is displayed to stderr and the script exits with code 1

4. **Given** the developer provides multiple ticket type+ID pairs (e.g., `feat IN-2262 fix IN-2200`)
   **When** the script parses arguments
   **Then** each pair is stored as a tuple of (type, ticket-id) for downstream processing

## Tasks / Subtasks

- [ ] Task 1: Create `klack.sh` entrypoint script (AC: #1, #2, #3, #4)
  - [ ] 1.1: Script header with `#!/usr/bin/env bash` and `set -euo pipefail`
  - [ ] 1.2: Argument validation — reject zero args with usage hint (AC #3)
  - [ ] 1.3: Argument parsing loop — consume pairs of `<type> <ticket-id>` (AC #4)
  - [ ] 1.4: Type validation — only `feat`, `fix`, `hot` are valid (AC #2)
  - [ ] 1.5: Export model environment variables (AC #1)
  - [ ] 1.6: Store parsed tickets in arrays for downstream use

## Dev Notes

### Naming: klack, NOT cc-crew

The architecture document is authoritative: **"The tool is named klack (not cc-crew). All scripts, commands, and references use this name."** The entrypoint script is `klack.sh`.
[Source: _bmad-output/planning-artifacts/architecture.md#Tool Name]

### Script Location

The file to create is: `klack.sh` (project root of the klack repository).
After installation via `install.sh`, it lives at `<target-project>/klack.sh` and is executable.
[Source: _bmad-output/planning-artifacts/architecture.md#klack Repository Structure]

### Bash Script Style (Mandatory Pattern 4)

All shell scripts MUST begin with:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

Rules:
- Always double-quote variables: `"$KLACK_TICKET"` not `$KLACK_TICKET`
- Errors go to stderr: `echo "ERROR: ..." >&2`
- Exit codes: `exit 1` on error, `exit 0` on success
[Source: _bmad-output/planning-artifacts/architecture.md#Pattern 4: Bash Script Style]

### Model Configuration (NFR7)

Environment variables to export:
- `ANTHROPIC_MODEL` → Sonnet model (for main agents in steps story/dev/qa/release)
- `CLAUDE_CODE_SUBAGENT_MODEL` → Haiku model (for sub-agents within Claude processes)
- `KLACK_REVIEW_MODEL` → Opus model (used by ticket-run.sh to override ANTHROPIC_MODEL for the review step only)

These are set once by `klack.sh` and inherited by all child processes. No per-step configuration.
[Source: _bmad-output/planning-artifacts/architecture.md#Cross-Cutting Concerns Identified, item 4]
[Source: _bmad-output/planning-artifacts/epics.md#NFR7]

**Important:** Do NOT hardcode model IDs. Use environment variable names that ticket-run.sh will read. The actual model IDs (e.g., `claude-sonnet-4-6`) should be set as defaults but overridable if the user has already set them.

### Argument Parsing Design

Arguments are positional pairs: `<type> <ticket-id> [<type> <ticket-id> ...]`

Examples:
- `./klack.sh feat IN-2262` — single ticket
- `./klack.sh feat IN-2262 fix IN-2200` — two tickets
- `./klack.sh feat IN-2262 fix IN-2200 hot IN-2199` — three tickets

Each pair produces:
- A ticket type (`feat`, `fix`, or `hot`)
- A ticket ID (any string, typically `IN-XXXX` format)

Store in parallel arrays: `KLACK_TYPES=()` and `KLACK_TICKETS=()` so that `${KLACK_TYPES[i]}` corresponds to `${KLACK_TICKETS[i]}`.

### Usage Hint Format

When no args or invalid args are provided, show:
```
Usage: klack.sh <type> <ticket-id> [<type> <ticket-id> ...]
Types: feat, fix, hot
Example: klack.sh feat IN-2262 fix IN-2200
```

### What This Story Does NOT Do

This story ONLY handles argument parsing and model configuration. It does NOT:
- Create tmux sessions (Story 1.2)
- Create `.klack/signale/` directories (Story 1.3)
- Start the Turmwaechter (Story 1.4)
- Handle session restore (Story 1.6)

After this story, `klack.sh` will parse args, export env vars, and have the ticket arrays ready. Stories 1.2+ will extend this script.

### Downstream Contract

The following variables MUST be available after this story's code runs, for Stories 1.2-1.7 to consume:
- `KLACK_TYPES` array — ticket types in order
- `KLACK_TICKETS` array — ticket IDs in order
- `ANTHROPIC_MODEL` — exported env var
- `CLAUDE_CODE_SUBAGENT_MODEL` — exported env var
- `KLACK_REVIEW_MODEL` — exported env var (or similar name for Opus)

### Edge Cases

- Odd number of arguments (type without ticket-id): error + exit 1
- Empty ticket ID: error + exit 1
- Duplicate ticket IDs: allowed (no dedup needed at this stage)
- Ticket ID format: do NOT validate format (not always `IN-XXXX`, could be project-specific)

### Project Structure Notes

- This is the first file being created in the klack repository
- File goes at project root: `klack.sh`
- Must be executable: `chmod +x klack.sh`
- No other files are created by this story

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Tool Name] — naming convention
- [Source: _bmad-output/planning-artifacts/architecture.md#Pattern 4: Bash Script Style] — script style
- [Source: _bmad-output/planning-artifacts/architecture.md#klack Repository Structure] — file location
- [Source: _bmad-output/planning-artifacts/architecture.md#Cross-Cutting Concerns Identified] — model config
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.1] — acceptance criteria
- [Source: _bmad-output/planning-artifacts/epics.md#NFR7] — model tiering

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
