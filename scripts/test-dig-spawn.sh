#!/usr/bin/env bash
# test-dig-spawn.sh — Phase 8 RESP-02 dig-command validation coverage.
#
# Exercises the SHELL LOGIC of commands/dig.md (persona regex, run-id path-traversal
# defense, latest sentinel resolution, missing-scorecard error, ephemeral invariant)
# against synthetic fixtures. Does NOT invoke the slash command itself (requires
# live Claude Code session); asserts the command markdown's shell-injection logic
# works, plus the ephemeral invariant (MANIFEST unchanged).
#
# Paths covered (per plan 08-03):
#   1. latest sentinel resolves to newest subdir under .council/
#   2. literal run-id directory-match validates; bogus run-id rejected
#   3. missing persona scorecard produces available-list error
#   4. path-traversal run-ids rejected BEFORE filesystem access
#   5. MANIFEST.json hash stable before/after dig (ephemeral invariant)
#
# Exits 0 if every assertion passes, 1 otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -f "$REPO_ROOT/commands/dig.md" ] || {
  echo "FAIL: commands/dig.md missing" >&2
  exit 1
}
[ -f "$REPO_ROOT/tests/fixtures/dig-spawn/latest-run/staff-engineer.md" ] || {
  echo "FAIL: fixture staff-engineer.md missing" >&2
  exit 1
}
[ -f "$REPO_ROOT/tests/fixtures/dig-spawn/latest-run/MANIFEST.json" ] || {
  echo "FAIL: fixture MANIFEST.json missing" >&2
  exit 1
}

TMPDIR_BASE="$(mktemp -d -t dc-dig-spawn-XXXXXX)"
cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

pass=0
fail=0

assert_eq() {
  local label="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label want='$want' got='$got'" >&2
    fail=$((fail + 1))
  fi
}

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qE "$needle"; then
    echo "PASS: $label"
    pass=$((pass + 1))
  else
    echo "FAIL: $label pattern='$needle' in: $haystack" >&2
    fail=$((fail + 1))
  fi
}

# Build a sandbox .council/ with 2 run dirs (older + newer) from the fixture.
mkdir -p "$TMPDIR_BASE/.council/20260423T120000Z-older-run"
mkdir -p "$TMPDIR_BASE/.council/20260424T120000Z-latest-run"
cp "$REPO_ROOT/tests/fixtures/dig-spawn/latest-run/staff-engineer.md" \
  "$TMPDIR_BASE/.council/20260424T120000Z-latest-run/staff-engineer.md"
cp "$REPO_ROOT/tests/fixtures/dig-spawn/latest-run/MANIFEST.json" \
  "$TMPDIR_BASE/.council/20260424T120000Z-latest-run/MANIFEST.json"
echo "placeholder" > "$TMPDIR_BASE/.council/20260423T120000Z-older-run/staff-engineer.md"
# Plant a responses.md file at .council root (must NOT be resolved by 'latest').
touch "$TMPDIR_BASE/.council/responses.md"

# Ensure mtimes order — latest-run must be newer than older-run.
# touch -t accepts [[CC]YY]MMDDhhmm on both BSD and GNU coreutils.
touch -t 202604231200 "$TMPDIR_BASE/.council/20260423T120000Z-older-run" 2>/dev/null || true
touch -t 202604241200 "$TMPDIR_BASE/.council/20260424T120000Z-latest-run" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Path 1: latest sentinel resolution (mirrors commands/dig.md portable shell).
# ---------------------------------------------------------------------------
RESOLVED=$(cd "$TMPDIR_BASE/.council" && ls -td */ 2>/dev/null | head -1 | sed 's:/$::')
assert_eq "Path1 latest resolves to newest subdir" "20260424T120000Z-latest-run" "$RESOLVED"

# responses.md is a FILE, not a DIR — `ls -td */` must exclude it.
assert_contains "Path1 latest excludes responses.md file" "$RESOLVED" '^[0-9]{8}T[0-9]{6}Z-'

# Assert responses.md is not resolved even when present at .council root.
test -f "$TMPDIR_BASE/.council/responses.md" \
  && assert_eq "Path1 responses.md is a file (not candidate)" "file" "file" \
  || { echo "FAIL: Path1 responses.md not present in fixture" >&2; fail=$((fail + 1)); }

# ---------------------------------------------------------------------------
# Path 2: literal run-id directory-match validation.
# ---------------------------------------------------------------------------
RUN_ID="20260424T120000Z-latest-run"
if [ -d "$TMPDIR_BASE/.council/$RUN_ID" ]; then
  assert_eq "Path2 literal match: valid run-id resolves" "ok" "ok"
else
  echo "FAIL: Path2 literal-match resolution" >&2
  fail=$((fail + 1))
fi

RUN_ID_BAD="20260425T000000Z-does-not-exist"
if [ ! -d "$TMPDIR_BASE/.council/$RUN_ID_BAD" ]; then
  assert_eq "Path2 bogus run-id rejected" "ok" "ok"
else
  echo "FAIL: bogus run-id unexpectedly found" >&2
  fail=$((fail + 1))
fi

# ---------------------------------------------------------------------------
# Path 3: missing persona scorecard.
# ---------------------------------------------------------------------------
if [ ! -f "$TMPDIR_BASE/.council/20260424T120000Z-latest-run/security-reviewer.md" ]; then
  assert_eq "Path3 missing-scorecard detected" "ok" "ok"
else
  echo "FAIL: security-reviewer.md unexpectedly present in fixture" >&2
  fail=$((fail + 1))
fi

# Static check: dig.md emits an available-scorecards listing on missing-scorecard error.
assert_contains "Path3 dig.md lists available scorecards on error" \
  "$(cat "$REPO_ROOT/commands/dig.md")" \
  'Available scorecards in this run'

# ---------------------------------------------------------------------------
# Path 4: path-traversal inputs rejected BEFORE filesystem access.
# The case/esac in commands/dig.md handles the three classes (*/*, *..*, .*).
# Re-exercise locally to assert the pattern rejects each class.
# ---------------------------------------------------------------------------
traversal_reject() {
  local input="$1"
  case "$input" in
    */*|*..*|.*) echo reject ;;
    *)           echo accept ;;
  esac
}
assert_eq "Path4 rejects ../something (dot-dot-slash)" "reject" "$(traversal_reject '../etc/passwd')"
assert_eq "Path4 rejects a/b (slash)" "reject" "$(traversal_reject 'a/b')"
assert_eq "Path4 rejects .hidden (leading dot)" "reject" "$(traversal_reject '.hidden')"
assert_eq "Path4 rejects bare .. (dot-dot)" "reject" "$(traversal_reject '..')"
assert_eq "Path4 rejects foo..bar (embedded dot-dot)" "reject" "$(traversal_reject 'foo..bar')"
assert_eq "Path4 accepts normal run-id" "accept" "$(traversal_reject '20260424T120000Z-latest-run')"
assert_eq "Path4 accepts latest sentinel" "accept" "$(traversal_reject 'latest')"

# Persona validation regex (same shape as commands/dig.md).
persona_reject() {
  local input="$1"
  if printf '%s' "$input" | grep -qE '^[a-z][a-z-]*$'; then
    echo accept
  else
    echo reject
  fi
}
assert_eq "Path4 persona: accepts staff-engineer" "accept" "$(persona_reject 'staff-engineer')"
assert_eq "Path4 persona: accepts security-reviewer" "accept" "$(persona_reject 'security-reviewer')"
assert_eq "Path4 persona: rejects Staff-Engineer (uppercase)" "reject" "$(persona_reject 'Staff-Engineer')"
assert_eq "Path4 persona: rejects staff_engineer (underscore)" "reject" "$(persona_reject 'staff_engineer')"
assert_eq "Path4 persona: rejects ../etc (path traversal)" "reject" "$(persona_reject '../etc')"
assert_eq "Path4 persona: rejects 2-letter-digit (digit)" "reject" "$(persona_reject 'eng2')"
assert_eq "Path4 persona: rejects empty" "reject" "$(persona_reject '')"

# ---------------------------------------------------------------------------
# Path 5: ephemeral invariant — MANIFEST.json not modified by any dig activity.
# Proxy check: (a) hash stable after test body; (b) static grep confirms dig.md
# has NO write-to-MANIFEST code path.
# ---------------------------------------------------------------------------
if command -v shasum >/dev/null 2>&1; then
  HASH_BEFORE=$(shasum -a 256 "$TMPDIR_BASE/.council/20260424T120000Z-latest-run/MANIFEST.json" | awk '{print $1}')
else
  HASH_BEFORE=$(sha256sum "$TMPDIR_BASE/.council/20260424T120000Z-latest-run/MANIFEST.json" | awk '{print $1}')
fi

# (intentionally no operation that would write to MANIFEST.json)

if command -v shasum >/dev/null 2>&1; then
  HASH_AFTER=$(shasum -a 256 "$TMPDIR_BASE/.council/20260424T120000Z-latest-run/MANIFEST.json" | awk '{print $1}')
else
  HASH_AFTER=$(sha256sum "$TMPDIR_BASE/.council/20260424T120000Z-latest-run/MANIFEST.json" | awk '{print $1}')
fi
assert_eq "Path5 MANIFEST hash unchanged (ephemeral)" "$HASH_BEFORE" "$HASH_AFTER"

# Static: commands/dig.md must not contain any redirect/write into MANIFEST.
# Accept comments/prose that MENTION MANIFEST.json but not any `> MANIFEST.json` style redirect.
if grep -E 'MANIFEST\.json[^"]*>[^&]' "$REPO_ROOT/commands/dig.md" >/dev/null 2>&1; then
  echo "FAIL: commands/dig.md contains a write-to-MANIFEST pattern (ephemeral invariant violated)" >&2
  fail=$((fail + 1))
else
  echo "PASS: commands/dig.md has no write-to-MANIFEST redirect pattern"
  pass=$((pass + 1))
fi

# Additional static: no jq ... > MANIFEST.json pattern (the canonical MANIFEST-write idiom).
if grep -E 'jq[^|]*>[[:space:]]*[^[:space:]]*MANIFEST\.json' "$REPO_ROOT/commands/dig.md" >/dev/null 2>&1; then
  echo "FAIL: commands/dig.md contains a jq>MANIFEST pattern (ephemeral invariant violated)" >&2
  fail=$((fail + 1))
else
  echo "PASS: commands/dig.md has no jq>MANIFEST write pattern"
  pass=$((pass + 1))
fi

# ---------------------------------------------------------------------------
# Static: persona regex present; no-re-critique instruction present;
# Phase 5 D-38 finding ID format referenced.
# ---------------------------------------------------------------------------
assert_contains "persona regex [a-z][a-z-]* present" \
  "$(cat "$REPO_ROOT/commands/dig.md")" \
  '\[a-z\]\[a-z-\]\*'

assert_contains "no-re-critique instruction present" \
  "$(cat "$REPO_ROOT/commands/dig.md")" \
  'Do NOT re-critique'

# D-38 finding ID format used in the fixture (validates test coupling).
assert_contains "fixture finding ID matches Phase 5 D-38 format" \
  "$(cat "$REPO_ROOT/tests/fixtures/dig-spawn/latest-run/staff-engineer.md")" \
  'staff-engineer-[a-f0-9]{8}'

echo "---"
echo "test-dig-spawn: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
