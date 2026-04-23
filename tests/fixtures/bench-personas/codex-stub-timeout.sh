#!/usr/bin/env bash
# Mocks `codex exec` hanging beyond the wall-clock timeout. The test harness
# passes timeout_seconds: 2 via the fixture draft, so this stub sleeps 30s.
# Maps to error_code=codex_timeout in dc-codex-delegate.sh.
set -euo pipefail
if [ "${1:-}" = "--version" ]; then echo "codex-cli 0.122.0"; exit 0; fi
if [ "${1:-}" = "login" ] && [ "${2:-}" = "status" ]; then echo "ok"; exit 0; fi
# Drain stdin (the delegate feeds a prompt on stdin).
cat >/dev/null 2>&1 || true
sleep 30
