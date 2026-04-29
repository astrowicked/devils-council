#!/usr/bin/env bash
# test-budget-cap.sh — Exercises bin/dc-budget-plan.sh against 6 cap scenarios.
# Uses pre-baked classifier fixtures so the test doesn't depend on live classify.py.
#
# Scenarios (per D-58, D-04, D-05):
#   1. under-cap-all-fit         — 4 triggered, cap=$0.50 / $0.08 = 6 max → all 4 spawn
#   2. over-cap-priority-selection — 4 triggered, tight cap=$0.08 → only security spawns (priority)
#   3. --only filter              — narrows to subset of triggered
#   4. --exclude filter           — removes from triggered set
#   5. --cap-usd override + over-budget → cap_exceeded error in MANIFEST.budget.errors[]
#   6. 9bench-all-triggered      — 9 triggered, cap=$0.50 / $0.08 = 6 max → top 6 by priority, 3 skipped
#
# Bonus validation (not a numbered scenario):
#   - --cap-usd=unlimited → exit 2 (non-numeric rejected)

set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

FAIL=0
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }

TEST_DIRS=()
TEST_FILES=()
cleanup() {
  for d in "${TEST_DIRS[@]:-}"; do [ -n "${d:-}" ] && rm -rf "$d" 2>/dev/null || true; done
  for f in "${TEST_FILES[@]:-}"; do [ -n "${f:-}" ] && rm -f "$f" 2>/dev/null || true; done
}
trap cleanup EXIT

# Tight config for over-budget scenarios (cap=0.08, per=0.08, max=1)
TIGHT_CONFIG=$(mktemp)
TEST_FILES+=("$TIGHT_CONFIG")
cat > "$TIGHT_CONFIG" <<'JSON'
{
  "budget": {
    "cap_usd": 0.08,
    "per_persona_estimate_usd": 0.08,
    "bench_priority_order": ["security-reviewer","dual-deploy-reviewer","finops-auditor","air-gap-reviewer"],
    "wall_clock_cap_seconds": 30
  }
}
JSON

# run_case: copies fixture into a tmp MANIFEST, invokes dc-budget-plan.sh with the
# given config + extra flags, echoes stdout and a __MF__<path>__MF__ marker so the
# caller can pick out both the SPAWN_BENCH line and the MANIFEST path.
run_case() {
  local name="$1"; shift
  local fixture="$1"; shift
  local config_path="$1"; shift
  # Remaining args are flags to bin/dc-budget-plan.sh

  local tmpdir; tmpdir=$(mktemp -d)
  TEST_DIRS+=("$tmpdir")
  cp "$REPO_ROOT/tests/fixtures/bench-personas/$fixture" "$tmpdir/MANIFEST.json"

  local out
  set +e
  out=$(bash "$REPO_ROOT/bin/dc-budget-plan.sh" "$tmpdir" --config="$config_path" "$@" 2>&1)
  local rc=$?
  set -e

  printf -- '--- %s (rc=%d) ---\n' "$name" "$rc" >&2
  printf '%s\n' "$out" >&2

  # Emit SPAWN line + MANIFEST marker on stdout so caller can parse
  local spawn
  spawn=$(printf '%s\n' "$out" | grep '^SPAWN_BENCH=' | head -1 | sed 's/^SPAWN_BENCH=//' || true)
  printf '%s\n' "$spawn"
  printf '__MF__%s__MF__\n' "$tmpdir/MANIFEST.json"
  return "$rc"
}

assert_spawn_equals() {
  local name="$1" got="$2" expected="$3"
  if [ "$got" = "$expected" ]; then pass "$name: SPAWN_BENCH=$got"
  else fail "$name: expected SPAWN_BENCH='$expected', got '$got'"
  fi
}

assert_manifest_field() {
  local name="$1" mf="$2" filter="$3" expected="$4"
  local got; got=$(jq -r "$filter" "$mf")
  if [ "$got" = "$expected" ]; then pass "$name: $filter == $expected"
  else fail "$name: expected $filter == '$expected', got '$got'"
  fi
}

extract_spawn() { printf '%s' "$1" | grep -v '^__MF__' | head -1; }
extract_mf()    { printf '%s' "$1" | grep '^__MF__' | sed 's/__MF__//g'; }

# Case 1: under-cap-all-fit (cap=0.50, per=0.08, max=6; triggered=4; all fit)
out=$(run_case "under-cap-all-fit" "budget-classifier-all-bench.json" "$REPO_ROOT/config.json")
spawn=$(extract_spawn "$out")
mf=$(extract_mf "$out")
assert_spawn_equals "under-cap-all-fit" "$spawn" "security-reviewer,dual-deploy-reviewer,finops-auditor,air-gap-reviewer"
assert_manifest_field "under-cap-all-fit" "$mf" '.budget.over_budget' 'false'
assert_manifest_field "under-cap-all-fit" "$mf" '.budget.spawned_bench_count' '4'
assert_manifest_field "under-cap-all-fit" "$mf" '.personas_skipped | length' '0'

# Case 2: over-cap-priority-selection (cap=0.08, per=0.08, max=1; triggered=4; security wins)
out=$(run_case "over-cap-priority-selection" "budget-classifier-all-bench.json" "$TIGHT_CONFIG")
spawn=$(extract_spawn "$out")
mf=$(extract_mf "$out")
assert_spawn_equals "over-cap-priority-selection" "$spawn" "security-reviewer"
assert_manifest_field "over-cap-priority-selection" "$mf" '.budget.over_budget' 'true'
assert_manifest_field "over-cap-priority-selection" "$mf" '.budget.max_spawnable_bench' '1'
assert_manifest_field "over-cap-priority-selection" "$mf" '.personas_skipped | map(.reason) | unique | sort | join(",")' 'budget_cap'

# Case 3: --only filter (only finops-auditor; under cap)
out=$(run_case "only-filter" "budget-classifier-all-bench.json" "$REPO_ROOT/config.json" "--only=finops-auditor")
spawn=$(extract_spawn "$out")
mf=$(extract_mf "$out")
assert_spawn_equals "only-filter" "$spawn" "finops-auditor"
assert_manifest_field "only-filter" "$mf" '.personas_skipped | length' '3'
assert_manifest_field "only-filter" "$mf" '.personas_skipped | map(.reason) | unique | sort | join(",")' 'excluded_by_flag'

# Case 4: --exclude filter (exclude finops + air-gap; under cap; security + dual-deploy remain)
out=$(run_case "exclude-filter" "budget-classifier-all-bench.json" "$REPO_ROOT/config.json" "--exclude=finops-auditor,air-gap-reviewer")
spawn=$(extract_spawn "$out")
mf=$(extract_mf "$out")
assert_spawn_equals "exclude-filter" "$spawn" "security-reviewer,dual-deploy-reviewer"
assert_manifest_field "exclude-filter" "$mf" '.personas_skipped | length' '2'
assert_manifest_field "exclude-filter" "$mf" '.personas_skipped | map(.reason) | unique | sort | join(",")' 'excluded_by_flag'

# Case 5: --cap-usd override WITH over-budget → cap_exceeded error pre-spawn
# cap=0.08 override means max=1; triggered=4; --cap-usd provided and exceeded → errors[] non-empty
out=$(run_case "cap-usd-override-over-budget" "budget-classifier-all-bench.json" "$REPO_ROOT/config.json" "--cap-usd=0.08")
spawn=$(extract_spawn "$out")
mf=$(extract_mf "$out")
assert_spawn_equals "cap-usd-override-over-budget" "$spawn" "security-reviewer"
assert_manifest_field "cap-usd-override-over-budget" "$mf" '.budget.errors[0].code' 'cap_exceeded'
assert_manifest_field "cap-usd-override-over-budget" "$mf" '.budget.errors[0].requested_personas' '4'
assert_manifest_field "cap-usd-override-over-budget" "$mf" '.budget.errors[0].allowed' '1'

# Case 6: 9bench-all-triggered — cap=0.50, per=0.08, max=6; triggered=9; top-6 by priority_order (D-04, D-05, REL-01)
out=$(run_case "9bench-all-triggered" "budget-classifier-9bench-all.json" "$REPO_ROOT/config.json")
spawn=$(extract_spawn "$out")
mf=$(extract_mf "$out")
# Top-6 by priority_order: security-reviewer, compliance-reviewer, dual-deploy-reviewer, performance-reviewer, finops-auditor, air-gap-reviewer
assert_spawn_equals "9bench-all-triggered" "$spawn" "security-reviewer,compliance-reviewer,dual-deploy-reviewer,performance-reviewer,finops-auditor,air-gap-reviewer"
assert_manifest_field "9bench-all-triggered" "$mf" '.budget.over_budget' 'true'
assert_manifest_field "9bench-all-triggered" "$mf" '.budget.max_spawnable_bench' '6'
assert_manifest_field "9bench-all-triggered" "$mf" '.budget.spawned_bench_count' '6'
# At least 3 personas skipped with reason: budget_cap (D-05)
assert_manifest_field "9bench-all-triggered" "$mf" '.personas_skipped | map(select(.reason == "budget_cap")) | length' '3'
# Verify the 3 skipped are the bottom-3 by priority: test-lead, executive-sponsor, competing-team-lead
assert_manifest_field "9bench-all-triggered" "$mf" '.personas_skipped | map(.persona) | sort | join(",")' 'competing-team-lead,executive-sponsor,test-lead'

# Bonus validation: --cap-usd non-numeric → exit 2 (D-58 no-sentinel rule)
set +e
bash "$REPO_ROOT/bin/dc-budget-plan.sh" "/tmp" --cap-usd=unlimited --config="$REPO_ROOT/config.json" >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" -eq 2 ]; then pass "non-numeric --cap-usd rejected (rc=2)"
else fail "non-numeric --cap-usd should exit 2, got $rc"
fi

if [ "$FAIL" -eq 0 ]; then
  printf '\nAll budget-cap scenarios passed.\n'
else
  printf '\nBudget-cap test FAILED.\n' >&2
fi
exit "$FAIL"
