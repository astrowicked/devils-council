---
phase: 04-six-personas-atomic-conductor-wiring
reviewed: 2026-04-28T22:15:00Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - .github/workflows/ci.yml
  - agents/competing-team-lead.md
  - agents/compliance-reviewer.md
  - agents/executive-sponsor.md
  - agents/junior-engineer.md
  - agents/performance-reviewer.md
  - agents/test-lead.md
  - bin/dc-budget-plan.sh
  - commands/review.md
  - persona-metadata/competing-team-lead.yml
  - persona-metadata/compliance-reviewer.yml
  - persona-metadata/executive-sponsor.yml
  - persona-metadata/junior-engineer.yml
  - persona-metadata/performance-reviewer.yml
  - persona-metadata/test-lead.yml
  - scripts/test-blinded-reader.sh
  - scripts/test-chair-synthesis.sh
  - scripts/validate-personas.sh
  - tests/fixtures/blinded-reader/multi-signal-fixture.md
  - tests/fixtures/exec-sponsor-adversarial/temptation-plan.md
  - tests/fixtures/exec-sponsor-adversarial/test-exec-sponsor-adversarial.sh
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-04-28T22:15:00Z
**Depth:** standard
**Files Reviewed:** 21
**Status:** issues_found

## Summary

Phase 4 delivers six new bench personas (compliance-reviewer, performance-reviewer, test-lead, executive-sponsor, competing-team-lead, junior-engineer) with persona-metadata sidecars, conductor wiring in commands/review.md, budget-plan integration in bin/dc-budget-plan.sh, and supporting test infrastructure. The code is well-structured overall -- persona agents follow a consistent template with worked examples and banned-phrase discipline, the budget-plan script handles edge cases carefully, and the CI workflow covers the new features with appropriate guard conditions.

Three warnings found: a potential command injection vector in bin/dc-budget-plan.sh via unvalidated ARTIFACT_TYPE passed to yq, a jq misuse of `input_filename` in commands/review.md that will fail at runtime, and a tempfile leak in bin/dc-budget-plan.sh on early exit. Three info items cover minor inconsistencies and test brittleness.

## Warnings

### WR-01: ARTIFACT_TYPE passed unescaped to yq expression

**File:** `bin/dc-budget-plan.sh:95`
**Issue:** `ARTIFACT_TYPE` is read from MANIFEST.json via jq (`jq -r '.artifact_type // ""'`) and then interpolated directly into a yq expression on line 95: `yq -e ".always_invoke_on // [] | .[] | select(. == \"$ARTIFACT_TYPE\")"`. If a malicious or malformed MANIFEST.json contains an `artifact_type` value with embedded quotes or yq metacharacters (e.g., `code-diff") | ... | .x = "pwned`), the yq expression can be manipulated. While MANIFEST.json is produced by trusted tooling (bin/dc-prep.sh), the artifact is untrusted input that flows through the system.
**Fix:** Use yq's `--arg` or `env()` to pass the value as a variable rather than string interpolation:
```bash
if ARTIFACT_TYPE="$ARTIFACT_TYPE" yq -e 'env(ARTIFACT_TYPE) as $at | .always_invoke_on // [] | .[] | select(. == $at)' "$yml" >/dev/null 2>&1; then
```
Or validate ARTIFACT_TYPE against an allowlist of known artifact types before the loop.

### WR-02: jq `input_filename` used without `--rawfile` or `inputs` -- will fail at runtime

**File:** `commands/review.md:105`
**Issue:** The `--show-nits` dedup shell-inject block uses `jq -r ... 'select(.artifact_path == $p or .sha256 == $sha) | input_filename' "$m"`. The `input_filename` builtin in jq reports the filename of the current input, but it is only meaningful when using `--rawfile`, `inputs`, or multiple file arguments. When a single file is passed as a positional argument and no `inputs` builtin is used, `input_filename` returns the filename of that single file -- which is `$m` itself, so the variable `$MATCH` will always be set to `$m` if the `select()` passes, which is the correct behavior in this specific case. However, the semantic intent is fragile: if the jq filter's `select()` does NOT match, the entire expression produces no output (correct), but the pattern relies on undocumented behavior of `input_filename` with a single positional file.
**Fix:** Replace the fragile pattern with explicit filename handling:
```bash
if jq -e --arg p "$RESOLVED_PATH" --arg sha "$ART_SHA" \
    'select(.artifact_path == $p or .sha256 == $sha)' "$m" >/dev/null 2>&1; then
  echo "RUN_DIR=$(dirname "$m")"
  echo "SKIP_FANOUT=1"
  break
fi
```
This is clearer, avoids the `input_filename` edge case, and has the same semantics.

### WR-03: Tempfile not cleaned up on early exit in dc-budget-plan.sh

**File:** `bin/dc-budget-plan.sh:173-194`
**Issue:** A `TMP_MF=$(mktemp)` is created on line 173 (inside the jq merge block). If the `jq` command or the `mv` fails (e.g., disk full, permission error), `set -e` will exit the script immediately, leaving the tempfile behind. While `set -e` causes exit before the script reaches line 209 (normal exit), there is no `trap` to clean up `$TMP_MF` on abnormal exit.
**Fix:** Add a cleanup trap near the top of the script after variable declarations:
```bash
_cleanup() { [ -n "${TMP_MF:-}" ] && rm -f "$TMP_MF" 2>/dev/null; }
trap _cleanup EXIT
```
Or declare TMP_MF earlier and add a single trap. This prevents tempfile accumulation in `/tmp` on repeated failures.

## Info

### IN-01: test-blinded-reader.sh PASSED counter can undercount

**File:** `scripts/test-blinded-reader.sh:103`
**Issue:** The `PASSED` counter is computed as `$((TOTAL_CHECKS - FAIL))` where `TOTAL_CHECKS=5` is hardcoded. But `FAIL` is incremented once per failed check, and some checks can fail multiple times (e.g., the sidecar existence check at line 34 can fail up to 9 times, each incrementing `FAIL`). When more than 5 individual failures occur, `PASSED` goes negative, producing nonsensical output like "Blinded-reader readiness: -4/5 checks passed."
**Fix:** Track PASSED and FAILED as separate category-level counters (one per check category, not per individual failure), or cap PASSED at 0:
```bash
PASSED=$((TOTAL_CHECKS - (FAIL > TOTAL_CHECKS ? TOTAL_CHECKS : FAIL)))
```
Alternatively, count category-level pass/fail rather than individual sidecar failures.

### IN-02: CI workflow step conditionals use -x on scripts but not all scripts have execute bit in git

**File:** `.github/workflows/ci.yml:90-93`
**Issue:** The "Adversarial Exec Sponsor fixture" step checks `[ -x tests/fixtures/exec-sponsor-adversarial/test-exec-sponsor-adversarial.sh ]` before running. This works correctly on fresh checkout only if the file has the executable bit set in git (`git update-index --chmod=+x`). If it was committed without the execute bit, the conditional silently skips the test and prints the "skipped" message, which CI treats as green. This is by design for graceful phase-gating, but makes it easy to miss a missing chmod.
**Fix:** No code change needed -- this is by design per the phase-gating pattern. Noting for awareness that execute bit must be set when committing new test scripts, or the CI step will silently skip.

### IN-03: commands/review.md line 24 -- second shell-inject uses fragile `ls -t | head -1` pattern

**File:** `commands/review.md:24`
**Issue:** The classifier invocation uses `$(ls -t .council/*/INPUT.md 2>/dev/null | head -1)` and similar for MANIFEST.json. This relies on filesystem mtime ordering and will break if two runs happen within the same second (same mtime), or if the filesystem does not preserve sub-second timestamps. In practice, `dc-prep.sh` creates only one run dir per invocation so this is unlikely to produce wrong results, but the pattern is fragile.
**Fix:** Since `dc-prep.sh` emits `RUN_DIR=<path>` on stdout (parsed in the block immediately above), the classifier should reference `$RUN_DIR/INPUT.md` and `$RUN_DIR/MANIFEST.json` directly instead of re-discovering via `ls -t`. This is likely a shell-inject ordering issue where the RUN_DIR variable is not yet available at the point of this shell-inject execution.

---

_Reviewed: 2026-04-28T22:15:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
