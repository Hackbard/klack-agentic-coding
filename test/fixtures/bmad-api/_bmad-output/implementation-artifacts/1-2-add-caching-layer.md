Depends: 1-1

# Story 1.2: Add caching layer for happy responses

Status: ready-for-dev

## Story

As a developer,
I want to cache /api/happy/{id} responses in Redis,
so that repeated requests for the same ID are served without recomputing.

## Acceptance Criteria

1. **Given** a cached ID **When** GET /api/happy/42 is called **Then** response is served from cache
2. **Given** cache miss **When** GET /api/happy/42 is called first time **Then** result is computed and cached

## Tasks / Subtasks

- [ ] Task 1: Add Redis caching (AC: #1, #2)
  - [ ] 1.1: Configure Redis connection
  - [ ] 1.2: Cache response on first call, return cached on subsequent calls

## Dev Notes

Depends on 1-1 (endpoint must exist before caching is added).

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
