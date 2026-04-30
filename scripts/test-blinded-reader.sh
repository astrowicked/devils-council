#!/usr/bin/env bash
# test-blinded-reader.sh — PQUAL-03 blinded-reader persona attribution readiness.
#
# Validates the STRUCTURAL prerequisites for LLM-as-judge blinded-reader
# evaluation at 9-bench scale. Actual LLM-as-judge attribution (D-10:
# "feed each anonymized scorecard to a fresh LLM prompt") runs in Phase 7
# UAT with live persona output.
#
# Phase 4 checks (structural readiness — always run):
#   1. All 9 bench persona sidecars exist and parse
#   2. Multi-signal fixture exists
#   3. Each persona has unique primary_concern (key attribution signal)
#   4. Each persona has >= 3 characteristic_objections (attribution signal)
#   5. Each persona has >= 3 role-specific banned phrases (negative signal)
#
# Phase 7 --live-judge mode (LLM-as-judge attribution — manual UAT only):
#   Runs Claude CLI to attribute anonymized scorecards to personas.
#   Asserts >= 80% accuracy per PQUAL-03.
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
# Portable: no associative arrays (bash 3.2 on macOS lacks declare -A)
CONCERNS_UNIQUE=true
SEEN_CONCERNS=""
for p in "${BENCH_PERSONAS[@]}"; do
  SIDECAR="$REPO_ROOT/persona-metadata/${p}.yml"
  [ -f "$SIDECAR" ] || continue
  CONCERN=$(yq '.primary_concern' "$SIDECAR" 2>/dev/null || echo "")
  if echo "$SEEN_CONCERNS" | grep -qF "|${CONCERN}|"; then
    fail "Duplicate primary_concern: $p shares concern with another persona"
    CONCERNS_UNIQUE=false
  fi
  SEEN_CONCERNS="${SEEN_CONCERNS}|${CONCERN}|"
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
else
  printf '=== BLINDED-READER READINESS: FAILURES DETECTED ===\n' >&2
  exit 1
fi

# === LIVE LLM-AS-JUDGE EVALUATION (Phase 7 REL-02 / PQUAL-03) ===
# Requires: a completed .council/ run with 6+ persona scorecards
# Invocation: ./scripts/test-blinded-reader.sh --live-judge [--run-dir=<path>]
# NOT run in CI — requires Claude CLI auth + a real review run

LIVE_JUDGE=false
RUN_DIR=""

for arg in "$@"; do
  case "$arg" in
    --live-judge) LIVE_JUDGE=true ;;
    --run-dir=*) RUN_DIR="${arg#--run-dir=}" ;;
  esac
done

if [ "$LIVE_JUDGE" = false ]; then
  exit 0
fi

printf '\n=== LLM-AS-JUDGE PERSONA ATTRIBUTION (REL-02 / PQUAL-03) ===\n'

# Resolve run directory
if [ -z "$RUN_DIR" ]; then
  RUN_DIR=$(ls -td "$REPO_ROOT/.council"/*/ 2>/dev/null | head -1)
fi

if [ -z "$RUN_DIR" ] || [ ! -d "$RUN_DIR" ]; then
  fail "No .council/ run directory found. Run /devils-council:review first."
  exit 1
fi

printf 'Using run directory: %s\n' "$RUN_DIR"

# Collect persona scorecards (exclude SYNTHESIS.md and MANIFEST files)
SCORECARDS=()
while IFS= read -r -d '' f; do
  SCORECARDS+=("$f")
done < <(find "$RUN_DIR" -maxdepth 1 -name "*.md" ! -name "SYNTHESIS.md" ! -name "MANIFEST*" -print0 | sort -z)

SCORECARD_COUNT=${#SCORECARDS[@]}
printf 'Found %d persona scorecards\n' "$SCORECARD_COUNT"

if [ "$SCORECARD_COUNT" -lt 6 ]; then
  fail "Expected at least 6 scorecards, found $SCORECARD_COUNT"
  exit 1
fi

# All persona slugs for the judge to pick from (4 core + 9 bench = 13 total)
ALL_PERSONAS="staff-engineer, sre, product-manager, devils-advocate, security-reviewer, compliance-reviewer, dual-deploy-reviewer, performance-reviewer, finops-auditor, air-gap-reviewer, test-lead, executive-sponsor, competing-team-lead"

CORRECT=0
TOTAL=0
JUDGE_RESULTS=()

llm_judge_attribute() {
  local scorecard_path="$1"
  local actual_persona
  actual_persona=$(basename "$scorecard_path" .md)

  # Strip persona identity from content (anonymize)
  local body
  body=$(sed -E 's/(staff-engineer|sre|product-manager|devils-advocate|security-reviewer|compliance-reviewer|dual-deploy-reviewer|performance-reviewer|finops-auditor|air-gap-reviewer|test-lead|executive-sponsor|competing-team-lead)/[REDACTED]/gi' "$scorecard_path")

  local judge_prompt
  judge_prompt="Given the following anonymized review scorecard, identify which persona (from the list: ${ALL_PERSONAS}) most likely wrote this review. Consider: voice register, types of concerns raised, banned-phrase absence, characteristic objection patterns. Reply with ONLY the persona slug (e.g., 'security-reviewer').

---
${body}
---"

  local guess=""
  if command -v claude >/dev/null 2>&1; then
    guess=$(echo "$judge_prompt" | claude --print --dangerously-skip-permissions 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
  else
    printf '  SKIP: claude CLI not available for %s\n' "$actual_persona" >&2
    JUDGE_RESULTS+=("$actual_persona | [no-cli] | SKIP")
    return 1
  fi

  TOTAL=$((TOTAL + 1))
  if [ "$guess" = "$actual_persona" ]; then
    CORRECT=$((CORRECT + 1))
    JUDGE_RESULTS+=("$actual_persona | $guess | YES")
  else
    JUDGE_RESULTS+=("$actual_persona | $guess | NO")
  fi
}

# Run judge attribution for each scorecard
for sc in "${SCORECARDS[@]}"; do
  printf '  Judging: %s\n' "$(basename "$sc")"
  llm_judge_attribute "$sc"
done

# Print attribution table
printf '\n%-25s | %-25s | %s\n' "ACTUAL" "JUDGE GUESS" "CORRECT?"
printf '%-25s-+-%-25s-+-%s\n' "-------------------------" "-------------------------" "--------"
for row in "${JUDGE_RESULTS[@]}"; do
  printf '%-25s\n' "$row"
done

# Compute accuracy
if [ "$TOTAL" -eq 0 ]; then
  fail "No scorecards could be evaluated (claude CLI not available?)"
  exit 1
fi

# Integer math: accuracy as percentage (avoid bc dependency)
ACCURACY_PCT=$(( (CORRECT * 100) / TOTAL ))
printf '\nAttribution accuracy: %d/%d (%d%%)\n' "$CORRECT" "$TOTAL" "$ACCURACY_PCT"
printf 'Threshold: 80%% (PQUAL-03)\n'

if [ "$ACCURACY_PCT" -ge 80 ]; then
  printf '=== LLM-AS-JUDGE: PASSED (%d%% >= 80%%) ===\n' "$ACCURACY_PCT"
  exit 0
else
  printf '=== LLM-AS-JUDGE: FAILED (%d%% < 80%%) ===\n' "$ACCURACY_PCT" >&2
  exit 1
fi
