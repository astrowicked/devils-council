#!/usr/bin/env bash
# scripts/test-chair-strictness.sh — TD-05 fixture runner + 08-UAT regression gate (D-08, P-08)
#
# Runs bin/dc-validate-synthesis.sh against each fixture run-dir and asserts
# expected exit. The 08-UAT-known-good fixture is the load-bearing regression gate:
# if it fails, the TD-05 regex is too strict and v1.0 outputs would break.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
VALIDATOR="$REPO_ROOT/bin/dc-validate-synthesis.sh"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/chair-strictness"

declare -a CASES=(
  "08-UAT-known-good:0"
  "single-target-good:0"
  "composite-rejected-and:1"
  "composite-rejected-3comma:1"
  "slash-allowed:0"
  "single-comma-allowed:0"
)

pass=0; fail=0
for case in "${CASES[@]}"; do
  name="${case%:*}"
  expected="${case##*:}"
  # Copy fixture to a scratch dir so validator's rename-on-pass doesn't consume the source
  scratch=$(mktemp -d -t dc-td05.XXXXXX)
  cp -R "$FIXTURE_DIR/$name/." "$scratch/"
  "$VALIDATOR" "$scratch" >/dev/null 2>&1 && got=0 || got=$?
  if [ "$got" -eq "$expected" ]; then
    printf "  PASS  %-35s (exit=%s, expected=%s)\n" "$name" "$got" "$expected"
    pass=$((pass+1))
  else
    printf "  FAIL  %-35s (exit=%s, expected=%s)\n" "$name" "$got" "$expected" >&2
    fail=$((fail+1))
  fi
  rm -rf "$scratch"
done

printf "\n%s/%s fixtures passed\n" "$pass" "$((pass+fail))"
[ "$fail" -eq 0 ]
