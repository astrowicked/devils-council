#!/usr/bin/env bash
# scripts/test-shell-inject.sh — TD-04 fixture runner
# Exercises scripts/validate-shell-inject.sh against tests/fixtures/shell-inject/
# Each fixture has a pre-declared expected exit code (0 = parser passes, 1 = parser fails).
# Exit 0 on all fixtures matching expected; exit 1 on any mismatch.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
PARSER="$REPO_ROOT/scripts/validate-shell-inject.sh"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/shell-inject"

declare -a CASES=(
  "known-good-01.md:0"
  "regression-v1.0.0.md:1"
  "edge-inline-backtick.md:1"
  "edge-fenced-exempt.md:0"
  "edge-shebang.md:0"
  "allowlist-positive.md:0"
)

pass=0; fail=0
for case in "${CASES[@]}"; do
  fixture="${case%:*}"
  expected="${case##*:}"
  "$PARSER" "$FIXTURE_DIR/$fixture" >/dev/null 2>&1 && got=0 || got=$?
  if [ "$got" -eq "$expected" ]; then
    printf "  PASS  %-35s (exit=%s, expected=%s)\n" "$fixture" "$got" "$expected"
    pass=$((pass+1))
  else
    printf "  FAIL  %-35s (exit=%s, expected=%s)\n" "$fixture" "$got" "$expected" >&2
    fail=$((fail+1))
  fi
done

printf "\n%s/%s fixtures passed\n" "$pass" "$((pass+fail))"
[ "$fail" -eq 0 ]
