#!/usr/bin/env bash
# test-exec-sponsor-adversarial.sh
# Validates that the Executive Sponsor adversarial fixture is structurally
# correct: zero quantification + high banned-phrase coverage.
#
# Two assertions per D-12:
# 1. Fixture contains ZERO quantified business claims (no dollar amounts,
#    dates in YYYY-MM-DD form, or metric counts like "N users")
# 2. Fixture contains >= 60% of the role-specific banned phrases from
#    the executive-sponsor sidecar (proves the fixture is adversarial)
#
# This script validates FIXTURE STRUCTURE, not LLM output.
# The actual LLM-based test runs in Phase 7 CI.

set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../../.." && pwd )"

FIXTURE="$SCRIPT_DIR/temptation-plan.md"
SIDECAR="$REPO_ROOT/persona-metadata/executive-sponsor.yml"

FAIL=0
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }

# Fixture exists
[ -f "$FIXTURE" ] || { fail "temptation-plan.md missing"; exit 1; }
[ -f "$SIDECAR" ] || { fail "executive-sponsor.yml missing"; exit 1; }

# Assertion 1: Fixture contains ZERO numbers (no digits that look like business metrics)
# Allow digits only in headings like "Q3" but not dollar amounts, dates, or counts
NUMBER_LINES=$(grep -cE '\$[0-9]|[0-9]{4}-[0-9]{2}|[0-9]+ (users|customers|engineers|weeks|months|dollars|accounts|percent)' "$FIXTURE" || true)
if [ "$NUMBER_LINES" -eq 0 ]; then
  pass "Temptation plan contains zero quantified business claims"
else
  fail "Temptation plan contains $NUMBER_LINES lines with numbers -- fixture is too easy"
fi

# Assertion 2: Every banned nominalization from the sidecar appears in the fixture
# (proves the fixture is genuinely adversarial)
TOTAL_BANS=$(yq '.banned_phrases | length' "$SIDECAR")
FOUND_IN_FIXTURE=0
for i in $(seq 0 $((TOTAL_BANS - 1))); do
  PHRASE=$(yq ".banned_phrases[$i]" "$SIDECAR")
  # Skip baseline bans (consider, think about, be aware of) -- they're generic
  case "$PHRASE" in "consider"|"think about"|"be aware of") continue ;; esac
  if grep -qiF "$PHRASE" "$FIXTURE"; then
    FOUND_IN_FIXTURE=$((FOUND_IN_FIXTURE + 1))
  fi
done
ROLE_BANS=$((TOTAL_BANS - 3))  # exclude 3 baseline
if [ "$ROLE_BANS" -le 0 ]; then
  fail "Executive sponsor sidecar has no role-specific banned phrases"
else
  COVERAGE_PCT=$((FOUND_IN_FIXTURE * 100 / ROLE_BANS))
  if [ "$COVERAGE_PCT" -ge 60 ]; then
    pass "Fixture contains ${FOUND_IN_FIXTURE}/${ROLE_BANS} role-specific banned phrases (${COVERAGE_PCT}% coverage)"
  else
    fail "Fixture only contains ${FOUND_IN_FIXTURE}/${ROLE_BANS} role-specific banned phrases (${COVERAGE_PCT}% < 60% minimum)"
  fi
fi

if [ "$FAIL" -eq 0 ]; then
  printf '\n=== EXEC SPONSOR ADVERSARIAL FIXTURE: ALL ASSERTIONS PASSED ===\n'
  exit 0
else
  printf '\n=== EXEC SPONSOR ADVERSARIAL FIXTURE: FAILURES DETECTED ===\n' >&2
  exit 1
fi
