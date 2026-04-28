#!/usr/bin/env bash
# test-persona-scaffolder.sh — Test harness for scaffolder output validation.
#
# Validates that scaffolder-produced persona files meet quality standards
# by testing three cases: pass, reject, and overlap detection.
#
# Tests the GENERATED FILES, not the interactive flow (per 05-RESEARCH.md
# Open Question #2 resolution).
#
# Exit codes:
#   0 — all test groups pass
#   1 — one or more test groups fail

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
VALIDATOR="$SCRIPT_DIR/validate-personas.sh"
SIGNALS="$REPO_ROOT/lib/signals.json"
FIX_DIR="$REPO_ROOT/tests/fixtures/scaffolder"

FAIL=0
pass() { printf '  PASS: %s\n' "$*"; }
fail() { printf '  FAIL: %s\n' "$*" >&2; FAIL=1; }

# Preflight checks.
[ -x "$VALIDATOR" ] || { printf 'ABORT: %s missing or not executable\n' "$VALIDATOR" >&2; exit 1; }
[ -f "$SIGNALS" ]   || { printf 'ABORT: %s missing\n' "$SIGNALS" >&2; exit 1; }
[ -d "$FIX_DIR" ]   || { printf 'ABORT: %s missing\n' "$FIX_DIR" >&2; exit 1; }

# ============================================================================
# Group 1: Pass Case (SCAF-02)
# ============================================================================
printf '\n=== Group 1: Pass Case ===\n'

VALID="$FIX_DIR/valid-persona.md"

# 1a: Fixture exists.
if [ -f "$VALID" ]; then
  pass "valid-persona.md exists"
else
  fail "valid-persona.md not found"
fi

# 1b: Passes validate-personas.sh exit 0.
if "$VALIDATOR" "$VALID" --signals "$SIGNALS" >/dev/null 2>&1; then
  pass "valid-persona.md passes validate-personas.sh (exit 0)"
else
  fail "valid-persona.md FAILS validate-personas.sh (expected exit 0)"
fi

# 1c: Has all required fields.
for field in tier primary_concern blind_spots characteristic_objections banned_phrases triggers; do
  if grep -q "$field" "$VALID"; then
    pass "valid-persona.md contains field: $field"
  else
    fail "valid-persona.md missing field: $field"
  fi
done

# 1d: characteristic_objections count >= 3.
OBJ_COUNT=$(python3 -c "
import yaml, sys
with open(sys.argv[1]) as f:
    content = f.read()
    # Extract frontmatter between --- fences
    parts = content.split('---')
    if len(parts) >= 3:
        data = yaml.safe_load(parts[1])
        objs = data.get('characteristic_objections', [])
        print(len(objs) if isinstance(objs, list) else 0)
    else:
        print(0)
" "$VALID" 2>/dev/null || echo 0)

if [ "$OBJ_COUNT" -ge 3 ]; then
  pass "valid-persona.md has $OBJ_COUNT characteristic_objections (>= 3)"
else
  fail "valid-persona.md has $OBJ_COUNT characteristic_objections (need >= 3)"
fi

# 1e: banned_phrases count >= 5 (scaffolder quality bar).
BAN_COUNT=$(python3 -c "
import yaml, sys
with open(sys.argv[1]) as f:
    content = f.read()
    parts = content.split('---')
    if len(parts) >= 3:
        data = yaml.safe_load(parts[1])
        bans = data.get('banned_phrases', [])
        print(len(bans) if isinstance(bans, list) else 0)
    else:
        print(0)
" "$VALID" 2>/dev/null || echo 0)

if [ "$BAN_COUNT" -ge 5 ]; then
  pass "valid-persona.md has $BAN_COUNT banned_phrases (>= 5 scaffolder bar)"
else
  fail "valid-persona.md has $BAN_COUNT banned_phrases (need >= 5 scaffolder bar)"
fi

# ============================================================================
# Group 2: Reject Case (SCAF-01 minimum enforcement)
# ============================================================================
printf '\n=== Group 2: Reject Case ===\n'

WEAK="$FIX_DIR/weak-persona.md"

# 2a: Fixture exists.
if [ -f "$WEAK" ]; then
  pass "weak-persona.md exists"
else
  fail "weak-persona.md not found"
fi

# 2b: Fails validate-personas.sh exit 1 (hard failure).
WEAK_OUTPUT=$("$VALIDATOR" "$WEAK" --signals "$SIGNALS" 2>&1 || true)
WEAK_EXIT=0
"$VALIDATOR" "$WEAK" --signals "$SIGNALS" >/dev/null 2>&1 || WEAK_EXIT=$?

if [ "$WEAK_EXIT" -ne 0 ]; then
  pass "weak-persona.md fails validate-personas.sh (exit $WEAK_EXIT)"
else
  fail "weak-persona.md PASSES validate-personas.sh (expected failure)"
fi

# 2c: Error mentions R5 or characteristic_objections.
if printf '%s' "$WEAK_OUTPUT" | grep -qE 'R5|characteristic_objections'; then
  pass "weak-persona.md error mentions R5/characteristic_objections"
else
  fail "weak-persona.md error does not mention R5/characteristic_objections (output: $WEAK_OUTPUT)"
fi

# 2d: Confirm fixture has < 3 characteristic_objections.
WEAK_OBJ_COUNT=$(python3 -c "
import yaml, sys
with open(sys.argv[1]) as f:
    content = f.read()
    parts = content.split('---')
    if len(parts) >= 3:
        data = yaml.safe_load(parts[1])
        objs = data.get('characteristic_objections', [])
        print(len(objs) if isinstance(objs, list) else 0)
    else:
        print(0)
" "$WEAK" 2>/dev/null || echo 0)

if [ "$WEAK_OBJ_COUNT" -lt 3 ]; then
  pass "weak-persona.md has $WEAK_OBJ_COUNT characteristic_objections (intentionally < 3)"
else
  fail "weak-persona.md has $WEAK_OBJ_COUNT characteristic_objections (should be < 3 to test reject)"
fi

# 2e: Confirm fixture has < 5 banned_phrases (would fail scaffolder minimum).
WEAK_BAN_COUNT=$(python3 -c "
import yaml, sys
with open(sys.argv[1]) as f:
    content = f.read()
    parts = content.split('---')
    if len(parts) >= 3:
        data = yaml.safe_load(parts[1])
        bans = data.get('banned_phrases', [])
        print(len(bans) if isinstance(bans, list) else 0)
    else:
        print(0)
" "$WEAK" 2>/dev/null || echo 0)

if [ "$WEAK_BAN_COUNT" -lt 5 ]; then
  pass "weak-persona.md has $WEAK_BAN_COUNT banned_phrases (< 5 scaffolder bar)"
else
  fail "weak-persona.md has $WEAK_BAN_COUNT banned_phrases (should be < 5 to test scaffolder rejection)"
fi

# ============================================================================
# Group 3: Overlap Detection (SCAF-04)
# ============================================================================
printf '\n=== Group 3: Overlap Detection ===\n'

OVERLAP="$FIX_DIR/overlap-persona.md"
STAFF_META="$REPO_ROOT/persona-metadata/staff-engineer.yml"

# 3a: Fixture exists.
if [ -f "$OVERLAP" ]; then
  pass "overlap-persona.md exists"
else
  fail "overlap-persona.md not found"
fi

# 3b-3d: Compute overlap percentage using python3.
OVERLAP_RESULT=$(python3 -c "
import yaml, sys, os

baseline = {'consider', 'think about', 'be aware of'}

# Read overlap fixture
fixture_path = sys.argv[1]
with open(fixture_path) as f:
    content = f.read()
    parts = content.split('---')
    fixture_data = yaml.safe_load(parts[1]) if len(parts) >= 3 else {}

fixture_bans = set(b.lower() for b in fixture_data.get('banned_phrases', []))
fixture_role_specific = fixture_bans - baseline

# Read staff-engineer sidecar
staff_path = sys.argv[2]
with open(staff_path) as f:
    staff_data = yaml.safe_load(f) or {}

staff_bans = set(b.lower() for b in staff_data.get('banned_phrases', []))
staff_role_specific = staff_bans - baseline

# Compute overlap
if not fixture_role_specific or not staff_role_specific:
    print('PCT=0')
    print('PHRASES=none')
    sys.exit(0)

intersection = fixture_role_specific & staff_role_specific
denominator = min(len(fixture_role_specific), len(staff_role_specific))
pct = len(intersection) * 100 // denominator

print(f'PCT={pct}')
print(f'PHRASES={chr(44).join(sorted(intersection))}')
print(f'FIXTURE_ROLE_SPECIFIC={chr(44).join(sorted(fixture_role_specific))}')
print(f'STAFF_ROLE_SPECIFIC={chr(44).join(sorted(staff_role_specific))}')
" "$OVERLAP" "$STAFF_META" 2>/dev/null || echo "PCT=0")

OVERLAP_PCT=$(echo "$OVERLAP_RESULT" | grep '^PCT=' | cut -d= -f2)
OVERLAP_PHRASES=$(echo "$OVERLAP_RESULT" | grep '^PHRASES=' | cut -d= -f2-)

# 3b: Overlap percentage > 30%.
if [ "${OVERLAP_PCT:-0}" -gt 30 ]; then
  pass "overlap-persona.md has ${OVERLAP_PCT}% overlap with staff-engineer (> 30%)"
else
  fail "overlap-persona.md has ${OVERLAP_PCT}% overlap with staff-engineer (need > 30%)"
fi

# 3c: Print overlapping phrases.
if [ -n "$OVERLAP_PHRASES" ] && [ "$OVERLAP_PHRASES" != "none" ]; then
  pass "overlapping phrases: $OVERLAP_PHRASES"
else
  fail "no overlapping phrases detected"
fi

# 3d: Print full result for debugging.
printf '  INFO: %s\n' "$OVERLAP_RESULT" | head -4

# ============================================================================
# Summary
# ============================================================================
printf '\n'
if [ "$FAIL" -ne 0 ]; then
  printf 'TEST SUITE FAILED\n' >&2
  exit 1
fi

printf 'TEST SUITE PASSED\n'
exit 0
