# Story 9.1: Klack Protocol Context File

Status: ready-for-dev

## Story

As a Claude agent running inside Der Klack,
I want a protocol file that teaches me how to communicate via the Klack filesystem,
so that I can operate autonomously within the pipeline without custom instructions in every command.

## Acceptance Criteria

1. A file `commands/klack-protocol.md` exists that any Claude agent can load
2. The protocol file teaches: KLACK_DIR, status.json schema, Ruecksignal mechanism, worktree verification
3. Every `ticket-*.md` command references the protocol file as first load instruction
4. The protocol includes helper patterns (bash snippets) the agent can copy-paste for status updates, Ruecksignal, etc.
5. The protocol explains the agent's role in the pipeline and what step comes before/after

## Dev Notes

This is the missing bridge between Klack orchestration and BMAD-Method skill execution. Currently each command file re-explains the protocol inline. Instead: one canonical protocol file, loaded first.

### References
- [Source: architecture.md#Pattern 1-6] — all communication patterns
- [Source: architecture.md#status.json Schema] — data contract
