#!/usr/bin/env bash
# Mocks `codex exec` exiting non-zero with a sandbox-violation message on
# stderr. Maps to error_code=codex_sandbox_violation (stderr grep -qi 'sandbox').
set -euo pipefail
if [ "${1:-}" = "--version" ]; then echo "codex-cli 0.122.0"; exit 0; fi
if [ "${1:-}" = "login" ] && [ "${2:-}" = "status" ]; then echo "ok"; exit 0; fi
cat >/dev/null 2>&1 || true
echo "Error: sandbox violation - attempted write outside read-only mode." >&2
exit 1
