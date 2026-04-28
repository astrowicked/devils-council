#!/usr/bin/env bash
# test-scaffolder-skill.sh — Structure tests for skills/create-persona/SKILL.md
#
# Validates that the SKILL.md file exists, has correct frontmatter, and contains
# all required wizard sections per the 05-01 plan's behavior specification.
#
# Exit codes:
#   0 — all tests pass
#   1 — one or more tests fail

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
SKILL_FILE="$REPO_ROOT/skills/create-persona/SKILL.md"

FAIL=0
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }

# --- Test 1: File exists ---
if [ -f "$SKILL_FILE" ]; then
  pass "Test 1: SKILL.md exists at skills/create-persona/SKILL.md"
else
  fail "Test 1: SKILL.md not found at skills/create-persona/SKILL.md"
  printf '\nTEST SUITE FAILED (file missing, cannot continue)\n' >&2
  exit 1
fi

# Extract frontmatter for Tests 2-4
FM=$(awk 'BEGIN{s=0} {if(s==0){if($0=="---"){s=1;next}else{exit 2}} if(s==1){if($0=="---"){exit 0}print}}' "$SKILL_FILE")

# --- Test 2: Frontmatter contains name: create-persona ---
if echo "$FM" | grep -q '^name: create-persona'; then
  pass "Test 2: frontmatter has name: create-persona"
else
  fail "Test 2: frontmatter missing name: create-persona"
fi

# --- Test 3: Frontmatter has allowed-tools including AskUserQuestion, Read, Write, Bash, Glob ---
if echo "$FM" | grep -q 'allowed-tools:' && \
   echo "$FM" | grep -q 'AskUserQuestion' && \
   echo "$FM" | grep -q 'Read' && \
   echo "$FM" | grep -q 'Write' && \
   echo "$FM" | grep -q 'Bash' && \
   echo "$FM" | grep -q 'Glob'; then
  pass "Test 3: frontmatter has allowed-tools with all 5 required tools"
else
  fail "Test 3: frontmatter missing allowed-tools or required tool entries"
fi

# --- Test 4: Frontmatter contains user-invocable: true ---
if echo "$FM" | grep -q 'user-invocable: true'; then
  pass "Test 4: frontmatter has user-invocable: true"
else
  fail "Test 4: frontmatter missing user-invocable: true"
fi

# Read full body (everything after closing --- fence)
BODY=$(awk 'BEGIN{s=0} {if(s==0){if($0=="---"){s=1;next}next} if(s==1){if($0=="---"){s=2;next}next} if(s==2){print}}' "$SKILL_FILE")

# --- Test 5: Body contains all 6 wizard steps in order ---
# Check for: name/slug, tier, primary_concern, characteristic_objections, banned_phrases, worked examples
STEP_COUNT=0
for pattern in "Step 0" "Step 1" "Step 2" "Step 3" "Step 4" "Step 5" "Step 6"; do
  if echo "$BODY" | grep -qi "$pattern"; then
    STEP_COUNT=$((STEP_COUNT + 1))
  fi
done
# Also check for Steps 7-11 (preview, write, validate, split, install)
for pattern in "Step 7" "Step 8" "Step 9" "Step 10" "Step 11"; do
  if echo "$BODY" | grep -qi "$pattern"; then
    STEP_COUNT=$((STEP_COUNT + 1))
  fi
done
if [ "$STEP_COUNT" -ge 10 ]; then
  pass "Test 5: body contains all wizard steps (found $STEP_COUNT/12 step markers)"
else
  fail "Test 5: body missing wizard steps (found only $STEP_COUNT/12 step markers)"
fi

# --- Test 6: Body contains overlap coaching section referencing >30% threshold ---
if echo "$BODY" | grep -q '30%'; then
  pass "Test 6: body contains >30% overlap threshold reference"
else
  fail "Test 6: body missing >30% overlap threshold reference"
fi

# --- Test 7: Body contains objection quality coaching (D-05 cross-check) ---
if echo "$BODY" | grep -qi 'banned.phrase' || echo "$BODY" | grep -qi 'banned_phrase'; then
  if echo "$BODY" | grep -qi 'objection.*banned\|banned.*objection\|cross.check\|D-05'; then
    pass "Test 7: body contains objection-vs-banned-phrase cross-check (D-05)"
  else
    fail "Test 7: body mentions banned phrases but missing cross-check logic"
  fi
else
  fail "Test 7: body missing objection quality coaching section"
fi

# --- Test 8: Body contains minimum enforcement rules ---
ENFORCE_COUNT=0
if echo "$BODY" | grep -qE '>=?\s*3|at least 3|minimum.*3|3.*objection'; then
  ENFORCE_COUNT=$((ENFORCE_COUNT + 1))
fi
if echo "$BODY" | grep -qE '>=?\s*5|at least 5|minimum.*5|5.*banned'; then
  ENFORCE_COUNT=$((ENFORCE_COUNT + 1))
fi
if echo "$BODY" | grep -qE '2 good.*1 bad|two good.*one bad|2.*good.*1.*bad'; then
  ENFORCE_COUNT=$((ENFORCE_COUNT + 1))
fi
if [ "$ENFORCE_COUNT" -ge 3 ]; then
  pass "Test 8: body contains all 3 minimum enforcement rules (objections>=3, bans>=5, 2good+1bad)"
else
  fail "Test 8: body missing minimum enforcement rules (found $ENFORCE_COUNT/3)"
fi

# --- Test 9: Body contains end-preview section (D-02) ---
if echo "$BODY" | grep -qi 'preview\|ready to write\|D-02'; then
  pass "Test 9: body contains end-preview section (D-02)"
else
  fail "Test 9: body missing end-preview section"
fi

# --- Test 10: Body contains workspace write using CLAUDE_PLUGIN_DATA ---
if echo "$BODY" | grep -q 'CLAUDE_PLUGIN_DATA' && echo "$BODY" | grep -q 'create-persona-workspace'; then
  pass "Test 10: body references CLAUDE_PLUGIN_DATA/create-persona-workspace/"
else
  fail "Test 10: body missing CLAUDE_PLUGIN_DATA/create-persona-workspace/ reference"
fi

# --- Test 11: Body contains validator invocation via Bash tool (not shell-inject) ---
if echo "$BODY" | grep -q 'validate-personas.sh'; then
  # Also check it's NOT using shell-inject pattern (!`)
  if grep -c '!`' "$SKILL_FILE" 2>/dev/null | grep -q '^0$' || ! grep -q '!`' "$SKILL_FILE"; then
    pass "Test 11: body references validate-personas.sh via Bash tool (no shell-inject)"
  else
    fail "Test 11: body uses shell-inject pattern (!backtick) instead of Bash tool"
  fi
else
  fail "Test 11: body missing validate-personas.sh invocation"
fi

# --- Test 12: Body contains validation-failure translated guidance (D-08) ---
if echo "$BODY" | grep -qE 'R[1-8].*=|R1|R2|R3|R4|R5|R6|R7|R8' && echo "$BODY" | grep -qi 'go back\|revisit\|re-ask\|D-08'; then
  pass "Test 12: body contains R-code to field-question mapping (D-08)"
else
  fail "Test 12: body missing validation-failure translated guidance (D-08 R-code mapping)"
fi

# --- Test 13: Body contains 3-retry-then-bail logic (D-09) ---
if echo "$BODY" | grep -qE '3.*retr|retry.*3|three.*retr|retr.*three|3.*attempt|attempt.*3|bail'; then
  pass "Test 13: body contains 3-retry-then-bail logic (D-09)"
else
  fail "Test 13: body missing 3-retry-then-bail logic (D-09)"
fi

# --- Test 14: Body contains overwrite-confirmation check (D-07) ---
if echo "$BODY" | grep -qi 'overwrite\|already exists\|D-07'; then
  pass "Test 14: body contains overwrite-confirmation check (D-07)"
else
  fail "Test 14: body missing overwrite-confirmation check for existing workspace"
fi

# --- Test 15: Body contains ready-to-run mv/cp commands section (D-06) ---
if echo "$BODY" | grep -qE 'cp.*agents/|mv.*agents/|install.*command|copy.*command|D-06'; then
  pass "Test 15: body contains ready-to-run install commands section (D-06)"
else
  fail "Test 15: body missing install commands section (D-06)"
fi

# --- Bonus: Line count check (>= 150 lines) ---
LINE_COUNT=$(wc -l < "$SKILL_FILE")
if [ "$LINE_COUNT" -ge 150 ]; then
  pass "Bonus: SKILL.md is $LINE_COUNT lines (>= 150 minimum)"
else
  fail "Bonus: SKILL.md is only $LINE_COUNT lines (need >= 150)"
fi

# ---- Summary ----
if [ "$FAIL" -ne 0 ]; then
  printf '\nTEST SUITE FAILED\n' >&2
  exit 1
fi

printf '\nTEST SUITE PASSED (all %d tests)\n' 16
exit 0
