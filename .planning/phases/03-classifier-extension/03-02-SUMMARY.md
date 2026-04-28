---
phase: 03-classifier-extension
plan: 02
subsystem: classifier
tags: [negative-fixtures, inverted-tdd, haiku-whitelist, ci-split, false-positive-prevention]

# Dependency graph
requires:
  - phase: 03-classifier-extension
    plan: 01
    provides: "5 new signal entries + 5 new detectors + artifact_type pipeline + 23 unit tests"
provides:
  - "17 negative fixtures across 5 detector categories under tests/fixtures/classifier-negatives/"
  - "test-classify.sh negatives-first ordering with run_negative_case helper (immediate exit 1 on false positive)"
  - "test-classify.sh --negatives-only and --positives-only flags for CI step split"
  - "5 new positive fixtures for v1.1 detectors in tests/fixtures/bench-personas/"
  - "agents/artifact-classifier.md Haiku whitelist expanded from 4 to 8 bench slugs"
  - "ci.yml two-step classifier pipeline: negatives-first, positives-second (D-16 enforcement)"
affects: [phase-4 persona sidecars, phase-7 integration UAT]

# Tech tracking
tech-stack:
  added: []
  patterns: [inverted-TDD negative-first ordering, CI step split for test-ordering enforcement, run_negative_case immediate-exit-on-false-positive]

key-files:
  created:
    - tests/fixtures/classifier-negatives/compliance-marker/helm-values-benign-1.yaml
    - tests/fixtures/classifier-negatives/compliance-marker/autoscaling-benign-1.yaml
    - tests/fixtures/classifier-negatives/compliance-marker/plain-python-benign-1.py
    - tests/fixtures/classifier-negatives/performance-hotpath/autoscaling-benign-1.yaml
    - tests/fixtures/classifier-negatives/performance-hotpath/helm-values-benign-1.yaml
    - tests/fixtures/classifier-negatives/performance-hotpath/single-function-benign-1.py
    - tests/fixtures/classifier-negatives/test-imbalance/aws-sdk-benign-1.diff
    - tests/fixtures/classifier-negatives/test-imbalance/no-diff-benign-1.md
    - tests/fixtures/classifier-negatives/test-imbalance/balanced-diff-benign-1.diff
    - tests/fixtures/classifier-negatives/test-imbalance/docs-only-diff-benign-1.diff
    - tests/fixtures/classifier-negatives/exec-keyword/chart-yaml-benign-1.yaml
    - tests/fixtures/classifier-negatives/exec-keyword/helm-values-benign-1.yaml
    - tests/fixtures/classifier-negatives/exec-keyword/plain-plan-benign-1.md
    - tests/fixtures/classifier-negatives/exec-keyword/code-with-roadmap-variable-benign-1.diff
    - tests/fixtures/classifier-negatives/shared-infra-change/autoscaling-benign-1.yaml
    - tests/fixtures/classifier-negatives/shared-infra-change/helm-values-benign-1.yaml
    - tests/fixtures/classifier-negatives/shared-infra-change/zero-signals-benign-1.md
    - tests/fixtures/bench-personas/v11-compliance-positive.md
    - tests/fixtures/bench-personas/v11-performance-positive.diff
    - tests/fixtures/bench-personas/v11-test-imbalance-positive.diff
    - tests/fixtures/bench-personas/v11-exec-keyword-positive.md
    - tests/fixtures/bench-personas/v11-shared-infra-positive.diff
  modified:
    - scripts/test-classify.sh
    - agents/artifact-classifier.md
    - .github/workflows/ci.yml

key-decisions:
  - "v11-performance-positive fixture uses JS/TS diff (not Python) because performance_hotpath regex patterns target JS-style for(...){} loops; Python AST parsing requires pure .py files but artifact_type gate requires code-diff classification"
  - "aws-sdk-import.py.diff kept as test-imbalance negative (1-file diff < 3-file threshold) despite src/ path -- the 3-file minimum from Plan 03-01 prevents false-positive"
  - "17 negative fixtures (exceeding 15 minimum) with 4 fixtures each in test-imbalance and exec-keyword categories"

patterns-established:
  - "run_negative_case exits 1 immediately on false positive (not collected like run_case)"
  - "CI two-step pattern: negatives-only step gates positives-only step via GH Actions sequential semantics"
  - "Negative fixtures use mix of repurposed v1.0 fixtures (proven benign) + targeted synthetic content"

requirements-completed: [CLS-05, CLS-06]

# Metrics
duration: 9min
completed: 2026-04-28
---

# Phase 3 Plan 02: Classifier Negative Fixtures + Haiku Whitelist + CI Inverted-TDD Summary

**17 negative fixtures with inverted-TDD ordering, 5 new positive assertions, Haiku whitelist expanded to 8 bench slugs, CI split into negatives-first/positives-second two-step pipeline**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-28T17:34:01Z
- **Completed:** 2026-04-28T17:43:22Z
- **Tasks:** 5
- **Files created:** 22
- **Files modified:** 3

## Accomplishments

- 17 negative fixtures across 5 detector categories (compliance-marker: 3, performance-hotpath: 3, test-imbalance: 4, exec-keyword: 4, shared-infra-change: 3)
- `run_negative_case` helper in test-classify.sh with immediate exit-1-on-false-positive semantics (inverted-TDD per D-16)
- `--negatives-only` and `--positives-only` flags for CI step splitting
- 5 new positive fixtures for v1.1 detectors (compliance-reviewer, performance-reviewer, test-lead, executive-sponsor, competing-team-lead)
- Haiku classifier whitelist expanded from 4 to 8 bench slugs in agents/artifact-classifier.md; executive-sponsor and junior-engineer explicitly excluded with rationale
- CI workflow split from 1 classifier step to 2: negatives-first step gates positives step via GH Actions default sequential failure semantics
- All 17 v1.0 positive assertions still green (D-20 backward-compat)
- Phase 4 unblocked: 21 signals in signals.json + 8-slug Haiku whitelist

## Task Commits

Each task was committed atomically:

1. **Task 1: Create 5 negative-fixture subdirectories with 17 fixtures** - `ad5bad3` (test)
2. **Task 2: Extend test-classify.sh + 5 new positive fixtures** - `7f8d0d0` (feat)
3. **Task 3: Expand Haiku whitelist from 4 to 8 slugs** - `a0d1466` (feat)
4. **Task 4: Split CI classifier step into two** - `e496266` (feat)
5. **Task 5: End-to-end phase-level gate** - verification only, no file changes

## Negative Fixture Inventory

| Detector Category | Fixture Count | Sources |
|---|---|---|
| compliance-marker | 3 | helm-values (repurposed), autoscaling (repurposed), plain-python (synthetic) |
| performance-hotpath | 3 | autoscaling (repurposed), helm-values (repurposed), single-function (synthetic) |
| test-imbalance | 4 | aws-sdk 1-file diff (repurposed), zero-signals md (repurposed), balanced-diff (synthetic), docs-only-diff (synthetic) |
| exec-keyword | 4 | chart-yaml (repurposed), helm-values (repurposed), plain-plan (synthetic), code-with-roadmap-var (synthetic) |
| shared-infra-change | 3 | autoscaling (repurposed), helm-values (repurposed), zero-signals (repurposed) |
| **Total** | **17** | 9 repurposed v1.0 + 8 new synthetic |

## Fixture Replacement Notes

- **aws-sdk-import.py.diff** was kept as a test-imbalance negative (not replaced) because it contains only 1 diff file (`src/uploader.py`), which is below the 3-file minimum threshold established in Plan 03-01. The plan flagged this as a potential issue, but the threshold makes it safe.

## Decisions Made

- **Performance positive fixture format**: Used JS/TS diff instead of Python because performance_hotpath's regex fallback patterns target `for(...){...query()}` JS syntax. Python AST parsing requires pure `.py` files but the `artifact_type: ["code-diff"]` signal gate requires diff classification. The JS/TS diff format satisfies both constraints.
- **17 fixtures (exceeding 15 minimum)**: test-imbalance and exec-keyword got 4 fixtures each (instead of minimum 3) to cover additional edge cases -- balanced diffs, docs-only diffs, code-diffs with exec-like variable names.

## Phase 4 Unblock Confirmation

- lib/signals.json: 21 entries (16 v1.0 + 5 new) -- all 5 new signal IDs present
- agents/artifact-classifier.md: 8 bench slugs in Haiku whitelist
- Validator R7 can now accept persona sidecars referencing compliance_marker, performance_hotpath, test_imbalance, exec_keyword, shared_infra_change
- Haiku fallback can route to compliance-reviewer, performance-reviewer, test-lead, competing-team-lead

## Deviations from Plan

None -- plan executed exactly as written. The only adjustment was using JS/TS diff format for the performance positive fixture instead of Python (plan provided Python example content but did not mandate format; the detector's regex patterns required JS-style syntax for code-diff artifacts).

## Known Stubs

None -- all fixtures contain real content, all test assertions verify actual classifier behavior.

## Threat Flags

None -- no new network endpoints, auth paths, or trust boundary changes introduced. All changes are test fixtures, test script logic, agent prompt text, and CI workflow configuration.

## Self-Check: PASSED

- All 26 files verified present on disk
- All 4 task commits verified in git log (ad5bad3, 7f8d0d0, a0d1466, e496266)
- Full test suite (all 3 modes) exits 0
- CI YAML parses without error
- 21 signals in signals.json, 8 bench slugs in whitelist, 17 negative fixtures

---
*Phase: 03-classifier-extension*
*Completed: 2026-04-28*
