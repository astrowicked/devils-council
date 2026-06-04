#!/usr/bin/env bash
# v1.3 FR-12: behavioral check of the override-precedence (merge-order) invariant.
# Sets a user opencode.json agent.<name>.model override, runs with the CHEAP
# preset (which would otherwise inject a different model), spawns the persona,
# and asserts via the session DB that the USER value won. This is the real test
# that the config-hook default loses to a user override — the invariant a future
# OpenCode config-merge reorder could silently break.
#
# Lane policy (FIN2-4): this performs a LIVE model spawn, so it is NOT a required
# CI gate. It runs nightly + on OpenCode version/lockfile change. It refuses to
# run on any non-cheap preset so it can never spawn an expensive model.
#
# Skips gracefully (exit 0) where opencode / a free model isn't available.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

skip() { echo "SKIP: $*"; exit 0; }
fail() { echo "FAIL: $*" >&2; exit 1; }

command -v opencode >/dev/null 2>&1 || skip "opencode not on PATH"
command -v sqlite3 >/dev/null 2>&1 || skip "sqlite3 not available"
DB="$HOME/.local/share/opencode/opencode.db"

PRESET="${DEVILS_COUNCIL_MODEL_PRESET:-cheap}"
[ "$PRESET" = "cheap" ] || fail "refusing to run live precedence check on non-cheap preset '$PRESET' (FIN2-4)"

PRIMARY="opencode/deepseek-v4-flash-free"
OVERRIDE_MODEL="opencode/mimo-v2.5-free"   # distinct from the cheap deep-reasoning default (minimax)
AGENT="council-chair"

# Build so .opencode/lib + generated sidecars are current (needs PyYAML).
python3 -c "import yaml" 2>/dev/null || skip "PyYAML not available for build"
bash .opencode/build.sh >/dev/null 2>&1 || fail "build failed"
rm -rf "$HOME/.cache/opencode/packages/devils-council-opencode@latest"  # cache shadows local build

backup="$(mktemp)"; cp opencode.json "$backup"
restore() { cp "$backup" opencode.json; rm -f "$backup"; }
trap restore EXIT

cat > opencode.json <<EOF
{ "\$schema": "https://opencode.ai/config.json", "plugin": ["./opencode"], "agent": { "$AGENT": { "model": "$OVERRIDE_MODEL" } } }
EOF

echo "== spawning $AGENT with preset=$PRESET and user override model=$OVERRIDE_MODEL =="
DEVILS_COUNCIL_MODEL_PRESET=cheap timeout 150 opencode run -m "$PRIMARY" \
  "Use the task tool to invoke the subagent '$AGENT' with message 'Reply exactly: PREC-RAN'. Report only its reply." >/dev/null 2>&1

got="$(sqlite3 "$DB" "SELECT json_extract(model,'\$.id') FROM session WHERE agent='$AGENT' ORDER BY time_created DESC LIMIT 1;" 2>/dev/null)"
want="mimo-v2.5-free"
if [ "$got" = "$want" ]; then
  echo "PASS: user override won (persona ran on '$got', not the cheap-preset default)"
else
  fail "override-precedence invariant broken: expected '$want' (user override), got '$got'. A config-merge reorder may have flipped user-wins -> plugin-clobbers."
fi
