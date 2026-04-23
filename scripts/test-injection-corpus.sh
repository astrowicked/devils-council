#!/usr/bin/env bash
# scripts/test-injection-corpus.sh — HARD-01 corpus runner.
#
# Phase 1: static grep of commands/review.md for D-68 shell-injection patterns.
# Phase 2: per-fixture runtime assertion under DC_MOCK_INJECTION_CORPUS=1.
# Phase 3: tool-hijack no-side-effect audit.
#
# Exit codes:
#   0 — all phases passed
#   1 — assertion failed
#   2 — usage error / missing fixture
#
# Environment:
#   DC_MOCK_INJECTION_CORPUS=1 (default) — mocked persona drafts, no live Agent().
#   DC_MOCK_INJECTION_CORPUS=0 — reserved for local-only live run (NOT for CI).

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

MOCK="${DC_MOCK_INJECTION_CORPUS:-1}"

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

# ============================================================
# Phase 1: Static grep — D-68 shell-injection pattern check on commands/review.md
# ============================================================
echo "--- Phase 1: Static grep of commands/review.md (D-68) ---"

PATTERNS=(
  '\$ARTIFACT'
  '\$\(cat[[:space:]]+INPUT\.md\)'
  '\$\(cat[[:space:]]+\$INPUT\)'
  '\$\(cat[[:space:]]+["'\'']?\$\{?RUN_DIR\}?/INPUT\.md'
  '\$\(<[[:space:]]*INPUT\.md\)'
  '\$\(<[[:space:]]*\$\{?RUN_DIR\}?/INPUT\.md'
  'eval[[:space:]]+["'\'']?\$\w+'
  'eval[[:space:]]+`'
  '(sh|bash)[[:space:]]+-c[[:space:]]+["'\''][^"'\'']*\$(ARTIFACT|INPUT|ARGUMENTS)'
  'printf[[:space:]]+["'\'']%s["'\''][[:space:]]+"\$\(cat[[:space:]]+INPUT'
)

STATIC_FAIL=0
for pat in "${PATTERNS[@]}"; do
  if grep -nE "$pat" commands/review.md 2>/dev/null; then
    fail "D-68 static grep matched: $pat"
    STATIC_FAIL=1
  fi
done
if [ "$STATIC_FAIL" -eq 0 ]; then
  pass "D-68 static grep: commands/review.md contains zero shell-injection patterns (${#PATTERNS[@]} patterns checked)"
fi

# Reserve further sections for Task 2 and Task 3.
# (Runtime per-fixture loop goes here.)
# (Tool-hijack no-side-effect audit goes here.)

[ "$FAIL" -ne 0 ] && exit 1
echo "HARD-01 INJECTION-CORPUS TEST (Phase 1 only): PASSED"
echo "NOTE: Phase 2 (runtime) + Phase 3 (tool-hijack audit) to be added in subsequent tasks."
exit 0
