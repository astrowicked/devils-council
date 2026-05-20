#!/usr/bin/env bash
# scripts/test-telemetry-dnt.sh — PLUG-03 + Pitfall 1
# Asserts DO_NOT_TRACK=1 short-circuits bin/dc-telemetry.sh before any side
# effect (no stdout, no stderr, exit 0). Also covers default-off (no
# DC_TELEMETRY).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TELEM="$REPO_ROOT/bin/dc-telemetry.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/council-run"

pass=0; fail=0

assert_empty() {
  local desc="$1"; shift
  local out
  out=$("$@" 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
    printf "  PASS  %s\n" "$desc"
    pass=$((pass+1))
  else
    printf "  FAIL  %s (rc=%s, out=[%s])\n" "$desc" "$rc" "$out" >&2
    fail=$((fail+1))
  fi
}

# Case 1: DNT=1 + opt-in + bogus endpoint → silent
assert_empty "DNT=1 silences production path (bogus endpoint)" \
  env -i HOME="$HOME" PATH="$PATH" \
       DO_NOT_TRACK=1 DC_TELEMETRY=true \
       DC_TELEMETRY_ENDPOINT=http://127.0.0.1:1 \
       "$TELEM" "$FIXTURE" --runtime=claude-code

# Case 2: DNT=1 + opt-in + --dry-run → silent (DNT precedes dry-run)
assert_empty "DNT=1 silences --dry-run path" \
  env -i HOME="$HOME" PATH="$PATH" \
       DO_NOT_TRACK=1 DC_TELEMETRY=true \
       "$TELEM" "$FIXTURE" --runtime=opencode --dry-run

# Case 3: Default env (no DC_TELEMETRY) → silent
assert_empty "default-off (no DC_TELEMETRY)" \
  env -i HOME="$HOME" PATH="$PATH" \
       "$TELEM" "$FIXTURE" --runtime=claude-code --dry-run

printf "\n%s/%s cases passed\n" "$pass" "$((pass+fail))"
[ "$fail" -eq 0 ]
