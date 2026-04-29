#!/usr/bin/env bash
# Mocks Codex returning non-schema-conforming JSON when --output-schema is used.
# Triggers codex_schema_validation_error in dc-codex-delegate.sh section 8b.
# Consumed by scripts/test-codex-delegation.sh via PATH injection.
set -euo pipefail
if [ "${1:-}" = "--version" ]; then
  echo "codex-cli 0.122.0"; exit 0
fi
if [ "${1:-}" = "--help" ]; then
  echo "Usage: codex [options] <command>"
  echo "  exec          Execute a prompt"
  echo "  --output-schema <path>  Enforce JSON schema on output"
  echo "  --json        Output JSON"
  exit 0
fi
if [ "${1:-}" = "login" ] && [ "${2:-}" = "status" ]; then
  echo "Logged in as test-user"; exit 0
fi
OUT_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) OUT_FILE="$2"; shift 2 ;;
    --output-schema) shift 2 ;; # Accept but ignore schema
    *) shift ;;
  esac
done
[ -n "$OUT_FILE" ] || { echo "stub: missing -o" >&2; exit 2; }
# Drain stdin so the pipeline producer doesn't SIGPIPE.
cat >/dev/null
# Emit JSON that is valid JSON but does NOT conform to the security schema
# (missing required "evidence" and "ask" fields on the finding)
cat > "$OUT_FILE" <<'JSON'
{"findings":[{"target":"src/auth/login.ts:42","claim":"skipVerify is dangerous","severity":"major","category":"auth-bypass"}]}
JSON
exit 0
