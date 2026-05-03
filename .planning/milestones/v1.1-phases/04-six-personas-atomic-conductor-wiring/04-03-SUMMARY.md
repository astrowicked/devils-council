---
phase: 04-six-personas-atomic-conductor-wiring
plan: 03
subsystem: personas
tags: [bench-persona, test-lead, test-quality, voice-kit]
dependency_graph:
  requires:
    - lib/signals.json (test_imbalance signal ID)
    - persona-metadata/security-reviewer.yml (template pattern)
    - agents/security-reviewer.md (template pattern)
  provides:
    - agents/test-lead.md (Test Lead bench persona)
    - persona-metadata/test-lead.yml (Test Lead voice kit sidecar)
  affects:
    - commands/review.md (bench whitelist — wired in Plan 07)
    - bin/dc-budget-plan.sh (spawn list — wired in Plan 07)
tech_stack:
  added: []
  patterns:
    - bench persona sidecar pattern (persona-metadata/*.yml)
    - circular-test-hunting voice discipline
key_files:
  created:
    - agents/test-lead.md
    - persona-metadata/test-lead.yml
  modified: []
decisions:
  - "Followed security-reviewer.md template exactly for agent structure"
  - "9 banned phrases covers both baseline (consider/think about/be aware of) and test-register (add tests/coverage/write unit tests/testing strategy)"
  - "4 characteristic objections target the four most common test-quality anti-patterns: circular mocks, execution-order coupling, src-test imbalance, and brittle snapshot assertions"
metrics:
  duration: "2m 43s"
  completed: "2026-04-28T19:06:19Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 0
---

# Phase 04 Plan 03: Test Lead Bench Persona Summary

Test Lead bench persona with circular-test-hunting voice, triggering on test_imbalance signal, banned from coverage-percentage findings and "add tests" verbs.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create Test Lead sidecar | 43593b3 | persona-metadata/test-lead.yml |
| 2 | Create Test Lead agent file | c21fb33 | agents/test-lead.md |

## What Was Built

### persona-metadata/test-lead.yml (sidecar)

- tier: bench
- triggers: [test_imbalance] (references existing signal ID in lib/signals.json)
- primary_concern: ends with `?` per schema convention
- 4 characteristic objections targeting: circular mock assertions, execution-order coupling, src-vs-test diff imbalance, brittle snapshot assertions
- 9 banned phrases: 3 baseline + 6 test-register-specific (add tests, increase coverage, test coverage, write unit tests, code coverage, testing strategy)
- tone_tags: [test-skeptical, circular-test-hunting, evidence-quoting]

### agents/test-lead.md (agent file)

- 144 lines (within 130-170 target range)
- Voice paragraph: describes diff-reading for mirror tests, land-mine tests, and coverage gaps without using banned register
- How you review section: evidence contract, severity guidance, banned-phrase discipline
- Output contract: scorecard-draft naming convention, frontmatter-only findings
- Worked examples: 2 good findings (circular-assertion blocker + src-test-imbalance major) + 1 bad finding (banned-phrase drop pattern)
- Banned-phrase discipline section: explains each of the 9 banned phrases

## Verification Results

- `validate-personas.sh agents/test-lead.md` exits 0 (no hard failures, no soft warnings)
- `validate-personas.sh` full run exits 0 with no regressions (only pre-existing W1/W2 warnings on other personas)
- R7 trigger validation passes: test_imbalance is a valid signal ID in lib/signals.json
- `## Examples` section present (W2 satisfied)
- All 3 baseline banned phrases present (W1 satisfied)

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None. Both files are complete and functional.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. Both files are read-only persona definitions consumed by the existing conductor pipeline.

## Self-Check: PASSED

- agents/test-lead.md: FOUND
- persona-metadata/test-lead.yml: FOUND
- 04-03-SUMMARY.md: FOUND
- Commit 43593b3: FOUND
- Commit c21fb33: FOUND
