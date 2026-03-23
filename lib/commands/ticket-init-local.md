# Lokales Ticket-System

Klack kann ohne Jira/GitHub/Linear arbeiten. Tickets sind einfach Markdown-Dateien.

## Verzeichnisstruktur

```
.klack/tickets/
├── epic-1.md              ← Epic-Beschreibung
├── E1-001.md              ← Ticket
├── E1-002.md              ← Ticket
├── E1-003.md              ← Ticket
└── epic-2.md
```

## Ticket-Format (minimal)

```markdown
# E1-001: Titel des Tickets

Type: feat
Status: open

## Beschreibung
Was gemacht werden soll.

## Acceptance Criteria
- [ ] AC 1
- [ ] AC 2
```

## Epic-Format (minimal)

```markdown
# Epic 1: Name des Epics

## Ziel
Was dieses Epic erreichen soll.

## Tickets
- E1-001: Titel
- E1-002: Titel
- E1-003: Titel
```
