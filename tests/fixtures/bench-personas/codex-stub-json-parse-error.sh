#!/usr/bin/env bash
# Mocks `codex exec` exiting 0 but writing malformed JSON to -o. Maps to
# error_code=codex_json_parse_error (caught by the post-check `jq -e .`).
set -euo pipefail
if [ "${1:-}" = "--version" ]; then echo "codex-cli 0.122.0"; exit 0; fi
if [ "${1:-}" = "login" ] && [ "${2:-}" = "status" ]; then echo "ok"; exit 0; fi
OUT_FILE=""
while [ $# -gt 0 ]; do case "$1" in -o) OUT_FILE="$2"; shift 2 ;; *) shift ;; esac; done
[ -n "$OUT_FILE" ] || exit 2
cat >/dev/null 2>&1 || true
# Deliberately write malformed JSON.
printf 'not { valid :: json\n' > "$OUT_FILE"
exit 0   # exit 0 with malformed JSON -> caught by jq -e post-check.
