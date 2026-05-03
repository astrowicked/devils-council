---
phase: 06-codex-schema-rollout
reviewed: 2026-04-28T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - bin/dc-codex-delegate.sh
  - lib/codex-schemas/security.json
  - scripts/test-codex-delegation.sh
  - skills/codex-deep-scan/SKILL.md
  - .github/workflows/ci.yml
  - tests/fixtures/bench-personas/codex-stub-success.sh
  - tests/fixtures/bench-personas/codex-stub-schema-invalid.sh
  - tests/fixtures/bench-personas/codex-stub-schema-validation-error.sh
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-04-28T00:00:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Reviewed the Phase 6 Codex schema-rollout deliverables: the delegation
orchestrator (`bin/dc-codex-delegate.sh`), the JSON schema for structured
output (`lib/codex-schemas/security.json`), the delegation test harness
(`scripts/test-codex-delegation.sh`), the updated skill contract
(`skills/codex-deep-scan/SKILL.md`), the CI workflow additions, and the
three new stub fixtures.

The core logic is sound. The three-branch `--output-schema` WRAPPER path
(feature-detect → strict pre-check → schema validation), the eight error
classes, and the D-51 fail-loud contract all hang together correctly.
The test harness exercises the right assertions for cases 8–10.

Three warnings require attention before the phase ships: a potential
unhandled `IndexError` in `write_failure`, an arithmetic crash when
`timeout_seconds` is a float, and a word-splitting hazard when the schema
path contains spaces. None of these are likely to fire in practice given
current callers, but each violates the D-51 fail-loud contract by turning
an expected recoverable condition into an unexpected exit 1.

Three informational items cover a misleading SKILL.md error-message
description, a confusing fixture filename, and a garbled inline comment.

---

## Warnings

### WR-01: `write_failure` does not guard against draft with no YAML frontmatter

**File:** `bin/dc-codex-delegate.sh:71-102`

**Issue:** The embedded Python in `write_failure` calls `text.split('---', 2)` and
immediately accesses `parts[1]` and `parts[2]` without checking that `len(parts) >= 3`.
If the draft file exists but contains no `---` delimiters (e.g., a plain-text file
passed by a caller in error), `parts[1]` raises `IndexError`, the Python process
exits non-zero, and `write_failure` fails — causing the surrounding `set -e` context
to propagate an exit 1 rather than the D-51 fail-loud exit 0.

The extraction heredoc at lines 124–136 correctly guards with `if len(parts) < 3:
print("null"); sys.exit(0)`, but `write_failure` lacks this guard.

**Fix:**
```python
# After: parts = text.split('---', 2)
if len(parts) < 3:
    # Malformed draft: no YAML frontmatter. Write fallback frontmatter + original text.
    fm = {}
    body = text
else:
    fm = yaml.safe_load(parts[1]) or {}
    body = parts[2]
```
Replace the three unconditional `parts[1]`/`parts[2]` accesses in `write_failure`
(lines 75 and 101) with this guarded pattern. Mirror the same fix in the
`codex_schema_validation_error` Python block at lines 388–402 (line 393/401).

---

### WR-02: Float `timeout_seconds` causes bash arithmetic crash instead of fail-loud exit 0

**File:** `bin/dc-codex-delegate.sh:254,297`

**Issue:** `TIMEOUT` is populated from `jq -r '.timeout_seconds // 60'` at line 254.
If the delegation request includes `timeout_seconds: 60.5` (a YAML float), jq returns
the string `"60.5"`. Bash integer arithmetic at line 297 then fails:

```
TIMEOUT_THRESHOLD_MS=$(( TIMEOUT * 1000 - 100 ))
# bash: 60.5: arithmetic syntax error: invalid arithmetic operator (error token is ".5")
```

Because `set -e` is re-enabled at line 292 (after the codex invocation block), this
arithmetic error causes the script to exit 1 — a structural error — rather than the
expected fail-loud exit 0 per D-51. The GNU `timeout "${TIMEOUT}s"` command accepts
fractional seconds, so that call would succeed; only the threshold arithmetic fails.

**Fix:**
```bash
# Line 297: truncate to integer before arithmetic
TIMEOUT_INT=$(printf '%.0f' "${TIMEOUT}")
TIMEOUT_THRESHOLD_MS=$(( TIMEOUT_INT * 1000 - 100 ))
```
Use `printf '%.0f'` (rounds to nearest integer) or `${TIMEOUT%%.*}` (truncates
fractional part). Apply the same truncation for the `timeout "${TIMEOUT}s"` call
if consistency is desired, though GNU `timeout` handles floats natively.

---

### WR-03: `SCHEMA_ARGS` is vulnerable to word-splitting when schema path contains spaces

**File:** `bin/dc-codex-delegate.sh:270,277,280,284`

**Issue:** `SCHEMA_ARGS` is built at line 270 as a plain string:
```bash
SCHEMA_ARGS="--output-schema $SCHEMA_FILE"
```
It is then interpolated unquoted into two `bash -c` command strings at lines 277 and 280:
```bash
bash -c '... --ephemeral '"$SCHEMA_ARGS"' -o "$2" -' _ "$PROMPT_FILE" "$OUT_FILE"
```
If `$SCHEMA_FILE` contains a space (e.g., a path like
`/home/user/my schemas/security.json`), the resulting `bash -c` string becomes:
```
... --ephemeral --output-schema /home/user/my schemas/security.json -o ...
```
Bash word-splits this so `schemas/security.json` becomes a separate argument, breaking
the `codex exec` invocation. The fallback path at line 284 also has an unquoted
`$SCHEMA_ARGS` in a subshell.

In practice, schema paths live under `$REPO_ROOT/lib/codex-schemas/` which is unlikely
to contain spaces, but the pattern is fragile. The path is constructed from user-controlled
`$PERSONA` (line 205), so a plugin install in a space-containing directory would trigger this.

**Fix:**
Use an array instead of a string for schema arguments:
```bash
# Replace lines 268-271:
SCHEMA_ARGS=()
if [ "$USE_SCHEMA" = true ] && [ -n "$SCHEMA_FILE" ]; then
  SCHEMA_ARGS=(--output-schema "$SCHEMA_FILE")
fi
```
Then replace the `bash -c` invocations with a function or script that receives
`$SCHEMA_FILE` as a positional argument, passed through `"$@"`:
```bash
# lines 277-280: pass as positional args to bash -c using $3/$4:
timeout "${TIMEOUT}s" bash -c \
  'cat "$1" | codex exec --json --sandbox read-only --skip-git-repo-check --ephemeral ${3:+--output-schema "$3"} -o "$2" -' \
  _ "$PROMPT_FILE" "$OUT_FILE" "${SCHEMA_FILE:-}"
```
Alternatively, write the invocation to a temp script file and exec it, avoiding
the `bash -c` string-interpolation pattern entirely.

---

## Info

### IN-01: SKILL.md error taxonomy message for `codex_schema_invalid` is inaccurate

**File:** `skills/codex-deep-scan/SKILL.md:146`

**Issue:** The taxonomy table lists the `codex_schema_invalid` message as:
> "Schema at {path} contains OpenAI strict-mode disallowed keywords. Falling back to schemaless delegation."

This is the message for the **silent pre-check** fallback in section 4d of
`dc-codex-delegate.sh`, which uses `err()` (stderr-only) and continues schemalessly
without writing any `delegation_failed` entry. However, `codex_schema_invalid` is the
error code written by **section 7b** (runtime HTTP 400 rejection), which calls
`write_failure` and exits 0 with `delegation.status=failed` — no fallback occurs.

The message "Falling back" is therefore misleading for the actual runtime behavior the
error code represents.

**Fix:** Update the taxonomy row message to match section 7b behavior:
```
"Schema at {path} was rejected by the Codex API (HTTP 400 or schema-validation error at submit time). Delegation failed; persona continues with its own findings. No schemaless retry attempted."
```
If a separate informational log is desired for the pre-check fallback, use the
`codex_schema_precheck_fallback` event (or similar) with a distinct message.

---

### IN-02: `codex-stub-schema-invalid.sh` fixture name does not match the error class it exercises

**File:** `tests/fixtures/bench-personas/codex-stub-schema-invalid.sh`

**Issue:** The stub is named `codex-stub-schema-invalid.sh`, which suggests it tests the
`codex_schema_invalid` error class (HTTP 400 rejection at runtime). However, this stub
exercises the **schemaless fallback path**: its `--help` output omits `--output-schema`,
causing the feature-detect in section 4c to set `USE_SCHEMA=false` and skip schema
enforcement entirely. The delegation succeeds schemalessly; no `codex_schema_invalid`
error is ever generated.

The corresponding test case at `scripts/test-codex-delegation.sh:197` is named
`"schema-fallback"`, which is accurate, but the fixture filename creates a false
association with the `codex_schema_invalid` error class.

**Fix:** Rename the fixture to `codex-stub-no-schema-support.sh` (or
`codex-stub-old-codex.sh`) to signal that it simulates an older Codex version without
`--output-schema` support, rather than a schema-rejection error. Update the `ln -s`
reference in `test-codex-delegation.sh` line 197 accordingly. There is currently no
stub that exercises the actual `codex_schema_invalid` runtime path (section 7b), which
is a coverage gap worth noting.

---

### IN-03: Garbled comment in section 7b of `dc-codex-delegate.sh`

**File:** `bin/dc-codex-delegate.sh:322`

**Issue:** The comment reads:
```bash
#     Persona still gets results via schemaless retry is NOT attempted --
```
This is grammatically broken and contradictory ("gets results via schemaless retry"
conflicts with "is NOT attempted").

**Fix:**
```bash
#     Persona still gets its own findings; schemaless retry is NOT attempted --
```

---

_Reviewed: 2026-04-28T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
