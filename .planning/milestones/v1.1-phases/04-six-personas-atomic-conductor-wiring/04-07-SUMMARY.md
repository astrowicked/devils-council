---
phase: 04-six-personas-atomic-conductor-wiring
plan: 07
subsystem: conductor
tags: [conductor-wiring, bench-personas, budget-plan, always-invoke-on, display-names]

# Dependency graph
requires:
  - phase: 04-01 through 04-06
    provides: "All 6 new persona agent files + sidecars (compliance-reviewer, performance-reviewer, test-lead, executive-sponsor, competing-team-lead, junior-engineer)"
  - phase: 03 (Phase 3 classifier extension)
    provides: "9-entry bench_priority_order in config.json, 5 new signal IDs in signals.json, Haiku whitelist at 8 slugs"
provides:
  - "Conductor bench whitelist expanded from 4 to 9 signal-triggered entries"
  - "Display-name map expanded to 14 entries (8 existing + 6 new)"
  - "dc-budget-plan.sh reads always_invoke_on from persona sidecars"
  - "Junior Engineer auto-appended to spawn list on code-diff artifacts, bypassing budget cap"
affects: [04-08-fixtures-validation, phase-5-scaffolder, phase-7-uat]

# Tech tracking
tech-stack:
  added: []
  patterns: ["always_invoke_on sidecar field bypass pattern for auto-invoked personas"]

key-files:
  created: []
  modified:
    - "bin/dc-budget-plan.sh"
    - "commands/review.md"

key-decisions:
  - "always_invoke_on reading in dc-budget-plan.sh (not in conductor) per D-05 — budget planner scans persona-metadata/*.yml sidecars for artifact_type match"
  - "JE appended AFTER budget cap application to ensure it bypasses cap per D-06"
  - "Bench whitelist uses 9 signal-triggered entries; JE documented separately as always_invoke_on bypass"

patterns-established:
  - "always_invoke_on: sidecar field pattern for personas that bypass both classifier signals and budget cap"
  - "Display-name map in review.md as single source of truth for persona slug-to-human-name mapping"

requirements-completed: [BNCH2-01, BNCH2-02, BNCH2-03, BNCH2-04, BNCH2-05, CORE-EXT-01]

# Metrics
duration: 3min
completed: 2026-04-28
---

# Phase 4 Plan 07: Conductor Wiring Summary

**Atomic conductor wiring: bench whitelist 4-to-9, display-name map 8-to-14, always_invoke_on bypass for Junior Engineer on code-diff artifacts**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-28T19:13:21Z
- **Completed:** 2026-04-28T19:16:29Z
- **Tasks:** 3 (2 implementation + 1 verification-only)
- **Files modified:** 2

## Accomplishments
- Expanded bench persona enumeration in conductor from 4 to 9 signal-triggered entries in a single atomic commit per D-13
- Added always_invoke_on sidecar scanning to dc-budget-plan.sh so Junior Engineer auto-spawns on code-diff artifacts, bypassing both classifier and budget cap per D-05/D-06
- Display-name map expanded to 14 entries covering all personas (4 core + 9 bench + JE)
- Full validation passes: 4 core, 10 bench (including JE), 1 chair, 1 classifier = 16 sidecar files

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend dc-budget-plan.sh with always_invoke_on reading** - `a6b29b2` (feat)
2. **Task 2: Expand bench whitelist and display-name map in review.md** - `629ee92` (feat)
3. **Task 3: Full validation + core cardinality assertion** - no commit (verification-only, no files changed)

## Files Created/Modified
- `bin/dc-budget-plan.sh` - Added always_invoke_on sidecar scanning block, ALWAYS_INVOKE_JSON tracking, budget.always_invoked MANIFEST field, and spawn list append outside budget cap
- `commands/review.md` - Bench enumeration expanded from 4 to 9, display-name map from 8 to 14, bench fan-out comment updated, JE always_invoke_on bypass documented

## Decisions Made
- always_invoke_on reading lives in dc-budget-plan.sh (scans persona-metadata/*.yml via yq), not in the conductor — keeps all budget/spawn logic in one script
- JE is appended to SPAWN_CSV after budget cap computation, ensuring it never counts against MAX_SPAWNABLE
- The 4-entry PRIORITY_ORDER_JSON fallback in dc-budget-plan.sh is preserved for backward compatibility (primary 9-entry source is config.json)

## Deviations from Plan

### Auto-fixed Issues

**1. [Plan Inaccuracy] Task 3 bench count assertion**
- **Found during:** Task 3 (verification)
- **Issue:** Plan acceptance criteria stated `grep -c '^tier: bench$' persona-metadata/*.yml` should output exactly `9`, but actual count is `10` because Junior Engineer has `tier: bench` in its sidecar
- **Fix:** No code fix needed — the plan's assertion was slightly wrong. The 9-entry bench whitelist in review.md counts signal-triggered personas only; JE is bench-tier but uses `always_invoke_on` instead of signals. Actual bench sidecar count is correctly 10.
- **Verification:** `grep -rl '^tier: bench$' persona-metadata/*.yml | wc -l` returns 10; all 10 bench personas pass validation

---

**Total deviations:** 1 plan inaccuracy noted (no code impact)
**Impact on plan:** None — the conductor whitelist correctly has 9 signal-triggered entries, and JE is correctly bench-tier with always_invoke_on bypass.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All conductor surfaces wired for 9 signal-triggered bench personas + JE always_invoke_on bypass
- Ready for Wave 3 (plan 04-08): adversarial fixtures, voice-distinctness validator, blinded-reader evaluation, 10-persona Chair synthesis fixture
- validate-personas.sh passes across all 16 sidecar files (4 core + 10 bench + 1 chair + 1 classifier)

---
## Self-Check: PASSED

- bin/dc-budget-plan.sh: FOUND
- commands/review.md: FOUND
- 04-07-SUMMARY.md: FOUND
- Commit a6b29b2 (Task 1): FOUND
- Commit 629ee92 (Task 2): FOUND

---
*Phase: 04-six-personas-atomic-conductor-wiring*
*Completed: 2026-04-28*
