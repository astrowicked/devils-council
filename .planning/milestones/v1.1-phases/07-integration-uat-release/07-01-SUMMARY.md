---
phase: 07-integration-uat-release
plan: 01
subsystem: test-infrastructure, uat-fixtures
tags: [uat, budget-cap, blinded-reader, 9-bench, fixtures]
dependency_graph:
  requires: [budget-classifier-all-bench.json, test-budget-cap.sh, test-blinded-reader.sh, config.json]
  provides: [budget-classifier-9bench-all.json, anaconda-platform-chart.md, verify-uat-live-run.sh, 9-bench-scenario]
  affects: [scripts/test-budget-cap.sh, scripts/test-blinded-reader.sh]
tech_stack:
  added: []
  patterns: [pre-baked-classifier-fixture, llm-as-judge-attribution, uat-verification-wrapper]
key_files:
  created:
    - tests/fixtures/uat-9bench/anaconda-platform-chart.md
    - tests/fixtures/bench-personas/budget-classifier-9bench-all.json
    - scripts/verify-uat-live-run.sh
  modified:
    - scripts/test-budget-cap.sh
    - scripts/test-blinded-reader.sh
decisions:
  - "UAT fixture modeled on anaconda-platform-chart with synthetic content triggering all 9 bench signals (D-01, D-02, D-03)"
  - "9-bench scenario added as Case 6 per D-04/D-05 convention"
  - "LLM-as-judge gated behind --live-judge flag to keep CI structural-only"
  - "Task 4 deferred to manual execution — created verify-uat-live-run.sh wrapper for post-review validation"
metrics:
  duration: "4m 28s"
  completed: "2026-04-29"
  tasks_completed: 4
  tasks_total: 4
  files_created: 3
  files_modified: 2
---

# Phase 7 Plan 01: UAT Fixture + 9-Bench Budget-Cap + Blinded-Reader Judge Summary

Synthetic anaconda-platform-chart fixture (222 lines) triggering all 9 bench persona signals simultaneously, extended budget-cap test with 9-bench Case 6 proving top-6 priority selection, and LLM-as-judge blinded-reader mode for post-review persona attribution evaluation.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create 9-bench UAT fixture + classifier fixture | f61ad14 | tests/fixtures/uat-9bench/anaconda-platform-chart.md, tests/fixtures/bench-personas/budget-classifier-9bench-all.json |
| 2 | Extend test-budget-cap.sh with 9-bench scenario | 0d5575e | scripts/test-budget-cap.sh |
| 3 | Extend test-blinded-reader.sh with LLM-as-judge | a19e792 | scripts/test-blinded-reader.sh |
| 4 | UAT live run verification infrastructure | 42e4884 | scripts/verify-uat-live-run.sh |

## Key Decisions

1. **UAT fixture as synthetic plan document** — Modeled on anaconda-platform-chart but with entirely synthetic content (no proprietary references). Structured as a migration plan to naturally trigger executive-sponsor and test-lead signals alongside the infrastructure signals.

2. **9-bench Case 6 placement** — Inserted before the existing bonus non-numeric validation (which was relabeled from "Case 6 (bonus)" to "Bonus validation"). This matches D-04/D-05 language of "6th scenario."

3. **LLM-as-judge behind flag** — The `--live-judge` mode requires Claude CLI auth and a real review run, so it cannot run in CI. Structural readiness checks remain the CI gate; live evaluation is a manual UAT step.

4. **Task 4 as manual step** — `/devils-council:review` is an interactive Claude Code command that cannot execute from a subagent context. Created `verify-uat-live-run.sh` as a wrapper to validate post-review output.

## Manual Steps Required (Task 4)

Task 4 requires human execution. Steps:

1. **Run the live review:**
   ```bash
   /devils-council:review tests/fixtures/uat-9bench/anaconda-platform-chart.md --type=plan
   ```

2. **Validate the output:**
   ```bash
   ./scripts/verify-uat-live-run.sh
   ```

3. **Optional — run blinded-reader attribution:**
   ```bash
   ./scripts/verify-uat-live-run.sh --with-judge
   ```

Expected outcomes:
- SYNTHESIS.md passes dc-validate-synthesis.sh (REL-01)
- At least 6 persona scorecards produced (4 core + budget-capped bench)
- MANIFEST.json shows `over_budget: true` and >= 3 `personas_skipped`
- Blinded-reader attribution >= 80% (PQUAL-03)

## Verification Results

| Check | Result |
|-------|--------|
| `bash scripts/test-budget-cap.sh` (all 6 + bonus) | PASSED |
| `bash scripts/test-blinded-reader.sh` (structural) | PASSED (5/5) |
| 9-bench classifier fixture: 9 triggered personas | PASSED |
| UAT fixture: 222 lines with all signal patterns | PASSED |
| Live review run (Task 4) | DEFERRED to manual execution |

## Deviations from Plan

### Auto-added Functionality

**1. [Rule 2 - Missing critical functionality] Created verify-uat-live-run.sh**
- **Found during:** Task 4
- **Issue:** Task 4 cannot execute interactively from subagent; needed a verification wrapper for human to run post-review
- **Fix:** Created scripts/verify-uat-live-run.sh that validates synthesis, scorecard count, and budget enforcement
- **Files created:** scripts/verify-uat-live-run.sh
- **Commit:** 42e4884

## Known Stubs

None. All files are fully functional:
- UAT fixture contains real signal-triggering content (not placeholder text)
- Budget-cap scenario exercises dc-budget-plan.sh end-to-end with deterministic fixture
- LLM-as-judge has a complete implementation gated behind `--live-judge` flag
- Verification script validates all acceptance criteria from Task 4

## Self-Check: PASSED

All 5 files verified on disk. All 4 task commits verified in git log.
