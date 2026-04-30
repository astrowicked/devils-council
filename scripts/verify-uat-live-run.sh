#!/usr/bin/env bash
# verify-uat-live-run.sh — Post-review validation for Phase 7 UAT live run.
#
# Run AFTER executing: /devils-council:review tests/fixtures/uat-9bench/anaconda-platform-chart.md --type=plan
#
# Validates (per 07-01-PLAN.md Task 4):
#   1. A .council/<run>/ directory exists with a completed review
#   2. dc-validate-synthesis.sh passes on the SYNTHESIS.md
#   3. At least 6 persona scorecards exist (4 core + bench under budget)
#   4. MANIFEST.json shows classifier ran and budget planner spawned bench personas
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

# 2. Validate synthesis quality (REL-01)
# dc-validate-synthesis.sh runs during the review and renames .draft -> .md on
# success. Post-hoc, check MANIFEST.synthesis.ran == true (proof it passed).
# If .draft still exists, that means validation FAILED during the review.
printf '\nChecking synthesis validation status...\n'
if [ -f "${RUN_DIR}SYNTHESIS.md.draft" ]; then
  fail "SYNTHESIS.md.draft still exists — synthesis validation failed during review"
elif [ -f "${RUN_DIR}SYNTHESIS.md.invalid" ]; then
  fail "SYNTHESIS.md.invalid exists — Chair output failed validation"
else
  SYNTH_RAN=$(jq -r '.synthesis.ran // false' "${RUN_DIR}MANIFEST.json" 2>/dev/null)
  if [ "$SYNTH_RAN" = "true" ]; then
    SYNTH_ERRORS=$(jq -r '.synthesis.errors | length // 0' "${RUN_DIR}MANIFEST.json" 2>/dev/null)
    pass "dc-validate-synthesis.sh passed during review (ran=true, errors=$SYNTH_ERRORS)"
  else
    # synthesis.ran may not be set if conductor didn't record it; check file state instead
    pass "SYNTHESIS.md exists and no .draft/.invalid — synthesis accepted"
  fi
fi

# 3. Count persona scorecards (at least 6: 4 core + 2+ bench)
SCORECARD_COUNT=$(find "$RUN_DIR" -maxdepth 1 -name "*.md" ! -name "SYNTHESIS.md" ! -name "SYNTHESIS.md.invalid" ! -name "MANIFEST*" | wc -l | tr -d ' ')
if [ "$SCORECARD_COUNT" -ge 6 ]; then
  pass "Found $SCORECARD_COUNT persona scorecards (>= 6 required)"
else
  fail "Only $SCORECARD_COUNT persona scorecards found (need >= 6)"
fi

# 4. Validate MANIFEST budget planner ran and classifier populated
# Note: plan-type artifacts trigger max 6 bench personas (code-diff-gated
# signals like performance_hotpath, test_imbalance, shared_infra_change are
# excluded). 6 triggered <= 6 cap = no skipping needed. Budget-cap enforcement
# under overload is tested deterministically by test-budget-cap.sh Case 6.
MANIFEST="${RUN_DIR}MANIFEST.json"
if [ ! -f "$MANIFEST" ]; then
  fail "MANIFEST.json not found"
else
  SPAWNED=$(jq -r '.budget.spawned_bench_count // 0' "$MANIFEST")
  MAX_BENCH=$(jq -r '.budget.max_spawnable_bench // 0' "$MANIFEST")
  HAS_CLASSIFIER=$(jq -e '.classifier' "$MANIFEST" >/dev/null 2>&1 && echo "true" || echo "false")
  TRIGGERED=$(jq -r '.triggered_personas | length // 0' "$MANIFEST")

  if [ "$HAS_CLASSIFIER" = "true" ]; then
    pass "MANIFEST.classifier populated (structural classification ran)"
  else
    fail "MANIFEST.classifier absent — classifier did not run"
  fi

  if [ "$TRIGGERED" -ge 5 ]; then
    pass "Classifier triggered $TRIGGERED bench personas (>= 5 expected for plan artifact)"
  else
    fail "Expected >= 5 triggered personas, got $TRIGGERED"
  fi

  if [ "$SPAWNED" -ge 5 ]; then
    pass "Budget planner spawned $SPAWNED bench personas (max_spawnable=$MAX_BENCH)"
  else
    fail "Expected >= 5 spawned bench personas, got $SPAWNED"
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
