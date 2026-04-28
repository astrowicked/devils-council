#!/usr/bin/env bash
# test-classify.sh — per-signal fixture tests for lib/classify.py via bin/dc-classify.sh.
#
# Phase 3 D-16: negative fixtures run FIRST (inverted TDD). If any negative
# fires its detector, script exits 1 BEFORE positive fixtures run.
#
# Supports --negatives-only | --positives-only flags for CI step split.
# Default (no flag) runs both in correct order: negatives then positives.
#
# Exits 0 if every expected trigger fires exactly on its fixture, all negatives
# are silent on their target detector, and zero-signals fixture produces
# needs_haiku=true; exits 1 on any failure.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

# --- Flag parsing (D-16 CI step split) ---
MODE="all"
case "${1:-}" in
  --negatives-only) MODE="negatives" ;;
  --positives-only) MODE="positives" ;;
  "") MODE="all" ;;
  *) echo "usage: $0 [--negatives-only|--positives-only]" >&2; exit 2 ;;
esac

FAIL=0
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }

RUN_DIRS=()
cleanup() {
  for d in "${RUN_DIRS[@]:-}"; do
    [ -n "${d:-}" ] && rm -rf "$d" 2>/dev/null || true
  done
}
trap cleanup EXIT

# run_negative_case <fixture-path> <detector-signal-id>
# Asserts that the given signal DID NOT fire on the fixture. Exits 1 immediately
# on false positive — do NOT collect failures. Inverted-TDD per D-16.
run_negative_case() {
  local fx_path="$1"
  local signal_id="$2"

  [ -f "$fx_path" ] || { fail "negative fixture missing: $fx_path"; exit 1; }

  local rd
  rd=$("$REPO_ROOT/bin/dc-prep.sh" "$fx_path" 2>&1 | grep '^RUN_DIR=' | tail -1 | sed 's/^RUN_DIR=//')
  [ -n "$rd" ] && [ -d "$rd" ] || { fail "negative prep failed: $fx_path"; exit 1; }
  RUN_DIRS+=("$rd")

  if ! "$REPO_ROOT/bin/dc-classify.sh" "$rd/INPUT.md" "$rd/MANIFEST.json" "$(basename "$fx_path")" >/dev/null 2>&1; then
    fail "classifier error on negative fixture: $fx_path"
    exit 1
  fi

  # Assert the specified detector did NOT produce evidence.
  # trigger_reasons is {"persona-slug": ["signal_id", ...], ...}
  # Check if signal_id appears in ANY persona's reason list.
  local sid_fired
  sid_fired=$(jq -r --arg sid "$signal_id" \
    '[.trigger_reasons | to_entries[] | .value[]] | any(. == $sid)' \
    "$rd/MANIFEST.json")
  if [ "$sid_fired" = "true" ]; then
    fail "NEGATIVE FIXTURE TRIGGERED ITS DETECTOR: $fx_path fired signal $signal_id (should be silent)"
    exit 1
  fi
  pass "negative: $(basename "$fx_path") silent on $signal_id"
}

# run_case <fixture-basename> <expected-personas-csv> [<needs-haiku-expected>]
run_case() {
  local fixture="$1"
  local expected_csv="$2"
  local needs_haiku_expected="${3:-false}"
  local fx_path="$REPO_ROOT/tests/fixtures/bench-personas/$fixture"

  [ -f "$fx_path" ] || { fail "$fixture: fixture missing at $fx_path"; return; }

  local rd
  rd=$("$REPO_ROOT/bin/dc-prep.sh" "$fx_path" 2>&1 | grep '^RUN_DIR=' | tail -1 | sed 's/^RUN_DIR=//')
  [ -n "$rd" ] && [ -d "$rd" ] || { fail "$fixture: prep did not produce a run dir"; return; }
  RUN_DIRS+=("$rd")

  if ! "$REPO_ROOT/bin/dc-classify.sh" "$rd/INPUT.md" "$rd/MANIFEST.json" "$fixture"; then
    fail "$fixture: dc-classify.sh exit non-zero"
    return
  fi

  local got_personas got_haiku
  got_personas=$(jq -r '.triggered_personas | sort | join(",")' "$rd/MANIFEST.json")
  got_haiku=$(jq -r '.classifier.needs_haiku' "$rd/MANIFEST.json")

  local sorted_expected
  sorted_expected=$(printf '%s' "$expected_csv" | tr ',' '\n' | sort | tr '\n' ',' | sed 's/,$//')

  if [ "$got_personas" = "$sorted_expected" ]; then
    pass "$fixture → triggered_personas=[$got_personas]"
  else
    fail "$fixture → expected [$sorted_expected], got [$got_personas]"
  fi

  if [ "$got_haiku" = "$needs_haiku_expected" ]; then
    pass "$fixture → needs_haiku=$got_haiku"
  else
    fail "$fixture → expected needs_haiku=$needs_haiku_expected, got $got_haiku"
  fi
}

# ====================================================================
# NEGATIVE FIXTURES (D-16: run FIRST; exit 1 on any false positive)
# ====================================================================
if [ "$MODE" != "positives" ]; then
  # Phase 3 D-16: negative fixtures FIRST. If any false-positive fires,
  # exit 1 BEFORE positives run. Each negative is asserted against its
  # target signal; fixture must produce zero evidence for that signal.

  # compliance-marker negatives (must NOT fire compliance_marker)
  run_negative_case "tests/fixtures/classifier-negatives/compliance-marker/helm-values-benign-1.yaml"  "compliance_marker"
  run_negative_case "tests/fixtures/classifier-negatives/compliance-marker/autoscaling-benign-1.yaml"  "compliance_marker"
  run_negative_case "tests/fixtures/classifier-negatives/compliance-marker/plain-python-benign-1.py"   "compliance_marker"

  # performance-hotpath negatives (must NOT fire performance_hotpath)
  run_negative_case "tests/fixtures/classifier-negatives/performance-hotpath/autoscaling-benign-1.yaml"   "performance_hotpath"
  run_negative_case "tests/fixtures/classifier-negatives/performance-hotpath/helm-values-benign-1.yaml"   "performance_hotpath"
  run_negative_case "tests/fixtures/classifier-negatives/performance-hotpath/single-function-benign-1.py" "performance_hotpath"

  # test-imbalance negatives (must NOT fire test_imbalance)
  run_negative_case "tests/fixtures/classifier-negatives/test-imbalance/aws-sdk-benign-1.diff"          "test_imbalance"
  run_negative_case "tests/fixtures/classifier-negatives/test-imbalance/no-diff-benign-1.md"            "test_imbalance"
  run_negative_case "tests/fixtures/classifier-negatives/test-imbalance/balanced-diff-benign-1.diff"    "test_imbalance"
  run_negative_case "tests/fixtures/classifier-negatives/test-imbalance/docs-only-diff-benign-1.diff"   "test_imbalance"

  # exec-keyword negatives (must NOT fire exec_keyword)
  run_negative_case "tests/fixtures/classifier-negatives/exec-keyword/chart-yaml-benign-1.yaml"                  "exec_keyword"
  run_negative_case "tests/fixtures/classifier-negatives/exec-keyword/helm-values-benign-1.yaml"                 "exec_keyword"
  run_negative_case "tests/fixtures/classifier-negatives/exec-keyword/plain-plan-benign-1.md"                    "exec_keyword"
  run_negative_case "tests/fixtures/classifier-negatives/exec-keyword/code-with-roadmap-variable-benign-1.diff"  "exec_keyword"

  # shared-infra-change negatives (must NOT fire shared_infra_change)
  run_negative_case "tests/fixtures/classifier-negatives/shared-infra-change/autoscaling-benign-1.yaml"  "shared_infra_change"
  run_negative_case "tests/fixtures/classifier-negatives/shared-infra-change/helm-values-benign-1.yaml"  "shared_infra_change"
  run_negative_case "tests/fixtures/classifier-negatives/shared-infra-change/zero-signals-benign-1.md"   "shared_infra_change"

  # Negative phase exit gate
  NEG_COUNT=$(find tests/fixtures/classifier-negatives -maxdepth 2 -type f | wc -l | tr -d ' ')
  pass "NEGATIVES PHASE: all $NEG_COUNT fixtures silent on their detectors"
fi

if [ "$MODE" = "negatives" ]; then
  exit 0
fi

# ====================================================================
# POSITIVE FIXTURES (new v1.1 detectors + legacy v1.0 assertions)
# ====================================================================
if [ "$MODE" != "negatives" ]; then
  # Phase 3 new-detector positive assertions (one per new detector)
  run_case "v11-compliance-positive.md"          "compliance-reviewer"
  run_case "v11-performance-positive.diff"       "performance-reviewer"
  run_case "v11-test-imbalance-positive.diff"    "test-lead"
  run_case "v11-exec-keyword-positive.md"        "executive-sponsor"
  run_case "v11-shared-infra-positive.diff"      "competing-team-lead"

  # Existing 17 v1.0 assertions (UNCHANGED per D-20 backward-compat):
  run_case "auth-jwt-code.ts"                           "security-reviewer"
  run_case "crypto-import.py"                           "security-reviewer"
  run_case "secret-handling.env.diff"                   "security-reviewer"
  run_case "dependency-update.package-lock.json.diff"   "security-reviewer,air-gap-reviewer"
  run_case "aws-sdk-import.py.diff"                     "finops-auditor"
  run_case "new-cloud-resource.tf"                      "finops-auditor,dual-deploy-reviewer"
  run_case "autoscaling-change.yaml"                    "finops-auditor"
  run_case "storage-class-change.yaml"                  "finops-auditor"
  run_case "network-egress.ts"                          "air-gap-reviewer"
  run_case "external-image-pull.Dockerfile"             "air-gap-reviewer,dual-deploy-reviewer"
  run_case "unpinned-dependency.package.json"           "air-gap-reviewer"
  run_case "license-phone-home.ts"                      "air-gap-reviewer"
  run_case "helm-values-change.yaml"                    "dual-deploy-reviewer"
  run_case "chart-yaml-present.yaml"                    "dual-deploy-reviewer"
  run_case "kots-config-change.yaml"                    "dual-deploy-reviewer"
  run_case "saas-only-assumption.ts"                    "dual-deploy-reviewer"
  run_case "zero-signals.md"                            ""                                     "true"

  # MANIFEST shape check (BNCH-08): trigger_reasons is an object,
  # each value is a non-empty array of known signal IDs
  rd=$("$REPO_ROOT/bin/dc-prep.sh" "$REPO_ROOT/tests/fixtures/bench-personas/auth-jwt-code.ts" 2>&1 | grep '^RUN_DIR=' | tail -1 | sed 's/^RUN_DIR=//')
  RUN_DIRS+=("$rd")
  "$REPO_ROOT/bin/dc-classify.sh" "$rd/INPUT.md" "$rd/MANIFEST.json" "auth-jwt-code.ts"
  if jq -e '.trigger_reasons["security-reviewer"] | type == "array" and length > 0' "$rd/MANIFEST.json" >/dev/null; then
    pass "MANIFEST.trigger_reasons shape (BNCH-08)"
  else
    fail "MANIFEST.trigger_reasons missing or wrong shape"
  fi
fi

exit "$FAIL"
