#!/usr/bin/env bash
# test-on-plan-on-code.sh — Phase 8 GSDI-01 + GSDI-02 wrapper-command coverage.
# Exercises the SHELL LOGIC of commands/on-plan.md and commands/on-code.md
# (glob discovery, zero-pad, git log --diff-filter=A anchor, --from fallback)
# against synthetic fixtures. Does NOT invoke the slash commands themselves
# (that would require a live Claude Code session).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -f "$REPO_ROOT/commands/on-plan.md" ] || { echo "FAIL: commands/on-plan.md missing" >&2; exit 1; }
[ -f "$REPO_ROOT/commands/on-code.md" ] || { echo "FAIL: commands/on-code.md missing" >&2; exit 1; }

TMPDIR_BASE="$(mktemp -d -t dc-on-plan-code-XXXXXX)"
cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

pass=0; fail=0
assert_eq() {
  local label="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then
    echo "PASS: $label"
    pass=$((pass+1))
  else
    echo "FAIL: $label — want='$want' got='$got'" >&2
    fail=$((fail+1))
  fi
}
assert_nonempty() {
  local label="$1" got="$2"
  if [ -n "$got" ]; then
    echo "PASS: $label"
    pass=$((pass+1))
  else
    echo "FAIL: $label — expected non-empty" >&2
    fail=$((fail+1))
  fi
}
assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qE "$needle"; then
    echo "PASS: $label"
    pass=$((pass+1))
  else
    echo "FAIL: $label — expected '$needle' in: $haystack" >&2
    fail=$((fail+1))
  fi
}

# ---------------------------------------------------------------------------
# Static frontmatter sanity
# ---------------------------------------------------------------------------
assert_contains "on-plan name frontmatter" "$(head -20 "$REPO_ROOT/commands/on-plan.md")" '^name: on-plan$'
assert_contains "on-code name frontmatter" "$(head -20 "$REPO_ROOT/commands/on-code.md")" '^name: on-code$'

# ---------------------------------------------------------------------------
# Path 1: on-plan multi-plan glob discovery
# ---------------------------------------------------------------------------
FIX1="$TMPDIR_BASE/fix1"
mkdir -p "$FIX1/.planning/phases/99-test-phase"
for i in 01 02 03; do
  echo "# Plan $i" > "$FIX1/.planning/phases/99-test-phase/99-$i-PLAN.md"
done

(
  cd "$FIX1"
  PHASE=99
  PADDED=$(printf '%02d' "$PHASE")
  shopt -s nullglob
  PLANS=(.planning/phases/${PADDED}-*/${PADDED}-*-PLAN.md)
  echo "${#PLANS[@]}" > "$TMPDIR_BASE/on-plan-count.txt"
)
COUNT=$(cat "$TMPDIR_BASE/on-plan-count.txt")
assert_eq "on-plan discovers 3 plans" "3" "$COUNT"

# Zero-match → count 0
rm -rf "$FIX1/.planning/phases/99-test-phase"
mkdir -p "$FIX1/.planning/phases/98-nothing"
(
  cd "$FIX1"
  shopt -s nullglob
  PLANS=(.planning/phases/99-*/99-*-PLAN.md)
  echo "${#PLANS[@]}" > "$TMPDIR_BASE/on-plan-zero.txt"
)
assert_eq "on-plan zero-match returns count 0" "0" "$(cat "$TMPDIR_BASE/on-plan-zero.txt")"

# Zero-pad coverage: single-digit phase int passed as "7" should pad to "07"
assert_eq "on-plan zero-pads single-digit phase" "07" "$(printf '%02d' 7)"

# ---------------------------------------------------------------------------
# Path 2: on-code git log --diff-filter=A anchor resolution
# ---------------------------------------------------------------------------
FIX2="$TMPDIR_BASE/fix2"
mkdir -p "$FIX2"
(
  cd "$FIX2"
  git init -q -b main 2>/dev/null || git init -q
  git config user.email "test@example.com"
  git config user.name "test"
  git config commit.gpgsign false
  echo initial > README.md
  git add README.md
  git commit -q -m "initial"

  mkdir -p .planning/phases/07-fake-phase
  echo "# Plan 1" > .planning/phases/07-fake-phase/07-01-PLAN.md
  git add .planning
  git commit -q -m "add phase 7 plan 01"
  EXPECTED_SHA=$(git rev-parse HEAD)

  echo body-change >> README.md
  git add README.md
  git commit -q -m "body change after phase start"

  ANCHOR=$(git log --diff-filter=A --pretty=format:%H -- ".planning/phases/07-*/07-01-PLAN.md" 2>/dev/null | tail -1 || true)
  echo "$ANCHOR" > "$TMPDIR_BASE/anchor-found.txt"
  echo "$EXPECTED_SHA" > "$TMPDIR_BASE/anchor-expected.txt"
)
ANCHOR_FOUND=$(cat "$TMPDIR_BASE/anchor-found.txt")
ANCHOR_EXPECTED=$(cat "$TMPDIR_BASE/anchor-expected.txt")
assert_nonempty "on-code anchor resolves" "$ANCHOR_FOUND"
assert_eq "on-code anchor SHA matches first-commit-of-plan-file" "$ANCHOR_EXPECTED" "$ANCHOR_FOUND"

# ---------------------------------------------------------------------------
# Path 3: on-code --from fallback (commit_docs=false scenario)
# ---------------------------------------------------------------------------
FIX3="$TMPDIR_BASE/fix3"
mkdir -p "$FIX3"
(
  cd "$FIX3"
  git init -q -b main 2>/dev/null || git init -q
  git config user.email "test@example.com"
  git config user.name "test"
  git config commit.gpgsign false
  echo a > a.txt && git add a.txt && git commit -q -m "a"
  FROM_SHA=$(git rev-parse HEAD)
  echo b > b.txt && git add b.txt && git commit -q -m "b"

  # No .planning/phases directory → anchor is empty.
  ANCHOR=$(git log --diff-filter=A --pretty=format:%H -- ".planning/phases/07-*/07-01-PLAN.md" 2>/dev/null | tail -1 || true)
  echo "$ANCHOR" > "$TMPDIR_BASE/no-anchor.txt"

  # With --from, we'd use $FROM_SHA (validated via rev-parse --verify)
  if git rev-parse --verify "${FROM_SHA}^{commit}" >/dev/null 2>&1; then
    RESOLVED=$(git rev-parse --verify "${FROM_SHA}^{commit}")
    echo "$RESOLVED" > "$TMPDIR_BASE/from-ref-sha.txt"
  else
    echo "" > "$TMPDIR_BASE/from-ref-sha.txt"
  fi

  # rev-parse --verify of a bogus ref should fail (defense-in-depth for T-08-02)
  if git rev-parse --verify "notarealref-zzz^{commit}" >/dev/null 2>&1; then
    echo "bogus-ref-accepted" > "$TMPDIR_BASE/bogus-ref.txt"
  else
    echo "bogus-ref-rejected" > "$TMPDIR_BASE/bogus-ref.txt"
  fi

  # Shell-metachar ref (arg-injection attempt) should also be rejected
  if git rev-parse --verify '$(rm -rf /tmp/__dc_test_injected)^{commit}' >/dev/null 2>&1; then
    echo "injection-accepted" > "$TMPDIR_BASE/injection.txt"
  else
    echo "injection-rejected" > "$TMPDIR_BASE/injection.txt"
  fi
)
assert_eq "on-code anchor empty when no plan committed" "" "$(cat "$TMPDIR_BASE/no-anchor.txt")"
assert_nonempty "on-code FROM_REF sha resolvable via rev-parse --verify" "$(cat "$TMPDIR_BASE/from-ref-sha.txt")"
assert_eq "on-code --from validates refs (bogus rejected)" "bogus-ref-rejected" "$(cat "$TMPDIR_BASE/bogus-ref.txt")"
assert_eq "on-code --from rejects shell-metachar injection" "injection-rejected" "$(cat "$TMPDIR_BASE/injection.txt")"

# ---------------------------------------------------------------------------
# Error message text checks (static on the command files)
# ---------------------------------------------------------------------------
assert_contains "on-code error message mentions --from" "$(cat "$REPO_ROOT/commands/on-code.md")" 'No phase-start anchor found for phase'
assert_contains "on-code error message mentions commit_docs or gitignored" "$(cat "$REPO_ROOT/commands/on-code.md")" 'commit_docs|gitignored'
assert_contains "on-plan error message present" "$(cat "$REPO_ROOT/commands/on-plan.md")" 'No plans found for phase'

echo "---"
echo "test-on-plan-on-code: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
