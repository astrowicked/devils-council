#!/usr/bin/env bash
# test-blinded-reader.sh — PQUAL-03 blinded-reader persona attribution readiness.
#
# Validates the STRUCTURAL prerequisites for LLM-as-judge blinded-reader
# evaluation at 9-bench scale. Actual LLM-as-judge attribution (D-10:
# "feed each anonymized scorecard to a fresh LLM prompt") runs in Phase 7
# UAT with live persona output.
#
# Phase 4 checks:
#   1. All 9 bench persona sidecars exist and parse
#   2. Multi-signal fixture exists
#   3. Each persona has unique primary_concern (key attribution signal)
#   4. Each persona has >= 3 characteristic_objections (attribution signal)
#   5. Each persona has >= 3 role-specific banned phrases (negative signal)
#
# Exit 0 if all checks pass, exit 1 otherwise.

set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

FAIL=0
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }

BENCH_PERSONAS=(
  security-reviewer finops-auditor air-gap-reviewer dual-deploy-reviewer
  compliance-reviewer performance-reviewer test-lead executive-sponsor competing-team-lead
)

# Check all sidecars exist
SIDECARS_OK=true
for p in "${BENCH_PERSONAS[@]}"; do
  if [ ! -f "$REPO_ROOT/persona-metadata/${p}.yml" ]; then
    fail "Missing sidecar: ${p}.yml"
    SIDECARS_OK=false
  fi
done
if [ "$SIDECARS_OK" = true ]; then
  pass "All 9 bench persona sidecars exist"
fi

# Check fixture exists
FIXTURE="$REPO_ROOT/tests/fixtures/blinded-reader/multi-signal-fixture.md"
if [ -f "$FIXTURE" ]; then
  pass "Multi-signal fixture exists"
else
  fail "Missing: tests/fixtures/blinded-reader/multi-signal-fixture.md"
fi

# Check primary_concern uniqueness (key attribution signal)
declare -A CONCERN_MAP
CONCERNS_UNIQUE=true
for p in "${BENCH_PERSONAS[@]}"; do
  SIDECAR="$REPO_ROOT/persona-metadata/${p}.yml"
  [ -f "$SIDECAR" ] || continue
  CONCERN=$(yq '.primary_concern' "$SIDECAR" 2>/dev/null || echo "")
  for existing_persona in "${!CONCERN_MAP[@]}"; do
    if [ "${CONCERN_MAP[$existing_persona]}" = "$CONCERN" ]; then
      fail "Duplicate primary_concern: $p shares with $existing_persona"
      CONCERNS_UNIQUE=false
    fi
  done
  CONCERN_MAP["$p"]="$CONCERN"
done
if [ "$CONCERNS_UNIQUE" = true ]; then
  pass "All 9 bench personas have unique primary_concern values"
fi

# Check characteristic_objections count (minimum 3 for attribution signal)
OBJECTIONS_OK=true
for p in "${BENCH_PERSONAS[@]}"; do
  SIDECAR="$REPO_ROOT/persona-metadata/${p}.yml"
  [ -f "$SIDECAR" ] || continue
  COUNT=$(yq '.characteristic_objections | length' "$SIDECAR" 2>/dev/null || echo "0")
  if [ "$COUNT" -lt 3 ]; then
    fail "$p has only $COUNT characteristic_objections (minimum 3 for attribution signal)"
    OBJECTIONS_OK=false
  fi
done
if [ "$OBJECTIONS_OK" = true ]; then
  pass "All 9 bench personas have >= 3 characteristic_objections"
fi

# Check banned_phrases (role-specific count after baseline exclusion)
BANS_OK=true
for p in "${BENCH_PERSONAS[@]}"; do
  SIDECAR="$REPO_ROOT/persona-metadata/${p}.yml"
  [ -f "$SIDECAR" ] || continue
  TOTAL=$(yq '.banned_phrases | length' "$SIDECAR" 2>/dev/null || echo "0")
  ROLE_SPECIFIC=$((TOTAL - 3))  # subtract 3 baseline (consider, think about, be aware of)
  if [ "$ROLE_SPECIFIC" -lt 3 ]; then
    fail "$p has only $ROLE_SPECIFIC role-specific banned phrases (minimum 3 for negative signal)"
    BANS_OK=false
  fi
done
if [ "$BANS_OK" = true ]; then
  pass "All 9 bench personas have >= 3 role-specific banned phrases"
fi

# Summary
TOTAL_CHECKS=5
PASSED=$((TOTAL_CHECKS - FAIL))
printf '\nBlinded-reader readiness: %d/%d checks passed\n' "$PASSED" "$TOTAL_CHECKS"

if [ "$FAIL" -eq 0 ]; then
  printf '=== BLINDED-READER READINESS: PASSED (Phase 7 live run will measure >=80%% attribution) ===\n'
  exit 0
else
  printf '=== BLINDED-READER READINESS: FAILURES DETECTED ===\n' >&2
  exit 1
fi
