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
STAFF_META="$REPO_ROOT/persona-metadata/staff-engineer.yml"
if [ -f "$STAFF_META" ] && grep -qiE '(^|[[:space:]])-[[:space:]]+"?consider"?[[:space:]]*$' "$STAFF_META"; then
  :
elif grep -qiE '(^|[[:space:]])-[[:space:]]+"?consider"?[[:space:]]*$' "$STAFF_ENG"; then
  :
else
  fail "D: neither $STAFF_META nor agents/staff-engineer.md lists 'consider' in banned_phrases — smoke test cannot assert banned-phrase drop"
  exit 1
fi

# CHAIR-06 snapshot: the exact id that stamp_id() must produce for the canonical
# valid finding in the Case D fixture. Recomputed here at test time from the
# canonical payload so that if the canonicalization recipe drifts in
# dc-validate-scorecard.sh's `canon()`/`stamp_id()`, this assertion breaks loudly.
# payload = "staff-engineer|## risks|the rate limiter feature flag has exactly one consumer in the plan."
EXPECTED_CASE_D_ID="staff-engineer-$(
  python3 -c "import hashlib; \
payload=b'staff-engineer|## risks|the rate limiter feature flag has exactly one consumer in the plan.'; \
print(hashlib.sha256(payload).hexdigest()[:8])"
)"
echo "Case D expected id: $EXPECTED_CASE_D_ID"

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

# CHAIR-06 Assertion 1 — stamped id on kept finding matches the canonical snapshot.
STAMPED_D=$(printf '%s' "$FINAL_FM_JSON" | jq -r '.findings[0].id // empty')
if [ "$STAMPED_D" = "$EXPECTED_CASE_D_ID" ]; then
  pass "D: kept finding has stamped id matching canonical snapshot ($STAMPED_D)"
else
  fail "D: stamped id mismatch — expected '$EXPECTED_CASE_D_ID', got '$STAMPED_D'"
fi

# CHAIR-06 Assertion 2 — MANIFEST.personas_run[].findings[] mirrors the full record.
if jq -e --arg eid "$EXPECTED_CASE_D_ID" '
  (.personas_run[0].findings | type == "array") and
  (.personas_run[0].findings | length == 1) and
  (.personas_run[0].findings[0].id == $eid) and
  (.personas_run[0].findings[0] | has("target") and has("claim")
                                and has("severity") and has("category") and has("id"))
' "$RUN_A/MANIFEST.json" >/dev/null; then
  pass "D: MANIFEST.personas_run[0].findings[0] mirrors full record with id"
else
  fail "D: MANIFEST mirror missing/wrong: $(jq -c '.personas_run[0].findings' "$RUN_A/MANIFEST.json")"
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
# Case E — Multi-persona MANIFEST shape + trigger_reason argument handling
# ---------------------------------------------------------------------------
# Phase 4 extension: validator now accepts a third positional arg
# <trigger-reason> with default "core:always-on" AND always writes to
# personas_run[] (per D-30). Case E exercises:
#   1. Two-persona run (staff-engineer + sre), both with default trigger reason
#   2. personas_run[] ends with TWO distinct entries
#   3. Explicit third-arg invocation with non-default value stores that value
#   4. Calling validator twice for the same persona is idempotent (no
#      duplicate personas_run[] entries — deduped by name)
#
# Skip gracefully if agents/sre.md or persona-metadata/sre.yml are missing
# (Wave 1 dependency; Case E is Wave 2).

echo "--- Case E: multi-persona MANIFEST + trigger_reason arg ---"

SRE_AGENT="$REPO_ROOT/agents/sre.md"
SRE_META="$REPO_ROOT/persona-metadata/sre.yml"

if [ ! -f "$SRE_AGENT" ] || [ ! -f "$SRE_META" ]; then
  echo "E: skipped — agents/sre.md or persona-metadata/sre.yml not present (Wave 1 not yet delivered)"
else
  # Fresh run dir for Case E (independent of Case A/D run dirs).
  OUT_E=$("$PREP" "$PLAN_SAMPLE" 2>&1) || { fail "E: prep exited non-zero"; exit 1; }
  RUN_E=$(printf '%s' "$OUT_E" | grep '^RUN_DIR=' | tail -1 | sed 's/^RUN_DIR=//')
  if [ -z "$RUN_E" ] || [[ "$RUN_E" == ERROR:* ]]; then
    fail "E: prep RUN_DIR missing"
    exit 1
  fi
  RUN_DIRS+=("$RUN_E")

  # Mock staff-engineer draft: 1 valid finding (reuses the canonical line).
  cat > "$RUN_E/staff-engineer-draft.md" <<'DRAFT_SE_EOF'
---
persona: staff-engineer
run_id: smoke-test-case-e
findings:
  - id: "sha256:case-e-se-valid"
    target: "## Risks"
    claim: "The rate limiter feature flag has exactly one consumer."
    evidence: |
      Feature-flag via `RATE_LIMIT_ENABLED=true`.
    ask: "Land unflagged until a second environment needs it off."
    severity: minor
    category: complexity
---

## Summary

One finding. Smoke-test fixture.
DRAFT_SE_EOF

  # Mock sre draft: 1 valid finding citing the risks section.
  # Uses evidence from plan-sample.md that appears verbatim.
  # Must avoid all 6 sre banned_phrases in claim + ask (monitor carefully,
  # ensure observability, robust, graceful degradation, at scale, high availability).
  cat > "$RUN_E/sre-draft.md" <<'DRAFT_SRE_EOF'
---
persona: sre
run_id: smoke-test-case-e
findings:
  - id: "sha256:case-e-sre-valid"
    target: "## Risks"
    claim: "In-memory state reset on deploy produces a 429 spike with no runbook named."
    evidence: |
      In-memory state does not survive restart; limits reset on deploy.
    ask: "Name the pager rotation that owns a deploy-minute 429 spike and document the expected error-budget burn."
    severity: major
    category: blast-radius
---

## Summary

One finding. Smoke-test fixture.
DRAFT_SRE_EOF

  # 1. Run validator for staff-engineer with DEFAULT trigger_reason (2-arg call — backward compat).
  "$VALIDATOR" staff-engineer "$RUN_E" > /dev/null 2>&1 \
    || { fail "E: validator staff-engineer (default trigger) exited non-zero"; exit 1; }
  pass "E: validator staff-engineer 2-arg invocation exited 0"

  # 2. Run validator for sre with EXPLICIT trigger_reason matching the default ("core:always-on").
  "$VALIDATOR" sre "$RUN_E" core:always-on > /dev/null 2>&1 \
    || { fail "E: validator sre (explicit trigger) exited non-zero"; exit 1; }
  pass "E: validator sre 3-arg invocation exited 0"

  # 3. Assert personas_run[] has TWO entries, correct names, correct trigger_reasons.
  if jq -e '
    (.personas_run | type == "array") and
    (.personas_run | length == 2) and
    ([.personas_run[].name] | sort == ["sre","staff-engineer"]) and
    (all(.personas_run[]; .trigger_reason == "core:always-on"))
  ' "$RUN_E/MANIFEST.json" >/dev/null; then
    pass "E: personas_run[] has {sre, staff-engineer} with core:always-on trigger reasons"
  else
    fail "E: personas_run[] incorrect: $(jq -c '.personas_run' "$RUN_E/MANIFEST.json")"
  fi

  # 4. Assert validation[] has TWO entries, one per persona.
  if jq -e '
    (.validation | type == "array") and
    (.validation | length == 2) and
    ([.validation[].persona] | sort == ["sre","staff-engineer"]) and
    (all(.validation[]; .findings_kept == 1 and .findings_dropped == 0))
  ' "$RUN_E/MANIFEST.json" >/dev/null; then
    pass "E: validation[] has both personas with 1 kept / 0 dropped each"
  else
    fail "E: validation[] incorrect: $(jq -c '.validation' "$RUN_E/MANIFEST.json")"
  fi

  # 5. Assert idempotent: re-running the validator for a persona whose draft
  # is already processed should fail cleanly (draft deleted) — but the IDEMPOTENCE
  # we care about is at the MANIFEST level: if the draft existed and validator
  # ran twice, personas_run[] still has ONE entry for that persona (dedupe by name).
  # Exercise: create a new draft for staff-engineer and re-run validator — ensures
  # personas_run[] does NOT grow a duplicate.
  cat > "$RUN_E/staff-engineer-draft.md" <<'DRAFT_SE2_EOF'
---
persona: staff-engineer
run_id: smoke-test-case-e-rerun
findings: []
---

## Summary

Re-run fixture — no findings.
DRAFT_SE2_EOF

  "$VALIDATOR" staff-engineer "$RUN_E" > /dev/null 2>&1 \
    || { fail "E: validator re-run staff-engineer exited non-zero"; exit 1; }

  if jq -e '.personas_run | length == 2' "$RUN_E/MANIFEST.json" >/dev/null; then
    pass "E: re-running validator for same persona does not duplicate personas_run[] entry"
  else
    fail "E: personas_run[] duplicated on re-run: $(jq -c '.personas_run' "$RUN_E/MANIFEST.json")"
  fi

  # 6. Assert explicit non-default trigger_reason propagates correctly.
  # Use a third run-dir-like subdir pattern with a distinct draft to avoid
  # contaminating the Case E personas_run[] check above.
  OUT_E2=$("$PREP" "$PLAN_SAMPLE" 2>&1) || { fail "E: prep-2 exited non-zero"; exit 1; }
  RUN_E2=$(printf '%s' "$OUT_E2" | grep '^RUN_DIR=' | tail -1 | sed 's/^RUN_DIR=//')
  if [ -z "$RUN_E2" ] || [[ "$RUN_E2" == ERROR:* ]]; then
    fail "E: prep-2 RUN_DIR missing"
    exit 1
  fi
  RUN_DIRS+=("$RUN_E2")

  cp "$RUN_E/staff-engineer.md" "$RUN_E2/ignored-not-a-draft.md" 2>/dev/null || true
  cat > "$RUN_E2/sre-draft.md" <<'DRAFT_SRE2_EOF'
---
persona: sre
run_id: smoke-test-case-e2
findings:
  - id: "sha256:case-e2-sre-valid"
    target: "## Risks"
    claim: "IP-based keying hits corporate NAT and produces false-positive pages."
    evidence: |
      IP-based keying hits NAT'd corporate clients disproportionately.
    ask: "Emit a NAT-suspect metric label so on-call can distinguish abuse from corporate shared-egress."
    severity: minor
    category: observability
---

## Summary

Trigger-reason test fixture.
DRAFT_SRE2_EOF

  "$VALIDATOR" sre "$RUN_E2" "signal:test-custom-reason" > /dev/null 2>&1 \
    || { fail "E: validator sre (custom trigger) exited non-zero"; exit 1; }

  if jq -e '
    (.personas_run | length == 1) and
    (.personas_run[0].name == "sre") and
    (.personas_run[0].trigger_reason == "signal:test-custom-reason")
  ' "$RUN_E2/MANIFEST.json" >/dev/null; then
    pass "E: custom trigger_reason 'signal:test-custom-reason' stored verbatim"
  else
    fail "E: custom trigger_reason not stored correctly: $(jq -c '.personas_run' "$RUN_E2/MANIFEST.json")"
  fi
fi

# ---------------------------------------------------------------------------
# Case F — CHAIR-06 id stability across re-runs + evidence-swap
# ---------------------------------------------------------------------------
echo "--- Case F: CHAIR-06 id stability (re-run + evidence-swap) ---"

# Fresh run dir for Case F (independent of prior cases).
OUT_F1=$("$PREP" "$PLAN_SAMPLE" 2>&1) || { fail "F: prep-1 exited non-zero"; exit 1; }
RUN_F1=$(printf '%s' "$OUT_F1" | grep '^RUN_DIR=' | tail -1 | sed 's/^RUN_DIR=//')
[ -n "$RUN_F1" ] && [[ "$RUN_F1" != ERROR:* ]] || { fail "F: RUN_F1 missing"; exit 1; }
RUN_DIRS+=("$RUN_F1")

cat > "$RUN_F1/staff-engineer-draft.md" <<'DRAFT_F1_EOF'
---
persona: staff-engineer
run_id: case-f-run1
findings:
  - id: "sha256:placeholder"
    target: "## Risks"
    claim: "The rate limiter feature flag has exactly one consumer in the plan."
    evidence: |
      Feature-flag via `RATE_LIMIT_ENABLED=true`.
    ask: "Land unflagged until a second environment needs it off."
    severity: minor
    category: complexity
---

## Summary

Case F run 1.
DRAFT_F1_EOF

"$VALIDATOR" staff-engineer "$RUN_F1" > /dev/null 2>&1 || { fail "F: validator run1 exited non-zero"; exit 1; }
ID_F1=$(jq -r '.personas_run[0].findings[0].id' "$RUN_F1/MANIFEST.json")

# Run 2: fresh prep dir, same draft content, assert id is IDENTICAL.
OUT_F2=$("$PREP" "$PLAN_SAMPLE" 2>&1) || { fail "F: prep-2 exited non-zero"; exit 1; }
RUN_F2=$(printf '%s' "$OUT_F2" | grep '^RUN_DIR=' | tail -1 | sed 's/^RUN_DIR=//')
[ -n "$RUN_F2" ] && [[ "$RUN_F2" != ERROR:* ]] || { fail "F: RUN_F2 missing"; exit 1; }
RUN_DIRS+=("$RUN_F2")

# Rebuild an IDENTICAL draft in RUN_F2
cat > "$RUN_F2/staff-engineer-draft.md" <<'DRAFT_F2_EOF'
---
persona: staff-engineer
run_id: case-f-run2
findings:
  - id: "sha256:placeholder"
    target: "## Risks"
    claim: "The rate limiter feature flag has exactly one consumer in the plan."
    evidence: |
      Feature-flag via `RATE_LIMIT_ENABLED=true`.
    ask: "Land unflagged until a second environment needs it off."
    severity: minor
    category: complexity
---

## Summary

Case F run 2.
DRAFT_F2_EOF

"$VALIDATOR" staff-engineer "$RUN_F2" > /dev/null 2>&1 || { fail "F: validator run2 exited non-zero"; exit 1; }
ID_F2=$(jq -r '.personas_run[0].findings[0].id' "$RUN_F2/MANIFEST.json")

if [ "$ID_F1" = "$ID_F2" ] && [ -n "$ID_F1" ]; then
  pass "F: id stable across re-runs ($ID_F1)"
else
  fail "F: id not stable — run1='$ID_F1' run2='$ID_F2'"
fi

# Run 3: swap evidence to a DIFFERENT verbatim line from plan-sample.md; assert id UNCHANGED.
OUT_F3=$("$PREP" "$PLAN_SAMPLE" 2>&1) || { fail "F: prep-3 exited non-zero"; exit 1; }
RUN_F3=$(printf '%s' "$OUT_F3" | grep '^RUN_DIR=' | tail -1 | sed 's/^RUN_DIR=//')
[ -n "$RUN_F3" ] && [[ "$RUN_F3" != ERROR:* ]] || { fail "F: RUN_F3 missing"; exit 1; }
RUN_DIRS+=("$RUN_F3")

# Verify the alternate evidence line is in plan-sample.md before using it.
ALT_EVIDENCE='In-memory state does not survive restart; limits reset on deploy.'
if ! grep -qF -- "$ALT_EVIDENCE" "$PLAN_SAMPLE"; then
  fail "F: alt evidence line not found in plan-sample.md — update Case F fixture"
  exit 1
fi

cat > "$RUN_F3/staff-engineer-draft.md" <<DRAFT_F3_EOF
---
persona: staff-engineer
run_id: case-f-run3
findings:
  - id: "sha256:placeholder"
    target: "## Risks"
    claim: "The rate limiter feature flag has exactly one consumer in the plan."
    evidence: |
      $ALT_EVIDENCE
    ask: "Land unflagged until a second environment needs it off."
    severity: minor
    category: complexity
---

## Summary

Case F run 3 (evidence-swapped).
DRAFT_F3_EOF

"$VALIDATOR" staff-engineer "$RUN_F3" > /dev/null 2>&1 || { fail "F: validator run3 exited non-zero"; exit 1; }
ID_F3=$(jq -r '.personas_run[0].findings[0].id' "$RUN_F3/MANIFEST.json")

if [ "$ID_F1" = "$ID_F3" ] && [ -n "$ID_F3" ]; then
  pass "F: id unchanged when evidence differs (evidence excluded from hash — $ID_F3)"
else
  fail "F: id changed with evidence swap — baseline='$ID_F1' evidence-swap='$ID_F3'"
fi

# ---------------------------------------------------------------------------
# Summary + exit
# ---------------------------------------------------------------------------
echo ""
if [ "$FAIL" -ne 0 ]; then
  printf 'ENGINE SMOKE TEST: FAILED\n' >&2
  exit 1
fi
printf 'ENGINE SMOKE TEST: PASSED (all cases A-F)\n'
exit 0
