---
phase: 04-six-personas-atomic-conductor-wiring
plan: 05
subsystem: persona-authoring
tags: [bench-persona, competing-team-lead, shared-infra, consumer-naming]
dependency_graph:
  requires: [lib/signals.json (shared_infra_change signal)]
  provides: [agents/competing-team-lead.md, persona-metadata/competing-team-lead.yml]
  affects: [commands/review.md (Wave 2 conductor wiring), bin/dc-budget-plan.sh]
tech_stack:
  added: []
  patterns: [sidecar-template, agent-template, consumer-naming-voice]
key_files:
  created:
    - agents/competing-team-lead.md
    - persona-metadata/competing-team-lead.yml
  modified: []
decisions:
  - "Consumer-naming is structurally enforced: every characteristic_objection in the sidecar names a specific service, team, or schema. The banned-phrase list blocks the vague-coordination register (downstream impact, breaking change, coordinate with teams, etc.) that would let findings avoid naming a victim."
  - "Voice differentiation from Staff Engineer: CTL asks 'which team depends on this contract?' (consumer-facing, shared-infra-scoped) vs Staff Eng asks 'what can we delete?' (author-facing, YAGNI-forward). Zero overlap in banned phrases beyond baseline three."
  - "Voice differentiation from Devil's Advocate: CTL names specific consumers affected by contract changes vs DA names unquestioned premises. CTL is scoped to shared infrastructure; DA is artifact-scope-agnostic."
metrics:
  duration_seconds: 168
  completed: "2026-04-28T19:06:24Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 0
---

# Phase 04 Plan 05: Competing Team Lead Persona Summary

Consumer-naming bench persona for shared-infrastructure changes -- every finding names a specific team, repo, service, or endpoint affected by a contract change. Triggered by `shared_infra_change` signal.

## Task Results

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create Competing Team Lead sidecar | 2d82e0c | persona-metadata/competing-team-lead.yml |
| 2 | Create Competing Team Lead agent file | 56aebcf | agents/competing-team-lead.md |

## Verification Results

- `./scripts/validate-personas.sh agents/competing-team-lead.md` exits 0 (no hard failures, no warnings)
- `./scripts/validate-personas.sh` (full run) exits 0 with no regressions (all warnings are pre-existing on other personas)
- `yq '.tier' persona-metadata/competing-team-lead.yml` = `bench`
- `yq '.triggers[0]' persona-metadata/competing-team-lead.yml` = `shared_infra_change`
- `yq '.characteristic_objections | length'` = 4 (all name specific consumers)
- `yq '.banned_phrases | length'` = 9 (3 baseline + 6 vague-coordination-register)
- Agent file: 142 lines (within 130-170 target), `## Examples` section present, 46 consumer/service/team/endpoint/contract references

## Voice Differentiation

| Overlap Pair | CTL Voice | Other Voice | Separation Mechanism |
|---|---|---|---|
| CTL vs Staff Engineer | "Which team depends on this contract?" (consumer-facing) | "What can we delete?" (author-facing) | CTL names downstream consumers; Staff Eng names author's unnecessary code. Zero role-specific banned-phrase overlap. |
| CTL vs Devil's Advocate | Names specific consumers affected by contract changes | Names unquestioned premises in the artifact | CTL is shared-infra-scoped; DA is artifact-scope-agnostic. CTL bans coordination-register; DA bans agreement-register. |

## Deviations from Plan

None -- plan executed exactly as written.

## Known Stubs

None -- both files are complete with all required fields, worked examples, and banned-phrase discipline sections.

## Self-Check: PASSED

- FOUND: agents/competing-team-lead.md
- FOUND: persona-metadata/competing-team-lead.yml
- FOUND: .planning/phases/04-six-personas-atomic-conductor-wiring/04-05-SUMMARY.md
- FOUND: commit 2d82e0c (Task 1)
- FOUND: commit 56aebcf (Task 2)
