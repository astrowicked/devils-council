#!/usr/bin/env bash
# test-engine-smoke.sh — CI smoke test for Phase 3 engine shell components.
#
# Per ADD-2: tests bin/dc-prep.sh and bin/dc-validate-scorecard.sh directly
# with a mocked subagent draft file. Does NOT invoke `claude` headlessly.
#
# Covers:
#   A. dc-prep.sh happy path on tests/fixtures/plan-sample.md
#      (run dir, INPUT.md byte-identical, MANIFEST.json v1 schema).
#   B. dc-prep.sh --type=code-diff override wins over auto-classifier.
#   C. dc-prep.sh error path on a missing file (RUN_DIR=ERROR:, non-zero exit).
#   D. dc-validate-scorecard.sh on a 3-finding mocked draft
#      (1 kept, 2 dropped with reasons evidence_not_verbatim +
#      banned_phrase_detected, MANIFEST.json validation[] entry + counters).
#
# Exits 0 if every assertion passes, 1 otherwise.
# Designed to run in <10s on both ubuntu-latest and macos-latest.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

cd "$REPO_ROOT"

PREP="$REPO_ROOT/bin/dc-prep.sh"
VALIDATOR="$REPO_ROOT/bin/dc-validate-scorecard.sh"
PLAN_SAMPLE="$REPO_ROOT/tests/fixtures/plan-sample.md"
STAFF_ENG="$REPO_ROOT/agents/staff-engineer.md"

FAIL=0
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }

# Track run dirs for cleanup at end.
RUN_DIRS=()
cleanup() {
  for d in "${RUN_DIRS[@]:-}"; do
    [ -n "${d:-}" ] && rm -rf "$d" 2>/dev/null || true
  done
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Preflight — required files exist + executable (fail-loud, not silent-skip).
# ---------------------------------------------------------------------------
[ -x "$PREP" ]        || { fail "bin/dc-prep.sh missing or not executable"; exit 1; }
[ -x "$VALIDATOR" ]   || { fail "bin/dc-validate-scorecard.sh missing or not executable"; exit 1; }
[ -f "$PLAN_SAMPLE" ] || { fail "tests/fixtures/plan-sample.md missing"; exit 1; }
[ -f "$STAFF_ENG" ]   || { fail "agents/staff-engineer.md missing — Plan 03 is a hard dependency (see depends_on)"; exit 1; }

# Sanity: the string we'll reuse as "valid evidence" actually appears in plan-sample.md.
# Defends T-03-27 — if fixture drifts, fail fast instead of a confusing assertion error.
if ! grep -qF -- 'Feature-flag via `RATE_LIMIT_ENABLED=true`.' "$PLAN_SAMPLE"; then
  fail "plan-sample.md no longer contains the canonical valid-evidence line — update the smoke test"
  exit 1
fi

# ---------------------------------------------------------------------------
# Case A — dc-prep.sh happy path on plan-sample.md
# ---------------------------------------------------------------------------
echo "--- Case A: dc-prep.sh happy path on plan-sample.md ---"

OUT_A=$("$PREP" "$PLAN_SAMPLE" 2>&1) || { fail "A: prep exited non-zero"; exit 1; }
RUN_A=$(printf '%s' "$OUT_A" | grep '^RUN_DIR=' | tail -1 | sed 's/^RUN_DIR=//')

if [ -z "$RUN_A" ] || [[ "$RUN_A" == ERROR:* ]]; then
  fail "A: prep did not emit RUN_DIR=<path> (got: $OUT_A)"
  exit 1
else
  RUN_DIRS+=("$RUN_A")
  pass "A: prep emitted RUN_DIR=$RUN_A"
fi

[ -d "$RUN_A" ]                         && pass "A: run dir exists"          || fail "A: run dir missing: $RUN_A"
[ -f "$RUN_A/INPUT.md" ]                && pass "A: INPUT.md exists"         || fail "A: INPUT.md missing"
[ -f "$RUN_A/MANIFEST.json" ]           && pass "A: MANIFEST.json exists"    || fail "A: MANIFEST.json missing"
cmp -s "$PLAN_SAMPLE" "$RUN_A/INPUT.md" && pass "A: INPUT.md byte-identical to source" \
                                        || fail "A: INPUT.md differs from source"

# MANIFEST v1 schema assertions (ENGN-08 regression guard).
if jq -e '
  .artifact_path and
  (.detected_type | type == "string") and
  .run_dir and
  .started_at and
  (.sha256 | type == "string" and length == 64) and
  (.nonce | type == "string" and (length >= 6 and length <= 8)) and
  (.bytes | type == "number") and
  (.personas_run | type == "array" and length == 0) and
  (.findings_kept | type == "number" and . == 0) and
  (.findings_dropped | type == "number" and . == 0) and
  (has("budget_usage")) and
  (.budget_usage == null or (.budget_usage | type == "object"))
' "$RUN_A/MANIFEST.json" >/dev/null; then
  pass "A: MANIFEST.json v1 schema intact (all required fields, nonce 6-8 hex, counters zero, budget_usage field present)"
else
  fail "A: MANIFEST.json schema violation: $(cat "$RUN_A/MANIFEST.json")"
fi

# ---------------------------------------------------------------------------
# Case B — --type=code-diff override wins over auto-detect (D-06)
# ---------------------------------------------------------------------------
echo "--- Case B: --type=code-diff override on plan-sample.md ---"

OUT_B=$("$PREP" "$PLAN_SAMPLE" --type=code-diff 2>&1) || { fail "B: prep exited non-zero"; exit 1; }
RUN_B=$(printf '%s' "$OUT_B" | grep '^RUN_DIR=' | tail -1 | sed 's/^RUN_DIR=//')
if [ -z "$RUN_B" ] || [[ "$RUN_B" == ERROR:* ]]; then
  fail "B: prep did not emit RUN_DIR=<path> (got: $OUT_B)"
  exit 1
fi
RUN_DIRS+=("$RUN_B")

if jq -e '.detected_type == "code-diff"' "$RUN_B/MANIFEST.json" >/dev/null; then
  pass "B: --type=code-diff override took effect"
else
  fail "B: override ignored (detected_type = $(jq -r '.detected_type' "$RUN_B/MANIFEST.json"))"
fi

# ---------------------------------------------------------------------------
# Case C — dc-prep.sh error path on missing file
# ---------------------------------------------------------------------------
echo "--- Case C: dc-prep.sh error path on missing file ---"

set +e
OUT_C=$("$PREP" "$REPO_ROOT/tests/fixtures/does-not-exist.md" 2>&1)
RC_C=$?
set -e

if [ "$RC_C" -eq 0 ]; then
  fail "C: prep should have exited non-zero on missing file (got rc=0)"
fi

if printf '%s' "$OUT_C" | grep -q '^RUN_DIR=ERROR:'; then
  pass "C: missing file produced RUN_DIR=ERROR: (rc=$RC_C)"
else
  fail "C: expected RUN_DIR=ERROR:, got: $OUT_C"
fi

# ---------------------------------------------------------------------------
# Case D — dc-validate-scorecard.sh with 3-finding mocked draft
# ---------------------------------------------------------------------------
echo "--- Case D: dc-validate-scorecard.sh with 3-finding mocked draft ---"

# T-03-28 defense: staff-engineer's banned_phrases must include the word we'll
# plant in the fixture's CLAIM ("consider"). If that guarantee regresses, fail
# fast — a silent validator pass here would be a dangerous false-negative.
# Check sidecar first (preferred per plugin schema compat), fall back to .md frontmatter.
STAFF_META="${STAFF_ENG%.md}.meta.yml"
if [ -f "$STAFF_META" ] && grep -qiE '(^|[[:space:]])-[[:space:]]+"?consider"?[[:space:]]*$' "$STAFF_META"; then
  :
elif grep -qiE '(^|[[:space:]])-[[:space:]]+"?consider"?[[:space:]]*$' "$STAFF_ENG"; then
  :
else
  fail "D: neither $STAFF_META nor agents/staff-engineer.md lists 'consider' in banned_phrases — smoke test cannot assert banned-phrase drop"
  exit 1
fi

# Mocked draft: 1 valid + 1 fabricated-evidence + 1 banned-phrase-in-claim.
# Pitfall 3 guarantee: only claim/ask are scanned for banned phrases, NOT
# evidence — so the banned-phrase finding's evidence reuses the valid line.
cat > "$RUN_A/staff-engineer-draft.md" <<'DRAFT_EOF'
---
persona: staff-engineer
run_id: smoke-test
findings:
  - id: "sha256:valid-finding"
    target: "## Risks"
    claim: "The rate limiter feature flag has exactly one consumer in the plan."
    evidence: |
      Feature-flag via `RATE_LIMIT_ENABLED=true`.
    ask: "Land unflagged until a second environment needs it off."
    severity: minor
    category: complexity
  - id: "sha256:fabricated-evidence"
    target: "## Risks"
    claim: "Something that is not in the artifact at all."
    evidence: |
      THIS STRING DOES NOT APPEAR IN PLAN-SAMPLE AT ALL xyz123
    ask: "Remove the thing that is not there."
    severity: major
    category: complexity
  - id: "sha256:banned-phrase"
    target: "## Approach"
    claim: "You should consider edge cases in the CSV parser."
    evidence: |
      Feature-flag via `RATE_LIMIT_ENABLED=true`.
    ask: "Think about what happens on large inputs."
    severity: minor
    category: complexity
---

## Summary

Three-finding smoke-test draft: one valid, one fabricated-evidence, one
banned-phrase. Expected: 1 kept, 2 dropped.
DRAFT_EOF

"$VALIDATOR" staff-engineer "$RUN_A" > /dev/null 2>&1 || { fail "D: validator exited non-zero"; exit 1; }
pass "D: validator exited 0"

# Draft deleted, final written.
if [ ! -f "$RUN_A/staff-engineer-draft.md" ]; then
  pass "D: draft deleted"
else
  fail "D: draft still present at $RUN_A/staff-engineer-draft.md"
fi
if [ -f "$RUN_A/staff-engineer.md" ]; then
  pass "D: final scorecard written"
else
  fail "D: final scorecard missing"
  exit 1
fi

# Extract final-scorecard frontmatter → JSON (yq if present, python3 + PyYAML otherwise).
FINAL_FM_JSON=$(awk '
  BEGIN { in_fm = 0; seen = 0 }
  NR == 1 && $0 ~ /^---[[:space:]]*$/ { in_fm = 1; seen = 1; next }
  in_fm && $0 ~ /^---[[:space:]]*$/ { exit }
  in_fm { print }
  !seen { exit }
' "$RUN_A/staff-engineer.md" \
  | if command -v yq >/dev/null 2>&1; then
      yq eval -o=json '.' -
    else
      python3 -c 'import sys,yaml,json;print(json.dumps(yaml.safe_load(sys.stdin)))'
    fi)

# 1 kept finding.
if printf '%s' "$FINAL_FM_JSON" | jq -e '(.findings | length) == 1' >/dev/null; then
  pass "D: final scorecard has exactly 1 kept finding"
else
  fail "D: expected 1 kept finding, got $(printf '%s' "$FINAL_FM_JSON" | jq '.findings | length')"
fi

# 2 dropped findings.
if printf '%s' "$FINAL_FM_JSON" | jq -e '(.dropped_findings | length) == 2' >/dev/null; then
  pass "D: dropped_findings has 2 entries"
else
  fail "D: expected 2 dropped_findings entries, got $(printf '%s' "$FINAL_FM_JSON" | jq '.dropped_findings | length')"
fi

# Drop reasons = {banned_phrase_detected, evidence_not_verbatim}.
if printf '%s' "$FINAL_FM_JSON" \
  | jq -e '[.dropped_findings[].reason] | sort == ["banned_phrase_detected","evidence_not_verbatim"]' >/dev/null; then
  pass "D: drop reasons are {banned_phrase_detected, evidence_not_verbatim}"
else
  fail "D: drop reasons incorrect: $(printf '%s' "$FINAL_FM_JSON" | jq -c '[.dropped_findings[].reason] | sort')"
fi

# MANIFEST.json validation[] entry + counters + personas_run[] object schema.
# T-03-32 defense: budget_usage key must still exist (ENGN-08 schema guard).
if jq -e '
  (.validation | type == "array" and length == 1) and
  (.validation[0].persona == "staff-engineer") and
  (.validation[0].findings_kept == 1) and
  (.validation[0].findings_dropped == 2) and
  (.personas_run | type == "array" and length == 1) and
  (.personas_run[0].name == "staff-engineer") and
  (.personas_run[0].trigger_reason != null) and
  (.findings_kept == 1) and
  (.findings_dropped == 2) and
  (has("budget_usage")) and
  (.budget_usage == null or (.budget_usage | type == "object"))
' "$RUN_A/MANIFEST.json" >/dev/null; then
  pass "D: MANIFEST.json validation summary correct (personas_run object schema + budget_usage field present)"
else
  fail "D: MANIFEST validation wrong: $(jq -c '.validation, .personas_run, .findings_kept, .findings_dropped, .budget_usage' "$RUN_A/MANIFEST.json")"
fi

# Enumerated drop_reasons in validation[] entry (ENGN-05 guard).
if jq -e '
  (.validation[0].drop_reasons | type == "array") and
  ((.validation[0].drop_reasons | sort) as $r
    | $r == ["banned_phrase_detected","evidence_not_verbatim"]
      or ($r | length) == 2)
' "$RUN_A/MANIFEST.json" >/dev/null; then
  pass "D: MANIFEST.validation[0].drop_reasons enumerates both drops"
else
  fail "D: validation[0].drop_reasons missing/incomplete: $(jq -c '.validation[0].drop_reasons' "$RUN_A/MANIFEST.json")"
fi

# Pitfall 3 guarantee: banned-phrase drop matched CLAIM ("consider") or ASK
# ("think about"), NOT evidence. If a regression makes the validator scan
# evidence, this assertion will fail or the valid finding will also be dropped.
BP_REASON=$(printf '%s' "$FINAL_FM_JSON" \
  | jq -r '.dropped_findings[] | select(.reason=="banned_phrase_detected") | .phrase // empty')
case "$BP_REASON" in
  consider|"think about"|"Think about"|Consider)
    pass "D: banned-phrase drop matched 'consider' or 'think about' (got: $BP_REASON)"
    ;;
  "")
    # Validator may not surface .phrase; tolerate empty if the reason is correct.
    # The primary assertion (drop reasons set) already covered the main contract.
    pass "D: banned-phrase drop reason correct (phrase field not surfaced)"
    ;;
  *)
    fail "D: banned-phrase drop phrase unexpected: '$BP_REASON'"
    ;;
esac

# ---------------------------------------------------------------------------
# Summary + exit
# ---------------------------------------------------------------------------
echo ""
if [ "$FAIL" -ne 0 ]; then
  printf 'ENGINE SMOKE TEST: FAILED\n' >&2
  exit 1
fi
printf 'ENGINE SMOKE TEST: PASSED (all cases A-D)\n'
exit 0
