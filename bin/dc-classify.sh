#!/usr/bin/env bash
# dc-classify.sh <INPUT.md> <MANIFEST.json> [<filename-hint>]
#
# Shell wrapper for lib/classify.py. D-55.
# Reads INPUT.md + lib/signals.json, invokes classify(), merges output into
# MANIFEST.json at .classifier, .triggered_personas, .trigger_reasons.
#
# Exit codes:
#   0 — classification written successfully (even when triggered_personas is [])
#   1 — classifier failed (python exception, malformed signals.json, etc.) —
#       conductor treats this as degrade-to-core per RESEARCH.md Pitfall 6
#   2 — usage error
#
# Partial-failure contract: on exit 1, bin/dc-classify.sh writes
#   .classifier = {error: "<msg>", version: 0, deterministic_match_count: 0,
#                   needs_haiku: false, triggered_personas: [], trigger_reasons: {}}
# into MANIFEST.json so the conductor always has a classifier block to read.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

err() { printf 'dc-classify: ERROR: %s\n' "$*" >&2; }

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  err "usage: dc-classify.sh <INPUT.md> <MANIFEST.json> [<filename-hint>]"
  exit 2
fi

INPUT_MD="$1"
MANIFEST="$2"
HINT="${3:-$INPUT_MD}"
SIGNALS="${REPO_ROOT}/lib/signals.json"

[ -f "$INPUT_MD" ]  || { err "INPUT.md not found: $INPUT_MD"; exit 2; }
[ -f "$MANIFEST" ]  || { err "MANIFEST.json not found: $MANIFEST"; exit 2; }
[ -f "$SIGNALS" ]   || { err "signals.json not found: $SIGNALS"; exit 2; }

# python3 detection mirrors bin/dc-prep.sh idiom
PYTHON3=""
if command -v python3 >/dev/null 2>&1; then
  if python3 -c 'import yaml, ast, json, re, hashlib' >/dev/null 2>&1; then
    PYTHON3="python3"
  fi
fi
[ -n "$PYTHON3" ] || { err "python3 with yaml/ast/json/re/hashlib required"; exit 1; }

command -v jq >/dev/null 2>&1 || { err "jq required"; exit 1; }

# --- Extract artifact_type from MANIFEST (D-06) ---
ARTIFACT_TYPE=$(jq -r '.detected_type // "code-diff"' "$MANIFEST" 2>/dev/null || printf 'code-diff')
# Guard: if empty or null string made it through, default
case "$ARTIFACT_TYPE" in
  code-diff|plan|rfc|design) ;;
  ""|null) ARTIFACT_TYPE="code-diff" ;;
  *) err "unknown detected_type '$ARTIFACT_TYPE' in MANIFEST — defaulting to code-diff"; ARTIFACT_TYPE="code-diff" ;;
esac

# Invoke classifier; capture stdout separately from stderr
OUT_JSON=$(mktemp)
ERR_LOG=$(mktemp)
trap 'rm -f "$OUT_JSON" "$ERR_LOG"' EXIT

set +e
"$PYTHON3" "${REPO_ROOT}/lib/classify.py" "$INPUT_MD" "$SIGNALS" "$HINT" --artifact-type "$ARTIFACT_TYPE" > "$OUT_JSON" 2> "$ERR_LOG"
CLS_EXIT=$?
set -e

if [ "$CLS_EXIT" -ne 0 ] || ! jq -e . "$OUT_JSON" >/dev/null 2>&1; then
  # Degrade-to-core: write error block so conductor can still proceed
  ERR_MSG=$(head -c 500 "$ERR_LOG" | tr '\n' ' ' | tr -d '\000')
  TMP_MF=$(mktemp)
  jq --arg msg "$ERR_MSG" '
    .classifier = {error: $msg, version: 0, deterministic_match_count: 0,
                   needs_haiku: false, triggered_personas: [], trigger_reasons: {}}
    | .triggered_personas = []
    | .trigger_reasons = {}
  ' "$MANIFEST" > "$TMP_MF" && mv "$TMP_MF" "$MANIFEST"
  err "classifier failed (exit $CLS_EXIT): $ERR_MSG"
  exit 1
fi

# Merge classifier result into MANIFEST additively
TMP_MF=$(mktemp)
jq --slurpfile cls "$OUT_JSON" '
  .classifier = $cls[0]
  | .triggered_personas = ($cls[0].triggered_personas // [])
  | .trigger_reasons = ($cls[0].trigger_reasons // {})
' "$MANIFEST" > "$TMP_MF" && mv "$TMP_MF" "$MANIFEST"

printf 'dc-classify: OK — %d signals, %d personas, artifact_type=%s\n' \
  "$(jq -r '.classifier.deterministic_match_count' "$MANIFEST")" \
  "$(jq -r '.triggered_personas | length' "$MANIFEST")" \
  "$ARTIFACT_TYPE" >&2
exit 0
