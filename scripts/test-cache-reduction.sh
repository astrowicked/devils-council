#!/usr/bin/env bash
# test-cache-reduction.sh — BNCH-06 + D-61 observable reduction assertion.
#
# Per 06-CACHE-SPIKE-MEMO.md, this script's assertion shape is one of three:
#   Outcome A: observable_reduction_pct >= 0.5 on 4+ persona run
#   Outcome B: cache_summary.measurement_available == false OR cache_stats
#              keys present (null values permitted) — schema-shape contract
#              downgraded from reduction-threshold per MEMO Plan 07 Directive
#   Outcome C: cache_summary.note present AND measurement_available == false
#
# Execution mode:
#   - If `claude` CLI is on PATH AND DC_SKIP_LIVE_CACHE_TEST is not set,
#     runs a live /devils-council:review against the fixture and asserts
#     the MANIFEST post-run.
#   - Otherwise, SKIP with a banner (exit 0) — the assertion is not a
#     hard CI blocker in the skip case; the live run is a phase-gate check.
#     Default CI behavior is to set DC_SKIP_LIVE_CACHE_TEST=1 until Outcome A
#     is confirmed and cost budget allows live runs (06-VALIDATION.md).

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

FIXTURE="$REPO_ROOT/tests/fixtures/bench-personas/cache-reduction-fixture.md"
MEMO="$REPO_ROOT/.planning/phases/06-classifier-bench-personas-cost-instrumentation/06-CACHE-SPIKE-MEMO.md"

FAIL=0
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }

# ---------------------------------------------------------------------------
# Skip conditions (checked first — fast-path exit 0)
# ---------------------------------------------------------------------------
if [ -n "${DC_SKIP_LIVE_CACHE_TEST:-}" ]; then
  echo "SKIP: DC_SKIP_LIVE_CACHE_TEST is set"
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "SKIP: claude CLI not on PATH; cache-reduction assertion requires live claude invocation"
  exit 0
fi

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
[ -f "$FIXTURE" ]  || { fail "fixture missing: $FIXTURE"; exit 1; }
[ -f "$MEMO" ]     || { fail "06-CACHE-SPIKE-MEMO.md missing — Plan 01 (spike) must land before test-cache-reduction.sh"; exit 1; }
command -v jq >/dev/null 2>&1 || { fail "jq required on PATH"; exit 1; }

# ---------------------------------------------------------------------------
# Parse spike outcome from MEMO: line immediately after '## Outcome' heading,
# skipping blank lines.
# ---------------------------------------------------------------------------
SPIKE_OUTCOME=$(awk '/^## Outcome$/{getline; while ($0 ~ /^[[:space:]]*$/) getline; print; exit}' "$MEMO")
SPIKE_OUTCOME=$(printf '%s' "$SPIKE_OUTCOME" | tr -d '[:space:]')
case "$SPIKE_OUTCOME" in
  A|B|C) pass "spike outcome parsed: $SPIKE_OUTCOME" ;;
  *) fail "MEMO outcome not one of A|B|C (got: '$SPIKE_OUTCOME')"; exit 1 ;;
esac

# ---------------------------------------------------------------------------
# Run the review headlessly via `claude` CLI
# ---------------------------------------------------------------------------
RUN_OUT=$(mktemp)
trap 'rm -f "$RUN_OUT"' EXIT

echo "--- Running /devils-council:review against $FIXTURE ---"
set +e
claude --plugin-dir "$REPO_ROOT" -p "/devils-council:review $FIXTURE" > "$RUN_OUT" 2>&1
RC=$?
set -e

if [ "$RC" -ne 0 ]; then
  echo "--- claude invocation stderr/stdout ---"
  cat "$RUN_OUT"
  fail "claude invocation exit $RC"
  exit 1
fi

# Locate the most recent run dir
RUN_DIR=$(ls -td .council/*/ 2>/dev/null | head -1 | sed 's:/$::')
[ -n "$RUN_DIR" ] && [ -d "$RUN_DIR" ] || { fail "no run dir found under .council/"; exit 1; }
MANIFEST="$RUN_DIR/MANIFEST.json"
[ -f "$MANIFEST" ] || { fail "MANIFEST.json missing at $MANIFEST"; exit 1; }

pass "run directory: $RUN_DIR"

# ---------------------------------------------------------------------------
# Preliminary gates (common to all outcomes)
# ---------------------------------------------------------------------------

# 4+ personas ran (core 4 + at least 1 bench from the fixture)
PERSONA_COUNT=$(jq -r '.personas_run | length' "$MANIFEST")
if [ "$PERSONA_COUNT" -ge 4 ]; then
  pass "personas_run count >= 4 (got $PERSONA_COUNT)"
else
  fail "expected personas_run >= 4 (got $PERSONA_COUNT); cache-reduction measurement requires 4+ personas per D-61"
  exit 1
fi

# cache_summary block exists
if jq -e '.cache_summary' "$MANIFEST" >/dev/null 2>&1; then
  pass "MANIFEST.cache_summary present"
else
  fail "MANIFEST.cache_summary missing — Plan 07 Task 2 wiring not active"
  exit 1
fi

# ---------------------------------------------------------------------------
# Branched assertion per spike outcome
# ---------------------------------------------------------------------------
case "$SPIKE_OUTCOME" in
  A)
    # D-61 as written: observable_reduction_pct >= 0.5
    OBS=$(jq -r '.cache_summary.observable_reduction_pct // 0' "$MANIFEST")
    # Compare as float using awk
    RESULT=$(awk -v o="$OBS" 'BEGIN { print (o >= 0.5) ? "PASS" : "FAIL" }')
    if [ "$RESULT" = "PASS" ]; then
      pass "observable_reduction_pct ($OBS) >= 0.5"
    else
      fail "observable_reduction_pct ($OBS) < 0.5"
    fi
    if jq -e '.cache_summary.measurement_available == true' "$MANIFEST" >/dev/null; then
      pass "measurement_available = true"
    else
      fail "measurement_available expected true in Outcome A"
    fi
    ;;

  B)
    # Outcome B per MEMO: schema-shape contract. Either:
    #   (1) measurement_available == false (cache observability not surfaced)
    #   (2) cache_summary schema keys present AND every persona has cache_stats
    #       with the 4 required keys (values may be null)
    # Per plan_specific_note: RELAXED — EITHER condition passes. This is a
    # schema-forward contract: when a future Claude Code release exposes
    # subagent usage to the plugin, values populate and Outcome A tightens
    # the assertion cleanly (no schema change needed).
    MEASURED_FALSE=0
    SCHEMA_OK=0

    if jq -e '.cache_summary.measurement_available == false' "$MANIFEST" >/dev/null; then
      MEASURED_FALSE=1
      pass "measurement_available = false (Outcome B truthy branch 1)"
    fi

    if jq -e '
      (.cache_summary | has("overall_hit_ratio"))
      and (.cache_summary | has("personas_count"))
      and (.cache_summary | has("observable_reduction_pct"))
      and (.personas_run | all(
          .cache_stats != null
          and (.cache_stats | has("input_tokens")
                           and has("cache_creation_input_tokens")
                           and has("cache_read_input_tokens")
                           and has("cache_hit_ratio"))
        ))
    ' "$MANIFEST" >/dev/null; then
      SCHEMA_OK=1
      pass "cache_summary schema keys present AND every persona has cache_stats with 4 keys (values may be null)"
    fi

    if [ "$MEASURED_FALSE" -eq 0 ] && [ "$SCHEMA_OK" -eq 0 ]; then
      fail "Outcome B requires EITHER measurement_available=false OR cache_summary+cache_stats schema keys present; neither truthy"
    fi
    ;;

  C)
    # note present + measurement_available == false
    if jq -e '.cache_summary.measurement_available == false' "$MANIFEST" >/dev/null; then
      pass "measurement_available = false (Outcome C)"
    else
      fail "Outcome C expects measurement_available = false"
    fi
    if jq -e '.cache_summary.note | type == "string" and length > 0' "$MANIFEST" >/dev/null; then
      pass "cache_summary.note documents no-cache condition"
    else
      fail "Outcome C expects cache_summary.note (non-empty string)"
    fi
    ;;
esac

exit "$FAIL"
