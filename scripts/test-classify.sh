#!/usr/bin/env bash
# test-classify.sh — per-signal fixture tests for lib/classify.py via bin/dc-classify.sh.
#
# Exits 0 if every expected trigger fires exactly on its fixture and zero-signals
# fixture produces needs_haiku=true; exits 1 on any failure.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

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

# Per RESEARCH.md §Q1 expected mappings:
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

exit "$FAIL"
