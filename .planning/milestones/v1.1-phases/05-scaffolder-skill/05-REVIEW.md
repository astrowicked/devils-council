---
phase: 05-scaffolder-skill
reviewed: 2026-04-28T18:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - skills/create-persona/SKILL.md
  - scripts/test-persona-scaffolder.sh
  - scripts/test-scaffolder-skill.sh
  - tests/fixtures/scaffolder/valid-persona.md
  - tests/fixtures/scaffolder/weak-persona.md
  - tests/fixtures/scaffolder/overlap-persona.md
  - CHANGELOG.md
  - README.md
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-04-28T18:00:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Phase 05 delivers the `create-persona` scaffolder skill, two test scripts, three fixture files, and documentation updates. The core wizard logic in `SKILL.md` is sound: the step sequencing is correct, D-0x requirement tags are honored, and the workspace-isolation pattern is well-implemented. Test coverage for the generated-file surface is solid.

Three warnings found: a code-injection vector in the overlap detection Python heredoc, a validator double-invocation that could mask failures, and a missing `yq` prerequisite in the README. Three info items: the README version badge is stale relative to `plugin.json`, a test count mismatch comment in one script, and dead-code in the primary-concern glob fallback.

No critical issues.

---

## Warnings

### WR-01: Banned-phrase injection can break Python heredoc in Step 5 overlap script

**File:** `skills/create-persona/SKILL.md:170`

**Issue:** The overlap detection script uses a triple-quoted Python string literal as a template:

```python
user_bans_raw = """USER_BANNED_PHRASES_HERE""".strip().split('\n')
```

The skill instructs Claude to replace `USER_BANNED_PHRASES_HERE` with the user's actual newline-joined banned phrases before running the script via the Bash tool. If any user-supplied phrase contains `"""` (three consecutive double-quotes), the Python string delimiter is prematurely closed, producing a `SyntaxError`. The Bash tool will then exit non-zero and the overlap check silently falls through (because the overall Bash invocation is not guarded with `|| fail`). The net effect: an author with overlapping banned phrases receives no warning.

**Fix:** Use a heredoc-fed approach that avoids embedding the string inside the source code, or write the phrases to a temp file and pass the path:

```python
# Instead of the triple-quoted inline template, write phrases to a tempfile
# and pass via sys.argv[]:
import yaml, os, sys

user_bans_raw = open(sys.argv[1]).read().strip().split('\n')
user_bans = set(b.strip().lower() for b in user_bans_raw if b.strip())
```

Pair with Bash that writes to a tempfile first:

```bash
TMPFILE=$(mktemp)
printf '%s\n' "${banned_phrases[@]}" > "$TMPFILE"
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/overlap-check.py" "$TMPFILE" "${CLAUDE_PLUGIN_ROOT}/persona-metadata"
rm -f "$TMPFILE"
```

Alternatively, since the Bash tool is used (not shell-inject), Claude can write out a properly escaped Python script file rather than using the heredoc template pattern.

---

### WR-02: Double-invocation of validator in Group 2 can mask a suppressed-error false pass

**File:** `scripts/test-persona-scaffolder.sh:117-119`

**Issue:** The validator is called twice on the weak fixture: once to capture stdout+stderr into `WEAK_OUTPUT`, and once to capture the exit code into `WEAK_EXIT`:

```bash
WEAK_OUTPUT=$("$VALIDATOR" "$WEAK" --signals "$SIGNALS" 2>&1 || true)
WEAK_EXIT=0
"$VALIDATOR" "$WEAK" --signals "$SIGNALS" >/dev/null 2>&1 || WEAK_EXIT=$?
```

If the validator is non-deterministic (e.g., timing-dependent file reads, or a future side-effectful validator), the two runs could diverge: the first run could succeed (capturing benign output) while the second fails (correct exit), or vice versa. More practically, this makes the test harder to reason about and maintains two separate invocations where one suffices.

**Fix:** Capture both output and exit code from a single run:

```bash
WEAK_OUTPUT=$("$VALIDATOR" "$WEAK" --signals "$SIGNALS" 2>&1) && WEAK_EXIT=0 || WEAK_EXIT=$?
```

This single call captures output in `WEAK_OUTPUT` and exit code in `WEAK_EXIT` atomically. Works correctly even under `set -euo pipefail` because the `|| WEAK_EXIT=$?` tail prevents the subshell failure from propagating.

---

### WR-03: `yq` undeclared dependency used in Step 2 without README prerequisite

**File:** `skills/create-persona/SKILL.md:103` / `README.md`

**Issue:** Step 2 of the scaffolder runs a shell snippet that calls `yq` with a python3 fallback:

```bash
pc=$(yq -r '.primary_concern // empty' "$f" 2>/dev/null || python3 -c "...")
```

The `2>/dev/null` suppression means `yq` failures are silent; the python3 fallback covers the absence of `yq`. This is soft-fail by design. However, `yq` is not listed in the README's **Requirements** section, even though `jq` and `python3+PyYAML` are. Users who rely on the primary path (yq) for performance or consistency in CI environments will have no signal that yq is expected.

The README currently lists:

```
- jq
- python3 + PyYAML
- OpenAI Codex CLI
- Node 18+
```

**Fix:** Add `yq` to the Requirements section with an optional note:

```markdown
- **yq** (macOS: `brew install yq`; Ubuntu: `snap install yq`) — optional; used by
  `/devils-council:create-persona` Step 2 for reading sidecar YAML. Falls back to
  python3+PyYAML if absent.
```

---

## Info

### IN-01: README Status badge is stale (v1.0.0 vs plugin.json v1.0.2)

**File:** `README.md:5`

**Issue:** The README Status line reads `v1.0.0` while `plugin.json` reports version `1.0.2` and the `[Unreleased]` CHANGELOG section adds further changes (TD-07 note + scaffolder). The scaffolder is in `[Unreleased]`, so the README not yet reflecting v1.1 is intentional. However, the mismatch between the README badge and the already-shipped `plugin.json` version (1.0.2 vs 1.0.0) is a factual error that could mislead users checking the install verification step (`jq '.[] | select(.name=="devils-council") | .version'` returns `"1.0.2"`, not `"1.0.0"`).

**Fix:** Update the Status line to match the current released version:

```markdown
**Status:** v1.0.2 — ...
```

And update the install verification comment on line 34 from `"1.0.0"` to `"1.0.2"`.

---

### IN-02: Test count in success message is a magic number that diverges from actual test count

**File:** `scripts/test-scaffolder-skill.sh:185`

**Issue:** The success printf hardcodes `16` as the test count argument:

```bash
printf '\nTEST SUITE PASSED (all %d tests)\n' 16
```

The actual test count is: 15 named tests (Test 1–15) + 1 Bonus test = 16, which currently matches. However, this is a magic number that will silently diverge if tests are added or removed without updating the printf. When someone adds Test 16, the message will still say "all 16 tests" — undercounting by one.

**Fix:** Track the count dynamically:

```bash
PASS_COUNT=0
pass() { printf 'PASS: %s\n' "$*"; PASS_COUNT=$((PASS_COUNT + 1)); }
# ...
printf '\nTEST SUITE PASSED (all %d tests)\n' "$PASS_COUNT"
```

---

### IN-03: Primary-concern glob loop in Step 2 is silent no-op when persona-metadata/ is empty

**File:** `skills/create-persona/SKILL.md:100-105`

**Issue:** The Step 2 Bash snippet iterates over `${CLAUDE_PLUGIN_ROOT}/persona-metadata/*.yml`. If the directory is empty or doesn't exist (e.g., a fresh plugin install before any sidecars are generated), bash expands the glob literally, and `basename "*.yml"` returns `*.yml`. The subsequent `yq`/`python3` invocation on a file named literally `*.yml` fails silently (`2>/dev/null`). The list presented to the user is empty, which is tolerable, but the user has no indication that the existing-persona list failed to load — it appears as "no existing personas" rather than "failed to read persona list."

This is a cosmetic-robustness issue, not a correctness bug, because the scaffolder continues correctly with an empty list. It would only surface on a pathological install with no shipped sidecars.

**Fix:** Add a nullglob guard or existence check before the loop:

```bash
if compgen -G "${CLAUDE_PLUGIN_ROOT}/persona-metadata/*.yml" > /dev/null 2>&1; then
  for f in "${CLAUDE_PLUGIN_ROOT}"/persona-metadata/*.yml; do
    # ... existing logic
  done
else
  printf '  (No existing persona sidecars found — nothing to compare against)\n'
fi
```

---

_Reviewed: 2026-04-28T18:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
