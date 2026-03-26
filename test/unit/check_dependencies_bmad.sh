#!/usr/bin/env bash
# Unit tests for ticket-run.sh bmad story lookup in check_dependencies()
#
# Tests the two key behaviors added for ticket_source: bmad:
#   1. Find pattern correctly locates {TICKET}-*.md in _bmad-output/implementation-artifacts/
#   2. Depends: field is extracted from bmad story files
#   3. No bmad story = empty deps (no error, graceful fallback)
#
# Run: bash test/unit/check_dependencies_bmad.sh

set -euo pipefail

PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    echo "        expected: '$expected'"
    echo "        actual:   '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

assert_empty() {
  local label="$1" actual="$2"
  if [[ -z "$actual" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (expected empty, got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Setup: temporary KLACK_ROOT with bmad artifacts
# ---------------------------------------------------------------------------

KLACK_ROOT="$(mktemp -d)"
trap 'rm -rf "$KLACK_ROOT"' EXIT

ARTIFACTS_DIR="$KLACK_ROOT/_bmad-output/implementation-artifacts"
mkdir -p "$ARTIFACTS_DIR"

# Story 1-1: no dependencies
cat > "$ARTIFACTS_DIR/1-1-implement-happy-endpoint.md" <<'EOF'
# Story 1.1: Implement /api/happy/{id} endpoint

Status: ready-for-dev

## Story

As a developer, I want GET /api/happy/{id}, so that clients get a response.
EOF

# Story 1-2: depends on 1-1
cat > "$ARTIFACTS_DIR/1-2-add-caching-layer.md" <<'EOF'
Depends: 1-1

# Story 1.2: Add caching layer

Status: ready-for-dev

## Story

As a developer, I want caching, so that responses are fast.
EOF

# Story 2-1: multiple dependencies
cat > "$ARTIFACTS_DIR/2-1-integration.md" <<'EOF'
Depends: 1-1, 1-2

# Story 2.1: Integration

Status: ready-for-dev
EOF

# ---------------------------------------------------------------------------
# Test the find pattern (mirrors ticket-run.sh check_dependencies logic)
# ---------------------------------------------------------------------------

find_bmad_story() {
  local ticket="$1"
  find "$KLACK_ROOT/_bmad-output/implementation-artifacts" \
    -name "${ticket}-*.md" -type f 2>/dev/null | head -1
}

extract_depends() {
  local story_file="$1"
  grep '^Depends:' "$story_file" 2>/dev/null | sed 's/^Depends:[[:space:]]*//' | tr ',' ' ' || true
}

echo ""
echo "=== BMad find pattern ==="

# Test: exact ticket ID match (1-1)
story_1_1="$(find_bmad_story "1-1")"
assert_eq "1-1 finds 1-1-implement-happy-endpoint.md" \
  "$ARTIFACTS_DIR/1-1-implement-happy-endpoint.md" "$story_1_1"

# Test: exact ticket ID match (1-2)
story_1_2="$(find_bmad_story "1-2")"
assert_eq "1-2 finds 1-2-add-caching-layer.md" \
  "$ARTIFACTS_DIR/1-2-add-caching-layer.md" "$story_1_2"

# Test: non-existent ticket returns empty
story_9_9="$(find_bmad_story "9-9")"
assert_empty "9-9 returns empty (no match)" "$story_9_9"

# Test: non-existent epic/story combination returns empty
story_1_99="$(find_bmad_story "1-99")"
assert_empty "1-99 returns empty (no match for that story)" "$story_1_99"

echo ""
echo "=== Depends: field extraction ==="

# Test: story without Depends → empty
deps_1_1="$(extract_depends "$story_1_1" | xargs)"
assert_empty "1-1 has no Depends field" "$deps_1_1"

# Test: story with single Depends → extracts value
deps_1_2="$(extract_depends "$story_1_2" | xargs)"
assert_eq "1-2 extracts Depends: 1-1" "1-1" "$deps_1_2"

# Test: story with multiple Depends → space-separated
story_2_1="$(find_bmad_story "2-1")"
deps_2_1="$(extract_depends "$story_2_1" | xargs)"
assert_eq "2-1 extracts Depends: 1-1 and 1-2" "1-1 1-2" "$deps_2_1"

echo ""
echo "=== Graceful fallback when no bmad story exists ==="

# Simulate check_dependencies() bmad block:
# If bmad_story is empty → bmad_deps stays empty → no effect on deps
TICKET="9-9"
bmad_story="$(find_bmad_story "$TICKET")"
bmad_deps=""
if [[ -n "$bmad_story" ]]; then
  bmad_deps="$(extract_depends "$bmad_story" | xargs)"
fi
assert_empty "missing story → bmad_deps stays empty" "$bmad_deps"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "=================================="
echo "Results: $PASS passed, $FAIL failed"
echo "=================================="

[[ $FAIL -eq 0 ]] || exit 1
