---
phase: 04-six-personas-atomic-conductor-wiring
plan: "04"
subsystem: persona-authoring
tags: [executive-sponsor, bench-persona, quantification, banned-phrases, P-11-defense]
dependency_graph:
  requires:
    - lib/signals.json (exec_keyword signal ID)
    - persona-metadata/security-reviewer.yml (sidecar template pattern)
    - agents/security-reviewer.md (agent file template pattern)
  provides:
    - persona-metadata/executive-sponsor.yml (Executive Sponsor voice kit sidecar)
    - agents/executive-sponsor.md (Executive Sponsor bench persona subagent)
  affects:
    - commands/review.md (Wave 2 conductor wiring will reference this persona)
    - bin/dc-budget-plan.sh (Wave 2 will include in bench spawn list)
tech_stack:
  added: []
  patterns:
    - "findings: [] escape path with explanatory Summary for unquantifiable artifacts"
    - "18-phrase banned list (longest in plugin) targeting exec-speak register"
    - "Three-category ban grouping: strategy-deck, risk-theater, corporate filler"
key_files:
  created:
    - agents/executive-sponsor.md
    - persona-metadata/executive-sponsor.yml
  modified: []
decisions:
  - "18 banned phrases (3 baseline + 15 role-specific) grouped into strategy-deck, risk-theater, and corporate-filler categories"
  - "Three worked-example scenarios: budget gap finding, customer count gap finding, and findings: [] for unquantifiable artifacts"
  - "Severity determined by size of quantification gap, not abstract risk level"
metrics:
  duration: "3m 24s"
  completed: "2026-04-28"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 0
---

# Phase 04 Plan 04: Executive Sponsor Persona Summary

Executive Sponsor bench persona with 18-phrase banned list (longest in plugin) targeting exec-speak register, explicit findings: [] escape path for unquantifiable artifacts, and three worked-example scenarios teaching quantification-gap detection.

## What Was Done

### Task 1: Create Executive Sponsor sidecar (e290064)

Created `persona-metadata/executive-sponsor.yml` with:

- **Tier:** bench, triggered by `exec_keyword` signal ID from `lib/signals.json`
- **Primary concern:** "What specific number -- dollars, weeks, customers, or ticket ID -- justifies this decision?"
- **18 banned phrases** (longest in plugin; previous max was 9):
  - 3 baseline: consider, think about, be aware of
  - 5 strategy-deck: strategic alignment, unlock value, north star, strategic imperative, strategic considerations
  - 3 risk-theater: de-risk, risk factors, alignment concerns
  - 7 corporate filler: move the needle, leverage synergies, drive impact, key stakeholders, transformation journey, opportunity window, competitive landscape
- **4 characteristic objections** each demanding a specific number category (budget, timeline, customer count, ARR)
- **4 blind spots:** implementation_detail, code_style, test_structure, deployment_mechanics
- **Zero role-specific overlap** with product-manager.yml banned phrases (PM bans stakeholder-free abstractions; Exec Sponsor bans exec-speak register)

### Task 2: Create Executive Sponsor agent file (3836570)

Created `agents/executive-sponsor.md` (187 lines) with:

- **Voice paragraph:** quantification-demanding, not role-describing. Names the "findings: [] with explanatory Summary" escape path directly in the opening paragraph.
- **Three worked-example scenarios:**
  1. Missing budget estimate (blocker) -- names specific infrastructure costs and engineer-weeks
  2. Missing customer count (major) -- names specific account count from billing
  3. `findings: []` for artifact with only strategic-register language and zero quantifiable claims
- **What NOT to do:** Finding containing 6 banned phrases (strategic alignment, risk factors, competitive landscape, de-risk, leverage synergies, unlock value) with no specific number
- **Extensive banned-phrase discipline section** explaining why each of the 15 role-specific bans exists, grouped by category
- **Passes validate-personas.sh** with zero hard failures; full validator run shows no regressions

## Deviations from Plan

None -- plan executed exactly as written.

## Verification Results

| Check | Result |
|-------|--------|
| `validate-personas.sh agents/executive-sponsor.md` | exit 0 |
| `validate-personas.sh` (full run) | exit 0, no new warnings |
| `yq '.banned_phrases \| length' persona-metadata/executive-sponsor.yml` | 18 (longest in plugin) |
| `yq '.characteristic_objections \| length' persona-metadata/executive-sponsor.yml` | 4 |
| `grep -c 'findings: \[\]' agents/executive-sponsor.md` | 8 (escape path taught) |
| `wc -l < agents/executive-sponsor.md` | 187 (within 140-200 range) |
| PM banned-phrase overlap | 0 role-specific overlaps |

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | e290064 | feat(04-04): create Executive Sponsor sidecar with 18-phrase banned list |
| 2 | 3836570 | feat(04-04): create Executive Sponsor agent file with findings: [] escape path |

## Self-Check: PASSED

All files verified on disk. All commits verified in git log.
