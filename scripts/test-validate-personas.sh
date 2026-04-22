#!/usr/bin/env bash
# test-validate-personas.sh — self-test harness for scripts/validate-personas.sh.
#
# Runs the validator against every persona fixture under
# tests/fixtures/personas/ and asserts:
#   - valid fixtures exit 0
#   - each invalid fixture exits non-zero AND its output contains the expected
#     field / rule substring
#   - an empty agents/ directory exits 0 (no-op case required by Plan 04 hook)
#
# Exits 0 if every assertion passes, 1 if any assertion fails.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
VALIDATOR="$SCRIPT_DIR/validate-personas.sh"
FIX_DIR="$REPO_ROOT/tests/fixtures/personas"
SIGNALS="$REPO_ROOT/lib/signals.json"

FAIL=0
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }

# Expect the validator to exit 0 on <file>.
expect_pass() {
  local file=$1
  if "$VALIDATOR" "$file" >/dev/null 2>&1; then
    pass "$file → exit 0 (expected)"
  else
    fail "$file → non-zero exit (expected 0)"
  fi
}

# Expect the validator to exit non-zero on <file> AND output to contain <needle>.
# <needle> is a literal fixed-string substring (no regex interpretation).
expect_fail_with() {
  local file=$1
  local needle=$2
  local out

  out=$("$VALIDATOR" "$file" 2>&1 || true)

  if "$VALIDATOR" "$file" >/dev/null 2>&1; then
    fail "$file → exit 0 (expected non-zero)"
    return
  fi

  if printf '%s' "$out" | grep -q -F -- "$needle"; then
    pass "$file → non-zero exit + output contains: '$needle'"
  else
    fail "$file → non-zero exit but did NOT mention: '$needle' (output: $out)"
  fi
}

# Preflight: required artifacts exist.
[ -x "$VALIDATOR" ]       || { fail "$VALIDATOR missing or not executable"; exit 1; }
[ -d "$FIX_DIR" ]         || { fail "$FIX_DIR missing"; exit 1; }
[ -f "$SIGNALS" ]         || { fail "$SIGNALS missing"; exit 1; }

# ---- Well-formed fixtures: validator must accept ----
expect_pass "$FIX_DIR/valid-core.md"
expect_pass "$FIX_DIR/valid-bench.md"

# ---- Malformed fixtures: each fails exactly ONE rule; assert field-specific message ----
expect_fail_with "$FIX_DIR/invalid-missing-fields.md"       "primary_concern"
expect_fail_with "$FIX_DIR/invalid-undeclared-signal.md"    "not_a_real_signal_xyz"
expect_fail_with "$FIX_DIR/invalid-too-few-objections.md"   "characteristic_objections"
expect_fail_with "$FIX_DIR/invalid-empty-banned-phrases.md" "banned_phrases"

# ---- Empty agents/ case: required by Plan 04 hook integration ----
# Use a temp directory with just an agents/.gitkeep so no-arg invocation hits
# the empty-directory branch. Pass --signals so the validator can find
# signals.json from outside the repo root.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/agents"
touch "$TMP/agents/.gitkeep"

if ( cd "$TMP" && "$VALIDATOR" --signals "$SIGNALS" >/dev/null 2>&1 ); then
  pass "empty agents/ → exit 0"
else
  fail "empty agents/ should exit 0"
fi

# ---- Summary ----
if [ "$FAIL" -ne 0 ]; then
  printf '\nTEST SUITE FAILED\n' >&2
  exit 1
fi

printf '\nTEST SUITE PASSED (all cases)\n'
exit 0
