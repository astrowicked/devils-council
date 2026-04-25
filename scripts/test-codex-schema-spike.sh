#!/usr/bin/env bash
# test-codex-schema-spike.sh — TD/CODX-01 Codex --output-schema spike harness
#
# Runs 21 real Codex invocations (3 modes x 7 corpus items) and emits a
# single-file JSONL log at .planning/research/codex-schema-spike-runs.jsonl.
#
# Modes (see 02-CONTEXT.md for rationale):
#   wrapped_no_schema   — baseline shape (replicates bin/dc-codex-delegate.sh:205
#                         exec invocation, MINUS --output-schema). Measures the
#                         LOWER BOUND of the wrapper invocation latency. Does NOT
#                         invoke the wrapper itself — no jq/python pre/post, no
#                         MANIFEST write, no draft merge. See memo for caveat.
#   stripped            — identical flags to wrapped_no_schema; isolates codex
#                         startup variance (control cell).
#   with_schema         — same flags + --output-schema templates/codex-security-schema.json.
#                         Item 7 uses the adversarial variant schema.
#
# Output JSONL record shape (one per run):
#   {
#     "mode": "<mode>",
#     "item": <1-7>,
#     "prompt_file": "<path>",
#     "schema_file": "<path|null>",
#     "start_ts": "<ISO8601>",
#     "wall_clock_ms": <int>,
#     "exit_code": <int>,
#     "output_bytes": <int>,
#     "output": <parsed JSON or {"_raw": "..."} on parse failure>,
#     "output_valid_json": <bool>,
#     "schema_valid": <bool|null>,           // null unless mode=with_schema
#     "schema_validation_error": "<str>|null",
#     "codex_version": "<str>",
#     "stderr_tail": "<last 500 chars of stderr, if any>"
#   }
#
# Exit 0 on any completed run — non-zero ONLY on harness bugs (missing files,
# binary not found). Per-run Codex failures are captured in the JSONL, not
# promoted to script exit.

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

FIXTURES_DIR="$REPO_ROOT/.planning/research/spike-fixtures"
OUT_JSONL="$REPO_ROOT/.planning/research/codex-schema-spike-runs.jsonl"
SCHEMA_V1="$REPO_ROOT/templates/codex-security-schema.json"
SCHEMA_ADV="$FIXTURES_DIR/item-07-adversarial-schema.json"

err() { printf 'spike-harness: ERROR: %s\n' "$*" >&2; }
log() { printf 'spike-harness: %s\n' "$*" >&2; }

# ---- pre-checks ------------------------------------------------------------

command -v codex  >/dev/null 2>&1 || { err "codex CLI not on PATH"; exit 2; }
command -v jq     >/dev/null 2>&1 || { err "jq required"; exit 2; }
command -v python3 >/dev/null 2>&1 || { err "python3 required"; exit 2; }

[ -f "$SCHEMA_V1" ]  || { err "v1 schema missing: $SCHEMA_V1"; exit 2; }
[ -f "$SCHEMA_ADV" ] || { err "adversarial schema missing: $SCHEMA_ADV"; exit 2; }
[ -d "$FIXTURES_DIR" ] || { err "fixtures dir missing: $FIXTURES_DIR"; exit 2; }

for i in 1 2 3 4 5 6 7; do
  [ -f "$FIXTURES_DIR/item-0${i}-prompt.txt" ] \
    || { err "missing fixture: item-0${i}-prompt.txt"; exit 2; }
done

CODEX_VERSION="$(codex --version 2>/dev/null | head -1)"
log "codex version: $CODEX_VERSION"

: > "$OUT_JSONL"
log "writing JSONL to: $OUT_JSONL"

# ---- timeout wrapper -------------------------------------------------------

TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
fi
PER_RUN_TIMEOUT_S=120

# ---- per-run ---------------------------------------------------------------

run_one() {
  local mode="$1" item="$2" prompt_file="$3" schema_file="$4"

  local out_file err_file
  out_file="$(mktemp)"
  err_file="$(mktemp)"

  local start_ts start_ms end_ms wall_ms exit_code
  start_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  start_ms="$(python3 -c 'import time;print(int(time.time()*1000))')"

  # Replicates bin/dc-codex-delegate.sh:205 exec flags:
  #   cat <prompt> | codex exec --json --sandbox read-only \
  #     --skip-git-repo-check --ephemeral -o <out> -
  # with_schema mode adds --output-schema <schema>
  local extra_args=()
  if [ "$mode" = "with_schema" ] && [ -n "$schema_file" ] && [ "$schema_file" != "null" ]; then
    extra_args=(--output-schema "$schema_file")
  fi

  set +e
  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" "${PER_RUN_TIMEOUT_S}s" bash -c '
      cat "$1" | codex exec --json --sandbox read-only --skip-git-repo-check --ephemeral -o "$2" "${@:3}" -
    ' _ "$prompt_file" "$out_file" "${extra_args[@]}" 2> "$err_file"
    exit_code=$?
  else
    # Fallback: no timeout binary; rely on codex network-level timeouts.
    cat "$prompt_file" | codex exec --json --sandbox read-only --skip-git-repo-check --ephemeral -o "$out_file" "${extra_args[@]}" - 2> "$err_file"
    exit_code=$?
  fi
  set -e

  end_ms="$(python3 -c 'import time;print(int(time.time()*1000))')"
  wall_ms=$(( end_ms - start_ms ))

  local output_bytes
  output_bytes=$(wc -c < "$out_file" | tr -d ' ')

  # --- Parse output as JSON; schema-validate if applicable -------------------
  # All schema validation runs in python3 to get a single atomic JSON record.
  python3 - "$mode" "$item" "$prompt_file" "${schema_file:-null}" \
                    "$start_ts" "$wall_ms" "$exit_code" "$output_bytes" \
                    "$out_file" "$err_file" "$CODEX_VERSION" "$OUT_JSONL" <<'PYEOF'
import json, sys, os

mode, item, prompt_file, schema_file, start_ts, wall_ms, exit_code, output_bytes, \
    out_file, err_file, codex_version, out_jsonl = sys.argv[1:13]

wall_ms = int(wall_ms)
exit_code = int(exit_code)
output_bytes = int(output_bytes)

try:
    with open(out_file, 'r', encoding='utf-8', errors='replace') as f:
        raw = f.read()
except Exception as e:
    raw = ""

# codex exec --json -o <file> writes the final assistant message as a single
# JSON object (the "message" envelope) OR, when --output-schema is set, the
# raw structured output. We accept either: try raw first, then strip an
# envelope if present.
parsed = None
output_valid_json = False
if raw.strip():
    try:
        parsed = json.loads(raw)
        output_valid_json = True
    except json.JSONDecodeError:
        parsed = None

# Extract the structured payload from a message envelope, if that is what we
# got. Schema validation targets the structured payload, not the envelope.
def try_parse_json_maybe_fenced(s):
    """Parse s as JSON; if fenced in ```json ... ```, strip and retry."""
    if not isinstance(s, str):
        return None, None
    s = s.strip()
    try:
        return json.loads(s), None
    except json.JSONDecodeError:
        pass
    # Strip ```json ... ``` or ``` ... ``` fences
    import re
    m = re.search(r"```(?:json)?\s*\n(.*?)\n```", s, flags=re.DOTALL)
    if m:
        inner = m.group(1).strip()
        try:
            return json.loads(inner), None
        except json.JSONDecodeError as e:
            return None, f"fenced-block not valid JSON: {e}"
    return None, "not valid JSON and no fenced block found"

payload = parsed
if isinstance(parsed, dict) and parsed.get("type") == "message":
    content = parsed.get("content") or []
    if isinstance(content, list):
        texts = [c.get("text", "") for c in content
                 if isinstance(c, dict) and c.get("type") == "text"]
        joined = "".join(texts).strip()
        if joined:
            p, _pe = try_parse_json_maybe_fenced(joined)
            if p is not None:
                payload = p
                output_valid_json = True
            else:
                payload = {"_envelope_text": joined}
elif isinstance(parsed, str):
    p, _pe = try_parse_json_maybe_fenced(parsed)
    if p is not None:
        payload = p
        output_valid_json = True
elif parsed is None and raw.strip():
    # Whole-file was not JSON. Try fenced-block extraction on the raw text
    # (codex `-o` often writes a markdown-fenced JSON blob as the final message).
    p, _pe = try_parse_json_maybe_fenced(raw)
    if p is not None:
        payload = p
        output_valid_json = True

# Schema validation (only for mode=with_schema).
# Empty/unparseable output in with_schema mode counts as schema_valid=false
# (the invocation failed to produce a conforming payload at all).
schema_valid = None
schema_err = None
if mode == "with_schema" and (not output_valid_json or payload is None):
    schema_valid = False
    schema_err = ("no parseable JSON payload to validate "
                  "(likely codex-side schema-submission rejection or empty output)")
if mode == "with_schema" and schema_file and schema_file != "null" and payload is not None and output_valid_json:
    try:
        try:
            import jsonschema  # type: ignore
            with open(schema_file, 'r', encoding='utf-8') as sf:
                schema = json.load(sf)
            try:
                jsonschema.validate(payload, schema)
                schema_valid = True
            except jsonschema.ValidationError as ve:
                schema_valid = False
                schema_err = f"{ve.message} @ {'/'.join(str(p) for p in ve.absolute_path)}"
        except ImportError:
            # Fallback: minimal manual check against v1 required fields.
            with open(schema_file, 'r', encoding='utf-8') as sf:
                schema = json.load(sf)
            required_finding_keys = set(schema["properties"]["findings"]["items"]["required"])
            ok = True
            err = None
            if not isinstance(payload, dict) or "findings" not in payload:
                ok = False; err = "missing top-level findings[]"
            elif not isinstance(payload["findings"], list):
                ok = False; err = "findings is not an array"
            else:
                for idx, f in enumerate(payload["findings"]):
                    if not isinstance(f, dict):
                        ok = False; err = f"finding[{idx}] is not an object"; break
                    missing = required_finding_keys - set(f.keys())
                    if missing:
                        ok = False; err = f"finding[{idx}] missing {sorted(missing)}"; break
                    # evidence length check (v1) — skip for adversarial (oneOf) variant
                    if "minLength" in (schema["properties"]["findings"]["items"]
                                              ["properties"]["evidence"]):
                        ev = f.get("evidence", "")
                        if not isinstance(ev, str) or len(ev) < 8:
                            ok = False; err = f"finding[{idx}] evidence < 8 chars or not string"; break
                    # severity enum check
                    sev = f.get("severity")
                    if sev not in ["blocker", "major", "minor", "nit"]:
                        ok = False; err = f"finding[{idx}] severity not in enum (got {sev!r})"; break
            schema_valid = ok
            schema_err = None if ok else err
    except Exception as e:
        schema_valid = False
        schema_err = f"validator crash: {type(e).__name__}: {e}"

# stderr tail
try:
    with open(err_file, 'r', encoding='utf-8', errors='replace') as f:
        stderr_all = f.read()
    stderr_tail = stderr_all[-500:] if stderr_all else ""
except Exception:
    stderr_tail = ""

# Emit JSONL record — atomic single-line write.
record = {
    "mode": mode,
    "item": int(item),
    "prompt_file": os.path.relpath(prompt_file, os.getcwd()),
    "schema_file": (os.path.relpath(schema_file, os.getcwd())
                    if schema_file and schema_file != "null" else None),
    "start_ts": start_ts,
    "wall_clock_ms": wall_ms,
    "exit_code": exit_code,
    "output_bytes": output_bytes,
    "output": payload if output_valid_json else {"_raw": raw[:2000]},
    "output_valid_json": output_valid_json,
    "schema_valid": schema_valid,
    "schema_validation_error": schema_err,
    "codex_version": codex_version,
    "stderr_tail": stderr_tail,
}

with open(out_jsonl, 'a', encoding='utf-8') as f:
    f.write(json.dumps(record, ensure_ascii=False) + "\n")

# Stdout note for the shell caller — concise status line.
status = "OK" if (exit_code == 0 and output_valid_json) else "FAIL"
print(f"  [{mode:<18}] item={item} {status} exit={exit_code} wall={wall_ms}ms "
      f"json={output_valid_json} schema_valid={schema_valid}")
PYEOF

  rm -f "$out_file" "$err_file"
}

# ---- modes x items ---------------------------------------------------------

TOTAL_RUNS=0
log "starting spike: 3 modes x 7 items = 21 runs"

for mode in wrapped_no_schema stripped with_schema; do
  log "--- mode: $mode ---"
  for i in 1 2 3 4 5 6 7; do
    prompt="$FIXTURES_DIR/item-0${i}-prompt.txt"
    schema="null"
    if [ "$mode" = "with_schema" ]; then
      if [ "$i" = "7" ]; then
        schema="$SCHEMA_ADV"
      else
        schema="$SCHEMA_V1"
      fi
    fi
    run_one "$mode" "$i" "$prompt" "$schema"
    TOTAL_RUNS=$((TOTAL_RUNS + 1))
  done
done

log "completed $TOTAL_RUNS runs; JSONL at $OUT_JSONL"
log "line count: $(wc -l < "$OUT_JSONL" | tr -d ' ')"
