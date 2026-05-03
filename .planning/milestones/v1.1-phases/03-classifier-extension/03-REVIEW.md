---
phase: 03-classifier-extension
reviewed: 2026-04-28T18:42:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - lib/classify.py
  - lib/signals.json
  - bin/dc-classify.sh
  - config.json
  - scripts/test-classify.sh
  - agents/artifact-classifier.md
  - .github/workflows/ci.yml
  - tests/test_new_detectors.py
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-04-28T18:42:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Phase 3 adds 5 new signal detectors (`compliance_marker`, `performance_hotpath`, `test_imbalance`, `exec_keyword`, `shared_infra_change`), an `artifact_type` keyword argument and `min_evidence` gating to `classify()`, a `--artifact-type` CLI pipeline in `bin/dc-classify.sh`, negative-fixture-first test ordering in the test harness, Haiku whitelist expansion to 8 personas, two-step CI enforcement, and `bench_priority_order` in `config.json`.

Overall quality is solid. The test infrastructure (negative-first ordering, inverted-TDD, per-signal fixture isolation) is well-designed for catching false positives. The `artifact_type` gating is correctly belt-and-suspenders (both in `signals.json` and within detector functions). The CI two-step split for negatives-before-positives is a good enforcement mechanism.

Four warnings identified: duplicate evidence from non-deduplicated `diff_file_hints` inflating `min_evidence` gates, constant-literal false positives in the `performance_hotpath` AST detector, a temp file leak in `dc-classify.sh`, and the `exec_keyword` detector matching variable names that happen to look like executive language.

## Warnings

### WR-01: diff_file_hints not deduplicated -- evidence inflation past min_evidence gates

**File:** `lib/classify.py:540-544`
**Issue:** The `diff_file_hints` list is populated from both `+++ b/<path>` and `diff --git a/<path>` headers. For a standard unified diff, every file appears in BOTH headers, producing duplicate entries. When `classify()` iterates `diff_file_hints` (line 560-565), each detector runs twice per diff-file (once for `+++ b/` match, once for `diff --git a/` match), in addition to the primary hint. This inflates evidence counts and can push a signal past its `min_evidence` threshold on weaker input than intended. For new Phase 3 detectors that rely on `min_evidence=2` (compliance_marker, performance_hotpath, exec_keyword), this reduces the effective gate to `min_evidence=1` in diff contexts.

This is a pre-existing issue (affects v1.0 detectors too), but Phase 3 makes it load-bearing because three new signals depend on `min_evidence=2` for precision.

**Fix:** Deduplicate `diff_file_hints` before the detector loop:
```python
diff_file_hints: list[str] = []
for m in re.finditer(r'(?:^|\n)\+\+\+\s+b/(\S+)', text):
    diff_file_hints.append(m.group(1))
for m in re.finditer(r'(?:^|\n)diff --git a/(\S+)', text):
    diff_file_hints.append(m.group(1))
diff_file_hints = list(dict.fromkeys(diff_file_hints))  # deduplicate, preserve order
```

### WR-02: performance_hotpath AST detector fires on constant collection literals inside loops

**File:** `lib/classify.py:376-381`
**Issue:** The AST walker flags ALL `ast.List`, `ast.Dict`, and `ast.Set` literals inside loop bodies as "per-iteration allocations." This includes constant lookup tables or configuration data that happens to be written inside a loop:

```python
for user in users:
    roles = ['admin', 'viewer', 'editor']  # constant -- not a hot-path issue
    perms = {'read': True, 'write': False}  # constant -- not a hot-path issue
```

This produces 2+ evidence items, which meets the `min_evidence=2` threshold and fires the signal. In real-world code, inline constant collection literals inside loops are common (e.g., allowlists, enum-like lookups). Combined with WR-01 (evidence inflation from duplicate diff_file_hints), this further increases false-positive risk.

The `min_evidence=2` gate was explicitly designed to prevent false positives (per `signals.json`: "Requires 2 distinct matches"), but constant-literal detection weakens this guarantee.

**Fix:** Consider restricting AST literal detection to cases where the literal is passed as an argument to a function call (indicating allocation of a data structure for processing), or remove the bare-literal detection entirely and rely only on `list()`/`dict()`/`set()` constructor calls and DB query patterns:
```python
# Remove lines 377-378 (ast.List/Dict/Set detection)
# Keep lines 379-381 (list()/dict()/set() constructor calls) which are
# more likely to indicate intentional per-iteration allocation
```

### WR-03: Temp file leak in dc-classify.sh error path

**File:** `bin/dc-classify.sh:73,85`
**Issue:** The `TMP_MF` variable (created via `mktemp` on lines 73 and 85) is not included in the `trap` cleanup on line 63. If the script is interrupted between `mktemp` and `mv`, the temp file leaks. The `trap` only cleans up `$OUT_JSON` and `$ERR_LOG`. While `mv` atomically replaces the destination, an interrupt between `jq ... > "$TMP_MF"` and `mv "$TMP_MF" "$MANIFEST"` leaves an orphaned temp file.

**Fix:** Either add `TMP_MF` to the trap, or use a single temp file pattern:
```bash
TMP_MF=""
trap 'rm -f "$OUT_JSON" "$ERR_LOG" "$TMP_MF"' EXIT
```
Set `TMP_MF=$(mktemp)` just before each use (lines 73 and 85), so the trap always has the current value.

### WR-04: exec_keyword matches variable/identifier names in plan/rfc artifacts

**File:** `lib/classify.py:462-467`
**Issue:** The `single_words` patterns in `_detect_exec_keyword` use `\b` word boundaries, which match variable names and identifiers. For example, `roadmap = build_roadmap()` in a plan that includes code snippets will match `\broadmap\b` twice. Similarly, `Q1`, `Q2` etc. match quarter references in changelogs or version notes commonly embedded in plans. When `artifact_type` is `plan` or `rfc`, these fire even on technical content that contains code examples.

The detector correctly guards against `code-diff` (line 445), but plans and RFCs often embed code snippets, variable names, or changelog references that trigger the single-word patterns. With `min_evidence=2`, two occurrences of `roadmap` as a variable name is sufficient to fire the signal.

**Fix:** Consider requiring at least one phrase-pattern match (from the `phrases` list) before counting single-word matches, or increase the minimum evidence threshold for single-word-only matches:
```python
phrase_evidence = []
for pat in phrases:
    for m in re.finditer(pat, text, re.I):
        phrase_evidence.append(m.group(0))
single_evidence = []
for pat in single_words:
    for m in re.finditer(pat, text, re.I):
        single_evidence.append(m.group(0))
# Require at least 1 phrase match, or 3+ single-word matches
if phrase_evidence:
    evidence = phrase_evidence + single_evidence
else:
    evidence = single_evidence if len(single_evidence) >= 3 else []
return evidence
```

## Info

### IN-01: yaml import unused at runtime

**File:** `lib/classify.py:15`
**Issue:** The `yaml` import has `# noqa: F401` with comment "imported for runtime availability check; future detectors may use." However, no detector uses it, and the availability check is not enforced anywhere (a missing `yaml` would fail silently at import time but no detector would break). If `yaml` is meant as a prerequisite check, consider making it explicit; otherwise, it is dead code.

**Fix:** Either remove the import or add a comment referencing the specific future detector that will use it.

### IN-02: tests/test_new_detectors.py uses custom test runner instead of pytest

**File:** `tests/test_new_detectors.py:219-233`
**Issue:** The test file implements a custom `__main__` runner that discovers test functions by name prefix. While functional, this duplicates pytest's core discovery behavior and loses pytest features (parametrize, markers, fixtures, better failure output). The file is compatible with pytest (bare `assert` statements, `test_` naming convention), so the custom runner is technically unnecessary.

**Fix:** Optional: remove the `if __name__ == "__main__"` block and run via `pytest tests/test_new_detectors.py`. Low priority since the current approach works and may be intentional to avoid a pytest dependency.

### IN-03: `bin/dc-classify.sh` Python detection checks for unused modules

**File:** `bin/dc-classify.sh:43`
**Issue:** The Python capability check imports `yaml, ast, json, re, hashlib` to verify they are available. `hashlib` is not used by `lib/classify.py` (it was presumably included because `bin/dc-prep.sh` uses it). This is not a bug -- the check is overly conservative rather than insufficient -- but it means the script could fail on systems where `hashlib` is unavailable even though the classifier does not need it.

**Fix:** Remove `hashlib` from the import check, or split the check so `dc-classify.sh` only validates modules it actually needs (`yaml, ast, json, re`).

---

_Reviewed: 2026-04-28T18:42:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
