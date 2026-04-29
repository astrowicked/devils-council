---
phase: 06-codex-schema-rollout
plan: 02
subsystem: codex-delegation-tests
tags: [codex, schema, testing, ci, stubs]
dependency_graph:
  requires: [bin/dc-codex-delegate.sh, lib/codex-schemas/security.json, scripts/test-codex-delegation.sh]
  provides: [10-case-test-harness, schema-path-ci-coverage, codex-stub-schema-fixtures]
  affects: [.github/workflows/ci.yml]
tech_stack:
  added: []
  patterns: [PATH-injected-stubs, jq-boolean-null-handling, delegation_failed-YAML-key-assertion]
key_files:
  created:
    - tests/fixtures/bench-personas/codex-stub-schema-invalid.sh
    - tests/fixtures/bench-personas/codex-stub-schema-validation-error.sh
  modified:
    - tests/fixtures/bench-personas/codex-stub-success.sh
    - scripts/test-codex-delegation.sh
    - .github/workflows/ci.yml
decisions:
  - "delegation_failed YAML key assertion instead of findings category: section 8b writes to delegation_failed[] not findings[], so the extra_category check reads the YAML key directly"
  - "jq false-vs-null: use explicit null check (if . == null then) instead of // operator which treats false as falsy"
  - "schema_used assertion as 7th run_case parameter: keeps assertions co-located with their test case instead of fragile post-hoc scanning"
metrics:
  duration: 557s
  completed: 2026-04-29T07:22:11Z
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 3
---

# Phase 06 Plan 02: Schema Test Harness + CI Wiring Summary

Extended test-codex-delegation.sh from 7 to 10 cases covering schema-enforced success, schemaless fallback, and schema-validation-error paths with MANIFEST schema_used/codex_schema_version assertions; added CI schema structure validation step.

## Tasks Completed

### Task 1: Create 3 new codex stubs for schema test cases + update success stub
- **Commit:** fa1221f
- **Files:** codex-stub-success.sh (modified), codex-stub-schema-invalid.sh (created), codex-stub-schema-validation-error.sh (created)
- Updated success stub: added --help handler with --output-schema, parse --output-schema flag during exec, emit findings-array when schema present or message-envelope when absent
- Created schema-invalid stub: --help omits --output-schema (simulates old codex v0.100.0), always emits message-envelope format
- Created schema-validation-error stub: --help includes --output-schema (feature-detect passes), emits findings JSON missing required `evidence` and `ask` fields to trigger section 8b validation failure

### Task 2: Extend test-codex-delegation.sh with 3 schema test cases + CI wiring
- **Commit:** 0376fb2
- **Files:** scripts/test-codex-delegation.sh (modified), .github/workflows/ci.yml (modified)
- Added 3 new run_case calls: schema-success (case 8), schema-fallback (case 9), schema-validation-err (case 10)
- Extended run_case() function with optional 6th param (extra_category for delegation_failed YAML key check) and 7th param (expected_schema_used)
- Added MANIFEST schema field assertions: codex_schema_version presence check for all succeeded cases, schema_used true/false check for schema cases
- Fixed jq boolean handling: `false // "null"` evaluates to `"null"` in jq; switched to explicit `if . == null then "null" else tostring end`
- Added CI step "Codex schema delegation tests (Phase 6 CODX-02/03/04)" validating lib/codex-schemas/security.json structure with jq assertions on required fields and array lengths
- All 10 test cases pass with all assertions green

## Decisions Made

1. **delegation_failed YAML key vs findings category:** Section 8b of dc-codex-delegate.sh writes schema validation errors to the `delegation_failed[]` YAML key in the draft frontmatter, NOT to the `findings[]` array. The test's extra_category check was adapted to read the YAML key directly using python3+yaml rather than checking findings categories.

2. **jq false-vs-null handling:** jq's `//` (alternative) operator treats both `null` AND `false` as falsy, so `.schema_used // "null"` returns `"null"` when schema_used is `false`. Fixed with explicit null check: `if . == null then "null" else tostring end`.

3. **schema_used as run_case parameter:** Rather than a fragile post-hoc scan of TEST_DIRS array indices, the schema_used assertion was integrated as a 7th optional parameter to run_case(), keeping assertions co-located with their test case invocation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] jq false-vs-null in schema_used assertion**
- **Found during:** Task 2 (test run)
- **Issue:** `jq -r '.personas_run[0].delegation.schema_used // "null"'` returns `"null"` for the schema-fallback case where schema_used is `false`, because jq's `//` operator treats `false` as falsy.
- **Fix:** Changed to `jq -r '.personas_run[0].delegation.schema_used | if . == null then "null" else tostring end'` which correctly distinguishes `false` from `null`.
- **Files modified:** scripts/test-codex-delegation.sh
- **Commit:** 0376fb2

**2. [Rule 1 - Bug] delegation_failed category assertion wrong target**
- **Found during:** Task 2 (test run)
- **Issue:** Plan assumed schema-validation-err would produce a `delegation_failed` category in the findings array. Actual behavior: section 8b writes to `delegation_failed[]` YAML key (not `findings[]`), so the category grep against findings missed it.
- **Fix:** Added special-case handling: when `expected_extra_category=delegation_failed`, read the `delegation_failed[]` YAML key and check for `codex_schema_validation_error` class instead of checking findings categories.
- **Files modified:** scripts/test-codex-delegation.sh
- **Commit:** 0376fb2

## Verification Results

All 5 plan verification checks passed:
1. `bash -n scripts/test-codex-delegation.sh` -- syntax OK
2. `grep -cP '^\s*run_case\s' scripts/test-codex-delegation.sh` returns 10
3. `scripts/test-codex-delegation.sh` -- all 10 cases PASS, exit 0
4. `grep -q 'CODX-02' .github/workflows/ci.yml` -- schema CI step present
5. All 3 stubs pass `bash -n` syntax check

## Known Stubs

None. All test stubs produce concrete output matching real Codex behavior patterns. All assertions validate actual MANIFEST field values.

## Threat Flags

None. Test infrastructure only -- no new network endpoints, auth paths, or trust boundary crossings.

## Self-Check: PASSED

- All 2 created files exist on disk
- All 3 modified files exist on disk
- All 2 task commits verified in git log (fa1221f, 0376fb2)
- SUMMARY.md exists at expected path
