#!/usr/bin/env bash
# verify-uat-live-run.sh — Post-review validation for Phase 7 UAT live run.
#
# Run AFTER executing: /devils-council:review tests/fixtures/uat-9bench/anaconda-platform-chart.md --type=plan
#
# Validates (per 07-01-PLAN.md Task 4):
#   1. A .council/<run>/ directory exists with a completed review
#   2. dc-validate-synthesis.sh passes on the SYNTHESIS.md
#   3. At least 6 persona scorecards exist (4 core + bench under budget)
#   4. MANIFEST.json shows budget enforcement (over_budget=true, >= 3 skipped)
#   5. (Optional) Run blinded-reader --live-judge for attribution accuracy
#
# Usage:
#   ./scripts/verify-uat-live-run.sh [--run-dir=<path>] [--with-judge]
#
# Exit 0 if all validations pass, exit 1 otherwise.

set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

FAIL=0
RUN_DIR=""
WITH_JUDGE=false

pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }

for arg in "$@"; do
  case "$arg" in
    --run-dir=*) RUN_DIR="${arg#--run-dir=}" ;;
    --with-judge) WITH_JUDGE=true ;;
  esac
done

# Resolve latest run directory
if [ -z "$RUN_DIR" ]; then
  RUN_DIR=$(ls -td "$REPO_ROOT/.council"/*/ 2>/dev/null | head -1)
fi

if [ -z "$RUN_DIR" ] || [ ! -d "$RUN_DIR" ]; then
  fail "No .council/ run directory found. Run '/devils-council:review tests/fixtures/uat-9bench/anaconda-platform-chart.md --type=plan' first."
  printf '\n=== UAT LIVE RUN VERIFICATION: NO RUN FOUND ===\n' >&2
  exit 1
fi

printf 'Validating run directory: %s\n\n' "$RUN_DIR"

# 1. Check SYNTHESIS.md exists
if [ -f "${RUN_DIR}SYNTHESIS.md" ]; then
  pass "SYNTHESIS.md exists"
elif [ -f "${RUN_DIR}/SYNTHESIS.md" ]; then
  RUN_DIR="${RUN_DIR}/"
  pass "SYNTHESIS.md exists"
else
  fail "SYNTHESIS.md not found in $RUN_DIR"
fi

# Normalize trailing slash
[[ "$RUN_DIR" != */ ]] && RUN_DIR="${RUN_DIR}/"

# 2. Validate synthesis via dc-validate-synthesis.sh (REL-01)
printf '\nRunning dc-validate-synthesis.sh...\n'
if bash "$REPO_ROOT/bin/dc-validate-synthesis.sh" "${RUN_DIR}SYNTHESIS.md" 2>&1; then
  pass "dc-validate-synthesis.sh passed (REL-01: Chair synthesis validated)"
else
  fail "dc-validate-synthesis.sh FAILED"
fi

# 3. Count persona scorecards (at least 6: 4 core + 2+ bench)
SCORECARD_COUNT=$(find "$RUN_DIR" -maxdepth 1 -name "*.md" ! -name "SYNTHESIS.md" ! -name "SYNTHESIS.md.invalid" ! -name "MANIFEST*" | wc -l | tr -d ' ')
if [ "$SCORECARD_COUNT" -ge 6 ]; then
  pass "Found $SCORECARD_COUNT persona scorecards (>= 6 required)"
else
  fail "Only $SCORECARD_COUNT persona scorecards found (need >= 6)"
fi

# 4. Validate MANIFEST budget enforcement
MANIFEST="${RUN_DIR}MANIFEST.json"
if [ ! -f "$MANIFEST" ]; then
  fail "MANIFEST.json not found"
else
  OVER_BUDGET=$(jq -r '.budget.over_budget // "null"' "$MANIFEST")
  SKIPPED_COUNT=$(jq -r '.personas_skipped | length // 0' "$MANIFEST")

  if [ "$OVER_BUDGET" = "true" ]; then
    pass "MANIFEST.budget.over_budget == true (9 triggered > 6 cap)"
  else
    fail "Expected MANIFEST.budget.over_budget == true, got '$OVER_BUDGET'"
  fi

  if [ "$SKIPPED_COUNT" -ge 3 ]; then
    pass "MANIFEST.personas_skipped has $SKIPPED_COUNT entries (>= 3 required)"
  else
    fail "Expected >= 3 personas_skipped, got $SKIPPED_COUNT"
  fi
fi

# Summary
printf '\n--- UAT Live Run Verification ---\n'
if [ "$FAIL" -eq 0 ]; then
  printf '=== UAT LIVE RUN: ALL CHECKS PASSED ===\n'
else
  printf '=== UAT LIVE RUN: %d FAILURE(S) DETECTED ===\n' "$FAIL" >&2
fi

# 5. Optional: Run blinded-reader --live-judge
if [ "$WITH_JUDGE" = true ] && [ "$FAIL" -eq 0 ]; then
  printf '\n--- Running LLM-as-judge attribution (--with-judge) ---\n'
  bash "$REPO_ROOT/scripts/test-blinded-reader.sh" --live-judge --run-dir="$RUN_DIR"
  JUDGE_RC=$?
  if [ "$JUDGE_RC" -ne 0 ]; then
    fail "Blinded-reader LLM-as-judge failed (exit $JUDGE_RC)"
  fi
fi

exit "$FAIL"
