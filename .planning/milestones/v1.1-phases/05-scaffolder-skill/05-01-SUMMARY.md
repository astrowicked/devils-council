---
phase: 05-scaffolder-skill
plan: 01
subsystem: scaffolder
tags: [skill, wizard, persona-authoring, validation, voice-coaching]
dependency_graph:
  requires:
    - scripts/validate-personas.sh
    - lib/signals.json
    - persona-metadata/*.yml
    - skills/persona-voice/PERSONA-SCHEMA.md
  provides:
    - skills/create-persona/SKILL.md
    - scripts/test-persona-scaffolder.sh
    - tests/fixtures/scaffolder/*
  affects:
    - agents/AUTHORING.md (automated equivalent)
tech_stack:
  added: []
  patterns:
    - "SKILL.md interactive wizard via AskUserQuestion"
    - "Bash tool for shell ops (no shell-inject in scaffolder)"
    - "python3 set-intersection for overlap detection"
    - "Legacy all-in-one frontmatter for workspace validation"
key_files:
  created:
    - skills/create-persona/SKILL.md
    - scripts/test-persona-scaffolder.sh
    - scripts/test-scaffolder-skill.sh
    - tests/fixtures/scaffolder/valid-persona.md
    - tests/fixtures/scaffolder/weak-persona.md
    - tests/fixtures/scaffolder/overlap-persona.md
  modified: []
decisions:
  - "Used python3 -c with sys.argv for overlap computation in test harness (heredoc stdin incompatible with positional args)"
  - "Overlap fixture uses 66% overlap with staff-engineer (2 of 3 role-specific phrases) -- well above 30% threshold"
  - "Valid fixture uses fictional cost-hawk persona (fixture-scaffolder-valid) to avoid collision with shipped personas"
  - "SKILL.md avoids shell-inject pattern entirely -- explanatory text rephrased to avoid false-positive in test"
metrics:
  duration: 7m
  completed: "2026-04-28T21:09:32Z"
  tasks: 2
  files_created: 6
  files_modified: 0
  test_pass_rate: "100% (16/16 structure tests + 20/20 harness tests)"
---

# Phase 05 Plan 01: Persona Scaffolder Skill + Test Harness Summary

Interactive wizard SKILL.md (475 lines) implementing all 9 CONTEXT decisions (D-01 through D-09) with inline voice coaching, overlap detection, and validate-personas.sh integration; test harness validating pass/reject/overlap output quality across 3 fixture files.

## What Was Built

### skills/create-persona/SKILL.md (475 lines)

A 12-step interactive wizard invoked via `/devils-council:create-persona [slug]` that guides users through persona creation:

- **Step 0:** Slug validation (kebab-case, no path traversal) + workspace overwrite check (D-07)
- **Step 1/1b:** Tier selection (core/bench) + signal trigger selection for bench (D-01, D-03)
- **Step 2:** Primary concern collection with existing-persona negative examples (D-01, D-03)
- **Step 3:** Blind spots collection
- **Step 4:** Characteristic objections (>= 3 minimum enforcement) with deferred D-05 cross-check
- **Step 5:** Banned phrases (>= 5 minimum, stricter than validator R6) with:
  - Overlap coaching: python3 set-intersection against all 16 shipped persona sidecars, >30% threshold warning (D-04)
  - Cross-check: objections containing own banned phrases flagged for rephrase-or-keep (D-05)
- **Step 6:** Worked examples (2 good + 1 bad minimum enforcement) (D-01)
- **Step 7:** Full file preview before write (D-02)
- **Step 8:** Write to `CLAUDE_PLUGIN_DATA/create-persona-workspace/<slug>/` (D-06, D-07)
- **Step 9:** Validator invocation with R-code-to-step mapping + 3-retry bail (D-08, D-09)
- **Step 10:** Split all-in-one into agent + sidecar post-validation
- **Step 11:** Print ready-to-run cp commands (D-06)

All shell operations use Bash tool explicitly. No shell-inject patterns anywhere in the skill.

### scripts/test-persona-scaffolder.sh (3 test groups)

Test harness validating scaffolder output quality (not interactive flow):

- **Group 1 (Pass):** valid-persona.md passes validate-personas.sh, has >= 3 objections, >= 5 banned phrases
- **Group 2 (Reject):** weak-persona.md fails validator with R5 (< 3 objections), has < 5 banned phrases
- **Group 3 (Overlap):** overlap-persona.md has 66% banned-phrase overlap with staff-engineer

### Fixture Files

| Fixture | Slug | Purpose | Key Property |
|---------|------|---------|--------------|
| valid-persona.md | fixture-scaffolder-valid | Pass case | bench tier, cost-hawk, all fields complete |
| weak-persona.md | fixture-scaffolder-weak | Reject case | 1 objection (R5 fail), 2 banned phrases |
| overlap-persona.md | fixture-scaffolder-overlap | Overlap case | 66% overlap with staff-engineer |

### scripts/test-scaffolder-skill.sh (structure tests)

16 tests verifying SKILL.md structure: frontmatter fields, wizard step markers, overlap coaching, minimum enforcement rules, D-02/D-05/D-06/D-07/D-08/D-09 sections, no shell-inject, >= 150 lines.

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| 1a5bbf4 | test | Failing structure tests for SKILL.md (TDD RED) |
| f8ea5a9 | feat | Create-persona interactive wizard SKILL.md (TDD GREEN) |
| 02e3195 | feat | Test harness + 3 fixture files |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Shell-inject pattern in explanatory text**
- **Found during:** Task 1 GREEN phase
- **Issue:** SKILL.md "Important Notes" section contained literal `` `!`backtick`` `` pattern in explanatory text about what NOT to do, triggering the no-shell-inject test
- **Fix:** Rephrased to "exclamation-backtick shell-injection pattern" (no code-formatted pattern)
- **Files modified:** skills/create-persona/SKILL.md
- **Commit:** f8ea5a9

**2. [Rule 1 - Bug] Python heredoc incompatible with sys.argv in test harness**
- **Found during:** Task 2 implementation
- **Issue:** Overlap detection script used `python3 << 'HEREDOC'` with `sys.argv[1]` references, but heredoc stdin doesn't pass positional args
- **Fix:** Switched to `python3 -c "..." "$OVERLAP" "$STAFF_META"` pattern matching other test harness sections
- **Files modified:** scripts/test-persona-scaffolder.sh
- **Commit:** 02e3195

## Verification Results

| Check | Result |
|-------|--------|
| SKILL.md exists, >= 150 lines | PASS (475 lines) |
| Frontmatter: name, allowed-tools, user-invocable | PASS |
| All 12 wizard steps present | PASS |
| Overlap coaching >30% threshold | PASS |
| D-05 objection cross-check | PASS |
| Minimum enforcement rules | PASS |
| No shell-inject patterns | PASS |
| R-code mapping (D-08) | PASS |
| 3-retry bail (D-09) | PASS |
| Valid fixture passes validator | PASS (exit 0) |
| Weak fixture fails with R5 | PASS (exit 1) |
| Overlap fixture >30% | PASS (66%) |
| Test harness exits 0 | PASS |
| Structure test suite | PASS (16/16) |

## Self-Check: PASSED

All 7 created files verified on disk. All 3 commit hashes found in git log.
