#!/usr/bin/env bash
# Mocks `codex exec` exiting with an unexpected non-zero code (42). Maps to
# error_code=codex_unknown (catch-all for non-taxonomy exits).
set -euo pipefail
if [ "${1:-}" = "--version" ]; then echo "codex-cli 0.122.0"; exit 0; fi
if [ "${1:-}" = "login" ] && [ "${2:-}" = "status" ]; then echo "ok"; exit 0; fi
cat >/dev/null 2>&1 || true
echo "Internal error: something unexpected" >&2
exit 42
