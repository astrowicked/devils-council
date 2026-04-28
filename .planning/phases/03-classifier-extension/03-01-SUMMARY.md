---
phase: 03-classifier-extension
plan: 01
subsystem: classifier
tags: [signals, detectors, artifact-type, min-evidence, bench-priority, python, bash]

# Dependency graph
requires:
  - phase: 06-classifier-bench-personas-cost-instrumentation
    provides: "16 v1.0 signals, 16 detectors, classify() function, dc-classify.sh driver, test-classify.sh fixtures"
provides:
  - "5 new signal entries in lib/signals.json (compliance_marker, performance_hotpath, test_imbalance, exec_keyword, shared_infra_change)"
  - "5 new detector functions in lib/classify.py with artifact_type + min_evidence gating"
  - "classify() keyword-only artifact_type parameter with backward-compatible defaults"
  - "bin/dc-classify.sh reads MANIFEST.detected_type and passes --artifact-type to classify.py"
  - "config.json budget.bench_priority_order expanded to 9 entries per D-09"
  - "23 unit tests for new detectors in tests/test_new_detectors.py"
affects: [03-classifier-extension plan 02, phase-4 persona sidecars]

# Tech tracking
tech-stack:
  added: [argparse (stdlib, replaces manual argv)]
  patterns: [try/except TypeError detector dispatch, artifact_type signal gating, min_evidence threshold, diff-file-hint re-invocation guard]

key-files:
  created:
    - tests/test_new_detectors.py
  modified:
    - lib/signals.json
    - lib/classify.py
    - bin/dc-classify.sh
    - config.json
    - .gitignore

key-decisions:
  - "test_imbalance requires 3+ files in diff to fire (prevents false-positives on small focused diffs like v1.0 fixtures)"
  - "config.json at project root updated instead of .planning/config.json (plan reference incorrect; .planning/config.json does not exist)"
  - "try/except TypeError dispatch chosen over inspect.signature for detector backward-compat (simpler, lower overhead)"

patterns-established:
  - "artifact_type-aware detectors accept *, artifact_type: str | None = None as keyword-only"
  - "classify() try/except TypeError dispatch: new detectors get artifact_type, old ones don't"
  - "min_evidence gating at classify() level, not per-detector (signal registry controls threshold)"
  - "diff_file_hint re-invocation guard: file-set detectors skip when hint is a diff path"

requirements-completed: [CLS-01, CLS-02, CLS-03, CLS-04]

# Metrics
duration: 10min
completed: 2026-04-28
---

# Phase 3 Plan 01: Classifier Extension Summary

**5 new signal detectors with artifact_type pipeline propagation, min_evidence gating, and 9-entry bench priority order -- all 17 v1.0 fixtures still green**

## Performance

- **Duration:** 10 min
- **Started:** 2026-04-28T17:18:02Z
- **Completed:** 2026-04-28T17:28:14Z
- **Tasks:** 6
- **Files modified:** 6

## Accomplishments
- 5 new signals (compliance_marker, performance_hotpath, test_imbalance, exec_keyword, shared_infra_change) added to lib/signals.json with signal_strength, min_evidence, target_personas, and optional artifact_type fields
- 5 new detector functions implemented in lib/classify.py: compliance (regex), performance (AST+regex), test_imbalance (file-set diff analysis), exec_keyword (nominalization phrases with code-diff defense-in-depth), shared_infra (path-based)
- classify() extended with keyword-only artifact_type="code-diff" default, artifact_type gating, min_evidence gating, and try/except TypeError dispatch for backward compatibility
- bin/dc-classify.sh reads MANIFEST.detected_type and passes --artifact-type to classify.py with whitelist validation
- config.json bench_priority_order expanded from 4 to 9 entries per D-09 order with rationale comment
- v1.0 backward-compatibility regression gate: 35/35 PASS, 0 FAIL

## Task Commits

Each task was committed atomically:

1. **Task 1: Add 5 new entries to lib/signals.json** - `088b6b0` (feat)
2. **Task 2: Extend classify() signature with artifact_type + min_evidence gating** - `1372c76` (feat)
3. **Task 3: Implement 5 new detector functions** - `5046e2a` (test: RED), `a9b13eb` (feat: GREEN)
4. **Task 4: Extend bin/dc-classify.sh --artifact-type** - `f9e810d` (feat)
5. **Task 5: Add bench_priority_order to config.json** - `0ff2e12` (feat)
6. **Task 6: Backward-compat regression gate** - `e31ff5d` (fix: test_imbalance threshold + gate pass)

Additional: `4a7a187` (chore: add __pycache__ to .gitignore)

## Files Created/Modified
- `lib/signals.json` - 21 signal entries (16 v1.0 + 5 new with signal_strength, min_evidence, artifact_type fields)
- `lib/classify.py` - 5 new detector functions, extended classify() signature, argparse __main__, DETECTORS dict (21 entries)
- `bin/dc-classify.sh` - Reads MANIFEST.detected_type, passes --artifact-type, whitelist case-statement guard
- `config.json` - budget.bench_priority_order expanded to 9 entries with rationale comment
- `tests/test_new_detectors.py` - 23 unit tests for all 5 new detectors
- `.gitignore` - Added __pycache__/ and *.pyc

## Decisions Made
- **test_imbalance 3-file threshold**: The test_imbalance detector requires 3+ files in a diff before analyzing src/test imbalance. Without this, small 1-2 file diffs (including v1.0 fixtures) false-positive. This is a tuning deviation from D-04 (which said strong/min_evidence=1) but preserves the signal's intent for multi-file diffs.
- **config.json location**: Plan referenced `.planning/config.json` which does not exist. Updated `config.json` at project root instead (the actual budget config file).
- **try/except TypeError over inspect.signature**: Simpler and lower-overhead for detector dispatch. The plan suggested inspect.signature as an alternative but try/except is more Pythonic and handles edge cases automatically.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] test_imbalance false-positive on v1.0 fixtures**
- **Found during:** Task 6 (backward-compat regression gate)
- **Issue:** test_imbalance detector fired on secret-handling.env.diff and aws-sdk-import.py.diff because they contain diff headers with src/ paths and no test paths (legitimate small focused changes)
- **Fix:** Added 3-file minimum threshold and diff_file_hint re-invocation guard. Small diffs (1-2 files) are too common for imbalance to be actionable.
- **Files modified:** lib/classify.py, tests/test_new_detectors.py
- **Verification:** v1.0 regression gate 35/35 PASS, unit tests 23/23 PASS
- **Committed in:** e31ff5d

**2. [Rule 2 - Missing Critical] __pycache__ not in .gitignore**
- **Found during:** Task 6 (post-test cleanup)
- **Issue:** Python bytecache generated by test runs was showing as untracked
- **Fix:** Added __pycache__/ and *.pyc to .gitignore
- **Files modified:** .gitignore
- **Committed in:** 4a7a187

**3. [Rule 1 - Bug] config.json path mismatch**
- **Found during:** Task 5 (bench priority order)
- **Issue:** Plan referenced `.planning/config.json` but the actual config file is `config.json` at project root. The existing file already had a budget block with 4 entries.
- **Fix:** Updated the existing `config.json` at project root to expand bench_priority_order from 4 to 9 entries
- **Files modified:** config.json
- **Committed in:** 0ff2e12

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bugs, 1 Rule 2 missing critical)
**Impact on plan:** All auto-fixes necessary for correctness. No scope creep. test_imbalance threshold is a legitimate tuning decision that the plan anticipated ("executor may tune during negative-fixture testing if a strong signal false-positives" per D-04).

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all detectors fully implemented with real logic.

## Next Phase Readiness
- Plan 03-02 is unblocked: all 5 new signal IDs exist in signals.json for validator R7 to accept
- Phase 4 persona sidecars can now reference compliance_marker, performance_hotpath, test_imbalance, exec_keyword, shared_infra_change in their triggers: frontmatter
- Plan 03-02 will add negative fixtures, test-classify.sh extension, Haiku whitelist expansion, and CI workflow updates

---
*Phase: 03-classifier-extension*
*Completed: 2026-04-28*
