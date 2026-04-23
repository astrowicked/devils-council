#!/usr/bin/env bash
# Mocks `codex exec` with expired/missing auth: --version works, `login status`
# exits non-zero. Maps to error_code=codex_auth_expired in dc-codex-delegate.sh.
set -euo pipefail
if [ "${1:-}" = "--version" ]; then echo "codex-cli 0.122.0"; exit 0; fi
if [ "${1:-}" = "login" ] && [ "${2:-}" = "status" ]; then
  echo "Not logged in. Run codex login." >&2
  exit 1
fi
echo "Auth required. Run codex login." >&2
exit 1
