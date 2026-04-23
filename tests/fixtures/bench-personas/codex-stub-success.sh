#!/usr/bin/env bash
# Mocks `codex exec` succeeding with a well-formed JSON message.
# Consumed by scripts/test-codex-delegation.sh via PATH injection.
set -euo pipefail
if [ "${1:-}" = "--version" ]; then
  echo "codex-cli 0.122.0"; exit 0
fi
if [ "${1:-}" = "login" ] && [ "${2:-}" = "status" ]; then
  echo "Logged in as test-user"; exit 0
fi
# Pass-through exec: write a minimal valid JSON to -o target.
OUT_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) OUT_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$OUT_FILE" ] || { echo "stub: missing -o" >&2; exit 2; }
# Drain stdin so the pipeline producer doesn't SIGPIPE.
cat >/dev/null
cat > "$OUT_FILE" <<'JSON'
{"type":"message","content":[{"type":"text","text":"Found 1 issue in src/auth/login.ts:42 - skipVerify branch is reachable via request body. Severity high. Fix: remove the branch."}]}
JSON
exit 0
