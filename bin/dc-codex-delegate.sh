#!/usr/bin/env bash
# dc-codex-delegate.sh <persona> <run-dir>
#
# Reads <run-dir>/<persona>-draft.md; if its YAML frontmatter contains a
# `delegation_request:` block, invokes `codex exec --json --sandbox read-only`
# per skills/codex-deep-scan/SKILL.md and merges results back into the draft
# (as additional findings with source: codex-delegate, OR a delegation_failed
# finding on error). Writes <run-dir>/MANIFEST.json .personas_run[<persona>].delegation.
#
# This runs BEFORE bin/dc-validate-scorecard.sh in the conductor flow — the
# validator then sees the merged draft with codex findings already in place,
# subject to the same verbatim-evidence check.
#
# Exit codes:
#   0 — delegation attempted (whether succeeded or failed per D-51); draft
#       updated; MANIFEST delegation block written
#   1 — structural error (missing draft, missing MANIFEST, malformed
#       delegation_request — e.g. sandbox != read-only pre-check)
#   2 — usage error
#
# D-51 fail-loud: ALL 6 error classes produce exit 0 with delegation.status=failed
# in MANIFEST + delegation_failed finding in the draft. The persona still ships
# whatever it authored itself; validator runs on the merged draft next.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

err() { printf 'dc-codex-delegate: ERROR: %s\n' "$*" >&2; }

if [ $# -ne 2 ]; then
  err "usage: dc-codex-delegate.sh <persona> <run-dir>"
  exit 2
fi

PERSONA="$1"
RUN_DIR="$2"
DRAFT="$RUN_DIR/${PERSONA}-draft.md"
MANIFEST="$RUN_DIR/MANIFEST.json"

[ -f "$DRAFT" ]     || { err "draft not found: $DRAFT"; exit 1; }
[ -f "$MANIFEST" ]  || { err "MANIFEST.json not found: $MANIFEST"; exit 1; }

command -v jq >/dev/null 2>&1        || { err "jq required"; exit 1; }
command -v python3 >/dev/null 2>&1   || { err "python3 required"; exit 1; }
python3 -c 'import yaml' >/dev/null 2>&1 || { err "PyYAML required"; exit 1; }

ATTEMPTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# REQ_JSON is populated further below; default so write_failure can reference
# it even in pre-extraction pre-checks (current design defers pre-checks until
# after extraction, but REQ_JSON is set to "null" here as a guard).
REQ_JSON="null"

# ---------------------------------------------------------------
# Helper: write_failure — defined BEFORE any call so every pre-check
# (sandbox, codex binary, auth) and every post-check (timeout, parse,
# sandbox violation, unknown exit) can invoke it. D-51 fail-loud.
# ---------------------------------------------------------------
write_failure() {
  local code="$1" msg="$2"
  local now="$ATTEMPTED_AT"
  # Append delegation_failed finding to draft frontmatter
  python3 - "$DRAFT" "$code" "$msg" "$now" "$REQ_JSON" <<'PYEOF'
import sys, yaml, json
path, code, msg, now, req_json = sys.argv[1:6]
text = open(path, encoding='utf-8').read()
parts = text.split('---', 2)
fm = yaml.safe_load(parts[1]) or {}
try:
    req = json.loads(req_json) if req_json else None
except (json.JSONDecodeError, TypeError):
    req = None
if not isinstance(req, dict):
    req = {}
failure_block = {
    "class": code,
    "message": msg,
    "attempted_at": now,
    "request": {
        "target": req.get("target"),
        "question": req.get("question"),
    }
}
fm.setdefault('delegation_failed', []).append(failure_block)
# Also add a synthetic finding with category: delegation_failed (D-51).
fm.setdefault('findings', []).append({
    "target": req.get("target", "unknown") or "unknown",
    "claim": f"Codex delegation failed: {code}. The deep scan requested by this persona was not completed.",
    "evidence": json.dumps(failure_block),  # verbatim envelope per D-51
    "ask": msg,
    "severity": "major",
    "category": "delegation_failed",
})
out = "---\n" + yaml.safe_dump(fm, sort_keys=False, default_flow_style=False) + "---" + parts[2]
open(path, 'w', encoding='utf-8').write(out)
PYEOF
  # Update MANIFEST.personas_run[].delegation
  local tmp; tmp=$(mktemp)
  jq --arg persona "$PERSONA" --arg code "$code" --arg msg "$msg" --arg now "$now" '
    (.personas_run // []) as $runs
    | .personas_run = (
        if ($runs | map(.name == $persona) | any) then
          ($runs | map(if .name == $persona then
            .delegation = {status: "failed", error_code: $code, message: $msg, attempted_at: $now, duration_ms: null}
          else . end))
        else
          $runs + [{name: $persona, delegation: {status: "failed", error_code: $code, message: $msg, attempted_at: $now, duration_ms: null}}]
        end
      )
  ' "$MANIFEST" > "$tmp" && mv "$tmp" "$MANIFEST"
}

# ---------------------------------------------------------------
# 1. Extract delegation_request from draft frontmatter.
# ---------------------------------------------------------------
REQ_JSON=$(python3 - "$DRAFT" <<'PYEOF'
import sys, yaml, json
text = open(sys.argv[1], encoding='utf-8').read()
parts = text.split('---', 2)
if len(parts) < 3:
    print("null"); sys.exit(0)
try:
    fm = yaml.safe_load(parts[1]) or {}
except yaml.YAMLError:
    print("null"); sys.exit(0)
req = fm.get('delegation_request')
print(json.dumps(req) if req else "null")
PYEOF
)

if [ -z "$REQ_JSON" ] || [ "$REQ_JSON" = "null" ]; then
  # No delegation_request block — write not_invoked to MANIFEST and exit 0.
  TMP_MF=$(mktemp)
  jq --arg persona "$PERSONA" '
    (.personas_run // []) as $runs
    | .personas_run = (
        if ($runs | map(.name == $persona) | any) then
          ($runs | map(if .name == $persona then
            .delegation = {status: "not_invoked", error_code: null, message: null, attempted_at: null, duration_ms: null}
          else . end))
        else
          $runs + [{name: $persona, delegation: {status: "not_invoked", error_code: null, message: null, attempted_at: null, duration_ms: null}}]
        end
      )
  ' "$MANIFEST" > "$TMP_MF" && mv "$TMP_MF" "$MANIFEST"
  exit 0
fi

# ---------------------------------------------------------------
# 2. Pre-check: sandbox MUST be read-only (D-02); reject otherwise.
# ---------------------------------------------------------------
SANDBOX=$(printf '%s' "$REQ_JSON" | jq -r '.sandbox // "read-only"')
if [ "$SANDBOX" != "read-only" ]; then
  write_failure "codex_sandbox_violation" \
    "Codex was invoked with or requested a non-read-only sandbox. Widening the sandbox is out of scope for v1 and requires a dedicated threat-model review."
  exit 0
fi

# ---------------------------------------------------------------
# 3. Pre-check: codex binary present (error_code=codex_not_installed).
# ---------------------------------------------------------------
if ! command -v codex >/dev/null 2>&1; then
  write_failure "codex_not_installed" \
    "Codex CLI not found on PATH. Install via 'brew install --cask codex' (macOS) or 'npm install -g @openai/codex', then run 'codex login'."
  exit 0
fi

# ---------------------------------------------------------------
# 4. Pre-check: auth valid (error_code=codex_auth_expired).
# ---------------------------------------------------------------
if ! codex login status >/dev/null 2>&1; then
  write_failure "codex_auth_expired" \
    "Codex authentication expired or missing. Run 'codex login' to re-auth, or set OPENAI_API_KEY."
  exit 0
fi

# ---------------------------------------------------------------
# 5. Build prompt file from delegation_request.question + context_files.
# ---------------------------------------------------------------
PROMPT_FILE=$(mktemp)
OUT_FILE=$(mktemp)
ERR_LOG=$(mktemp)
trap 'rm -f "$PROMPT_FILE" "$OUT_FILE" "$ERR_LOG"' EXIT

QUESTION=$(printf '%s' "$REQ_JSON" | jq -r '.question // ""')
TARGET=$(printf '%s' "$REQ_JSON"   | jq -r '.target   // ""')
TIMEOUT=$(printf '%s' "$REQ_JSON"  | jq -r '.timeout_seconds // 60')

{
  printf 'Target: %s\n' "$TARGET"
  printf 'Question: %s\n' "$QUESTION"
  printf 'Context files referenced in request (read only, cite line numbers): '
  printf '%s' "$REQ_JSON" | jq -r '.context_files // [] | join(", ")'
  printf '\n'
} > "$PROMPT_FILE"

# ---------------------------------------------------------------
# 6. Invoke codex with wall-clock timeout (error_code=codex_timeout).
# ---------------------------------------------------------------
START_MS=$(python3 -c 'import time; print(int(time.time()*1000))')
set +e
# `timeout` exists on ubuntu-latest; on macOS use `gtimeout` if present, else background-kill.
if command -v timeout >/dev/null 2>&1; then
  timeout "${TIMEOUT}s" bash -c 'cat "$1" | codex exec --json --sandbox read-only --skip-git-repo-check --ephemeral -o "$2" -' _ "$PROMPT_FILE" "$OUT_FILE" 2> "$ERR_LOG"
  EXIT_CODE=$?
elif command -v gtimeout >/dev/null 2>&1; then
  gtimeout "${TIMEOUT}s" bash -c 'cat "$1" | codex exec --json --sandbox read-only --skip-git-repo-check --ephemeral -o "$2" -' _ "$PROMPT_FILE" "$OUT_FILE" 2> "$ERR_LOG"
  EXIT_CODE=$?
else
  # Portable fallback — background process + sleep-kill.
  ( cat "$PROMPT_FILE" | codex exec --json --sandbox read-only --skip-git-repo-check --ephemeral -o "$OUT_FILE" - 2> "$ERR_LOG" ) &
  CODEX_PID=$!
  ( sleep "$TIMEOUT" && kill -TERM "$CODEX_PID" 2>/dev/null ) &
  KILLER_PID=$!
  wait "$CODEX_PID" 2>/dev/null
  EXIT_CODE=$?
  kill "$KILLER_PID" 2>/dev/null || true
fi
set -e
END_MS=$(python3 -c 'import time; print(int(time.time()*1000))')
DURATION_MS=$((END_MS - START_MS))

# Exit code 124 (GNU timeout) or 143 (SIGTERM) → timeout class.
TIMEOUT_THRESHOLD_MS=$(( TIMEOUT * 1000 - 100 ))
if [ "$EXIT_CODE" -eq 124 ] || [ "$EXIT_CODE" -eq 143 ] \
   || { [ "$EXIT_CODE" -ne 0 ] && [ "$DURATION_MS" -ge "$TIMEOUT_THRESHOLD_MS" ]; }; then
  write_failure "codex_timeout" \
    "Codex timed out after ${TIMEOUT}s. Narrow context_files, simplify the question, or raise timeout_seconds."
  # Append duration_ms to MANIFEST.
  TMP_MF=$(mktemp); jq --arg persona "$PERSONA" --argjson dur "$DURATION_MS" '
    .personas_run = (.personas_run | map(if .name == $persona then .delegation.duration_ms = $dur else . end))
  ' "$MANIFEST" > "$TMP_MF" && mv "$TMP_MF" "$MANIFEST"
  exit 0
fi

# ---------------------------------------------------------------
# 7. Post-check: sandbox violation (stderr contains 'sandbox').
# ---------------------------------------------------------------
if [ "$EXIT_CODE" -ne 0 ] && grep -qi 'sandbox' "$ERR_LOG"; then
  write_failure "codex_sandbox_violation" \
    "Codex reported a sandbox violation during execution. v1 only permits read-only."
  exit 0
fi

# ---------------------------------------------------------------
# 8. Post-check: JSON parseability (error_code=codex_json_parse_error).
# ---------------------------------------------------------------
if [ "$EXIT_CODE" -eq 0 ] && ! jq -e . "$OUT_FILE" >/dev/null 2>&1; then
  # Preserve raw output for inspection per SKILL.md taxonomy.
  cp "$OUT_FILE" "$RUN_DIR/codex-errors.log"
  write_failure "codex_json_parse_error" \
    "Codex returned malformed JSON. Raw output logged to $RUN_DIR/codex-errors.log."
  exit 0
fi

# ---------------------------------------------------------------
# 9. Other non-zero (error_code=codex_unknown).
# ---------------------------------------------------------------
if [ "$EXIT_CODE" -ne 0 ]; then
  cp "$ERR_LOG" "$RUN_DIR/codex-errors.log" 2>/dev/null || true
  write_failure "codex_unknown" \
    "Codex exited with code $EXIT_CODE. See $RUN_DIR/codex-errors.log for details."
  exit 0
fi

# ---------------------------------------------------------------
# 10. Success — merge Codex findings into draft.
# ---------------------------------------------------------------
python3 - "$DRAFT" "$OUT_FILE" "$ATTEMPTED_AT" <<'PYEOF'
import sys, json, yaml
draft_path, out_path, now = sys.argv[1:4]
text = open(draft_path, encoding='utf-8').read()
parts = text.split('---', 2)
fm = yaml.safe_load(parts[1]) or {}
fm.setdefault('findings', [])
# Parse the stub's output — success stub writes a single JSON object.
with open(out_path, encoding='utf-8') as f:
    raw = f.read().strip()
try:
    msg = json.loads(raw)
    # Extract any "text" content. Stub format:
    #   {"type":"message","content":[{"type":"text","text":"..."}]}
    summary_text = ""
    if isinstance(msg, dict) and msg.get("type") == "message":
        for c in msg.get("content", []):
            if c.get("type") == "text":
                summary_text += c.get("text", "")
    elif isinstance(msg, dict) and "text" in msg:
        summary_text = msg["text"]
    if summary_text:
        fm['findings'].append({
            "target": fm.get('delegation_request', {}).get('target', 'unknown'),
            "claim": f"Codex deep scan: {summary_text[:200]}",
            "evidence": summary_text[:500],  # codex-delegate is verbatim from codex output
            "ask": "Review the cited locations and address the issues Codex surfaced.",
            "severity": "major",
            "category": "codex-delegate",
            "source": "codex-delegate",
        })
except (json.JSONDecodeError, KeyError, TypeError):
    pass  # Success path with unusual shape — leave draft unchanged.
out = "---\n" + yaml.safe_dump(fm, sort_keys=False, default_flow_style=False) + "---" + parts[2]
open(draft_path, 'w', encoding='utf-8').write(out)
PYEOF

TMP_MF=$(mktemp)
jq --arg persona "$PERSONA" --arg now "$ATTEMPTED_AT" --argjson dur "$DURATION_MS" '
  (.personas_run // []) as $runs
  | .personas_run = (
      if ($runs | map(.name == $persona) | any) then
        ($runs | map(if .name == $persona then
          .delegation = {status: "succeeded", error_code: null, message: null, attempted_at: $now, duration_ms: $dur}
        else . end))
      else
        $runs + [{name: $persona, delegation: {status: "succeeded", error_code: null, message: null, attempted_at: $now, duration_ms: $dur}}]
      end
    )
' "$MANIFEST" > "$TMP_MF" && mv "$TMP_MF" "$MANIFEST"

exit 0
