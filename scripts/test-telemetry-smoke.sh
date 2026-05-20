#!/usr/bin/env bash
# scripts/test-telemetry-smoke.sh — PLUG-01 + PLUG-02 + PLUG-04
# Asserts bin/dc-telemetry.sh --dry-run produces the expected envelope across
# both runtimes, that DC_TELEMETRY_ENDPOINT overrides the default, that
# http:// endpoints are silently rejected, and that an unknown --runtime
# value is silently rejected. All cases run under env -i so the host shell's
# DC_TELEMETRY_ENDPOINT / DO_NOT_TRACK cannot leak in.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TELEM="$REPO_ROOT/bin/dc-telemetry.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/council-run"

pass=0; fail=0

# run_isolated <extra-env-pairs...> -- <args-to-telem...>
# Invokes the script under env -i with HOME/PATH/CLAUDE_PLUGIN_ROOT/DC_TELEMETRY
# preset, plus any caller-supplied env pairs (KEY=VAL ...) BEFORE `--`.
run_isolated() {
  local -a extra=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do
    extra+=("$1")
    shift
  done
  shift  # drop the `--`
  # bash 3.2-safe expansion: avoid "unbound" when array is empty under set -u.
  env -i HOME="$HOME" PATH="$PATH" \
         CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
         DC_TELEMETRY=true \
         ${extra[@]+"${extra[@]}"} \
         "$TELEM" "$FIXTURE" "$@"
}

check() {
  local desc="$1"; local cond_rc="$2"
  if [ "$cond_rc" -eq 0 ]; then
    printf "  PASS  %s\n" "$desc"
    pass=$((pass+1))
  else
    printf "  FAIL  %s\n" "$desc" >&2
    fail=$((fail+1))
  fi
}

# Case 1: --runtime=opencode --dry-run produces full envelope with semver client_version
OUT=$(run_isolated -- --runtime=opencode --dry-run)
if echo "$OUT" | grep -q '^dry-run: runtime=opencode$' \
   && echo "$OUT" | grep -q '^dry-run: endpoint=https://dc-telemetry.pub.andyjwoodard.net/v1/events$'; then
  PAYLOAD=$(echo "$OUT" | grep '^dry-run: payload=' | sed 's/^dry-run: payload=//')
  echo "$PAYLOAD" | jq -e '.event_type=="review.completed" and .payload.runtime=="opencode" and (.payload.client_version | test("^[0-9]+\\.[0-9]+\\.[0-9]+"))' >/dev/null && rc=0 || rc=$?
  check "opencode dry-run: envelope + semver client_version" "$rc"
else
  check "opencode dry-run: envelope + semver client_version" 1
fi

# Case 2: --runtime=claude-code --dry-run
OUT=$(run_isolated -- --runtime=claude-code --dry-run)
if echo "$OUT" | grep -q '^dry-run: runtime=claude-code$' \
   && echo "$OUT" | grep -q '^dry-run: endpoint=https://dc-telemetry.pub.andyjwoodard.net/v1/events$'; then
  PAYLOAD=$(echo "$OUT" | grep '^dry-run: payload=' | sed 's/^dry-run: payload=//')
  echo "$PAYLOAD" | jq -e '.event_type=="review.completed" and .payload.runtime=="claude-code" and (.payload.client_version | test("^[0-9]+\\.[0-9]+\\.[0-9]+"))' >/dev/null && rc=0 || rc=$?
  check "claude-code dry-run: envelope + semver client_version" "$rc"
else
  check "claude-code dry-run: envelope + semver client_version" 1
fi

# Case 3: DC_TELEMETRY_ENDPOINT override (https) is honored
OUT=$(run_isolated DC_TELEMETRY_ENDPOINT=https://example.test/v1/events -- --runtime=claude-code --dry-run)
echo "$OUT" | grep -q '^dry-run: endpoint=https://example.test/v1/events$' && rc=0 || rc=$?
check "DC_TELEMETRY_ENDPOINT override (https) honored (PLUG-04)" "$rc"

# Case 4: http:// endpoint override silently rejected (SSRF mitigation)
OUT=$(run_isolated DC_TELEMETRY_ENDPOINT=http://attacker.example/v1/events -- --runtime=claude-code --dry-run)
[ -z "$OUT" ] && rc=0 || rc=$?
check "http:// endpoint silently rejected (CORR-03)" "$rc"

# Case 5: Unknown --runtime value silently rejected (closed enum)
OUT=$(run_isolated -- --runtime=evil --dry-run)
[ -z "$OUT" ] && rc=0 || rc=$?
check "unknown --runtime value silently rejected (D-HP-04)" "$rc"

printf "\n%s/%s cases passed\n" "$pass" "$((pass+fail))"
[ "$fail" -eq 0 ]
