# Story 1.1: Implement /api/happy/{id} endpoint

Status: ready-for-dev

## Story

As a developer,
I want to implement GET /api/happy/{id},
so that clients receive a deterministic joke and cat image for any given ID.

## Acceptance Criteria

1. **Given** a valid integer ID **When** GET /api/happy/42 **Then** returns JSON with `joke` (string) and `cat_image` (URL string) and HTTP 200
2. **Given** the same ID called twice **When** GET /api/happy/42 **Then** both calls return identical responses (determinism)
3. **Given** an invalid ID **When** GET /api/happy/abc **Then** returns HTTP 400 with error message

## Tasks / Subtasks

- [ ] Task 1: Create HappyController (AC: #1, #2)
  - [ ] 1.1: Add route GET /api/happy/{id}
  - [ ] 1.2: Return deterministic joke + cat_image JSON
- [ ] Task 2: Input validation (AC: #3)
  - [ ] 2.1: Validate ID is positive integer, return 400 otherwise

## Dev Notes

Simple REST endpoint. Use a hash of the ID to deterministically select from a fixed joke list.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
