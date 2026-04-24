#!/usr/bin/env bash
# test-hooks-gsd-guard.sh — Phase 8 GSDI-03 + GSDI-04 guard coverage.
# Exercises bin/dc-gsd-wrap.sh across the three guard-logic paths:
#   1. Gated-off:           CLAUDE_PLUGIN_OPTION_GSD_INTEGRATION=false  -> empty stdout, exit 0
#   2. Gated-on, no GSD:    env=true, GSD agent files absent             -> empty stdout, exit 0 (GSDI-04)
#   3. Gated-on, GSD here:  env=true, at least one GSD file present      -> pointer stdout, exit 0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WRAP="$REPO_ROOT/bin/dc-gsd-wrap.sh"

[ -x "$WRAP" ] || { echo "FAIL: $WRAP missing or not executable" >&2; exit 1; }

TMPHOME="$(mktemp -d -t dc-gsd-guard-XXXXXX)"
cleanup() { rm -rf "$TMPHOME"; }
trap cleanup EXIT

# Fixture: a GSD plan-checker hook JSON carrying a PLAN.md path in its prompt.
FIXTURE_JSON='{"tool_name":"Agent","tool_input":{"subagent_type":"gsd-plan-checker","prompt":"<files_to_read>\n- .planning/phases/07-hardening-injection-defense-response-workflow/07-01-PLAN.md\n</files_to_read>"}}'

pass=0; fail=0
assert_empty() {
  local label="$1" out="$2"
  if [ -z "$out" ]; then
    echo "PASS: $label"
    pass=$((pass+1))
  else
    echo "FAIL: $label -- expected empty stdout, got: $out" >&2
    fail=$((fail+1))
  fi
}
assert_matches() {
  local label="$1" out="$2" pattern="$3"
  if printf '%s' "$out" | grep -qE "$pattern"; then
    echo "PASS: $label"
    pass=$((pass+1))
  else
    echo "FAIL: $label -- expected stdout to match '$pattern', got: $out" >&2
    fail=$((fail+1))
  fi
}

# Path 1: gated OFF (env=false). Even if GSD present, hook must be silent.
OUT="$(printf '%s' "$FIXTURE_JSON" | CLAUDE_PLUGIN_OPTION_GSD_INTEGRATION=false HOME="$HOME" "$WRAP" plan-checker || true)"
assert_empty "path1 gated-off: empty stdout" "$OUT"

# Path 2: gated ON but GSD absent. Point HOME at empty temp dir -> no .claude/agents/gsd-*.md.
mkdir -p "$TMPHOME/.claude/agents"
OUT="$(printf '%s' "$FIXTURE_JSON" | CLAUDE_PLUGIN_OPTION_GSD_INTEGRATION=true HOME="$TMPHOME" "$WRAP" plan-checker || true)"
assert_empty "path2 gated-on + no GSD: empty stdout (GSDI-04)" "$OUT"

# Path 3: gated ON and GSD present. Plant a fake gsd-plan-checker.md under TMPHOME.
touch "$TMPHOME/.claude/agents/gsd-plan-checker.md"
OUT="$(printf '%s' "$FIXTURE_JSON" | CLAUDE_PLUGIN_OPTION_GSD_INTEGRATION=true HOME="$TMPHOME" "$WRAP" plan-checker || true)"
assert_matches "path3 gated-on + GSD present: pointer emitted" "$OUT" '^\[devils-council:'

echo "---"
echo "test-hooks-gsd-guard: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
