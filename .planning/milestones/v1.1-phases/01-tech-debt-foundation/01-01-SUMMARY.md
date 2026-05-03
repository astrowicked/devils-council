---
phase: 01-tech-debt-foundation
plan: 01
subsystem: docs
tags: [tech-debt, retroactive-flip, troubleshooting, batch-1]
requirements: [TD-01, TD-02, TD-03, TD-07]
dependency_graph:
  requires: []
  provides: ["v1.0 audit closure for TD-01/02/03/07", "README troubleshooting for marketplace-update refresh"]
  affects: ["future milestone audits (clean retroactive evidence trail)", "user-facing upgrade UX (v1.1 release)"]
tech_stack:
  added: []
  patterns: ["retroactive-evidence citation (D-11/D-12)", "batch-1 single-commit atomicity (D-15)"]
key_files:
  created: []
  modified:
    - path: README.md
      tracked: true
      change: "Added Troubleshooting #2 (Install picks up old version after tag bump); renumbered #3-#9; updated cross-ref anchor to #4"
    - path: CHANGELOG.md
      tracked: true
      change: "Added v1.1 [Unreleased] ### Added bullet documenting TD-07 /plugin marketplace update refresh step"
    - path: .planning/milestones/v1.0-phases/01-plugin-scaffolding-codex-setup/01-VERIFICATION.md
      tracked: false
      change: "Frontmatter status human_needed -> passed; score 4/5 -> 5/5 (retroactive); added retroactive_closed + retroactive_closed_in; appended Retroactive Evidence H2 citing 08-UAT.md DOCS-06 sign-off + v1.0.x release chain; extended Gaps Summary."
    - path: .planning/milestones/v1.0-phases/04-remaining-core-personas/04-VERIFICATION.md
      tracked: false
      change: "Frontmatter status human_needed -> passed; score string rewritten; added retroactive_closed + retroactive_closed_in; appended Retroactive Evidence H2 citing Phase 5 structural dependency (SC-1), v1.1 Phase 7 PQUAL-03 supersession (SC-2), Phase 5+ parallel-isolation reaffirmation (SC-3)."
    - path: .planning/milestones/v1.0-phases/04-remaining-core-personas/04-HUMAN-UAT.md
      tracked: false
      change: "Frontmatter status partial -> resolved-by-downstream; updated timestamp 2026-04-25; added retroactive_closed + retroactive_closed_in; rewrote Current Test body; flipped all 3 result: pending -> result: resolved-by-downstream; Summary resolved: 3 / pending: 0."
    - path: .planning/milestones/v1.0-phases/05-council-chair-synthesis/05-VALIDATION.md
      tracked: false
      change: "Frontmatter status draft -> passed; nyquist_compliant false -> true; wave_0_complete false -> true; added retroactive_closed + retroactive_closed_in + approval: passed (retroactive); flipped all 6 Per-Task Verification Map Status cells ⬜ pending -> ✅ green; flipped File Exists column from ❌ W0 / ⚠ Extend Case D to ✅ W0 closed; appended Retroactive Validation H2 enumerating CI green + CHAIR-01..06 structural satisfaction."
decisions:
  - "D-11 liberal citation for TD-01 + TD-02 (release-chain evidence + downstream supersession); conservative citation for TD-03 (structural evidence enumerated)"
  - "D-12 both-locations citation (retroactive-evidence blocks in each archived file AND summary here)"
  - "D-13 TD-07 wording inserted verbatim per plan specification"
  - "D-15 single-commit Batch 1 with exact subject docs(01-batch-1): close TD-01/02/03/07 tracking debt"
  - "TD-03 fallback: /gsd-validate-phase 5 not runnable from executor (slash commands require interactive Claude Code session); used manual-flip path per plan fallback"
metrics:
  duration: "~15 minutes"
  tasks: 5
  files_changed_tracked: 2
  files_changed_local_only: 4
  completed: 2026-04-25
---

# Phase 1 Plan 01: Tech-Debt Batch 1 Summary

One-liner: Closed four v1.0-audit tech-debt items (TD-01/02/03/07) in a single atomic doc-only commit with retroactive-evidence citations for every flip and a new README troubleshooting entry covering the `/plugin marketplace update` upgrade step.

## Result

All 4 doc-only TD items from the v1.0 milestone audit are discharged. Batch 1 shipped as exactly one commit per D-15. Zero code changes; zero test changes; zero CI runs required. README Troubleshooting numbering is contiguous 1-9. CHANGELOG [Unreleased] carries the TD-07 user-visible entry.

## TD-Item Closeouts

### TD-01 — Phase 1 v1.0 VERIFICATION.md `human_needed -> passed`

**File flipped (local-only):** `.planning/milestones/v1.0-phases/01-plugin-scaffolding-codex-setup/01-VERIFICATION.md`

**Retroactive-evidence citation (verbatim from the flipped file):**

> PLUG-01 (marketplace install end-to-end) is proven by the v1.0.x release chain. Every `/plugin install devils-council@devils-council` executed since v1.0.0 shipped (2026-04-24) is a live production test of the install flow; three tagged releases (v1.0.0, v1.0.1, v1.0.2) have been installed and uninstalled successfully on Andy's machine and at least one remote reviewer's machine.
>
> Authoritative live-install record: `.planning/milestones/v1.0-phases/08-gsd-hook-integration-dig-in-docs-release/08-UAT.md` — DOCS-06 UAT sign-off on 2026-04-24 records a live install + uninstall + reinstall cycle on a real artifact.

**D-11 disposition:** liberal (release telemetry IS the live test).

### TD-02 — Phase 4 v1.0 VERIFICATION.md + 04-HUMAN-UAT.md

**Files flipped (local-only):**

- `.planning/milestones/v1.0-phases/04-remaining-core-personas/04-VERIFICATION.md` (`human_needed -> passed`)
- `.planning/milestones/v1.0-phases/04-remaining-core-personas/04-HUMAN-UAT.md` (`partial -> resolved-by-downstream`; all 3 `result:` fields → `resolved-by-downstream`; Summary `resolved: 3 / pending: 0`)

**Retroactive-evidence citation (verbatim from 04-VERIFICATION.md):**

> 1. **SC-1 live 4-persona fan-out** — Phase 5 (council-chair-synthesis) is architecturally dependent on Phase 4's 4-persona output. Phase 5's green CI (`scripts/test-chair-synthesis.sh` 17/17 as of v1.0.2) cannot be achieved without Phase 4's fan-out working; the green is structural proof. Phase 8 `08-UAT.md` also records a live `/devils-council:review` run against `03-00-PLAN.md` producing 13 findings across 4 core personas with voice-differentiated output.
>
> 2. **SC-2 blinded-reader voice differentiation** — v1.1 Phase 7 PQUAL-03 (blinded-reader ≥80% persona attribution at 6+ personas) raises the threshold and supersedes Phase 4's 4/4-at-4-personas gate.
>
> 3. **SC-3 order-swap isolation** — parallel isolation is a property of the Claude Code subagent harness, not of devils-council. Phase 5 Chair synthesis + Phase 8 UAT both ran multi-persona fan-out without order-dependent output drift.

**D-11 disposition:** liberal (functional proof via dependency chain + Phase 7 supersession).

### TD-03 — Phase 5 v1.0 VALIDATION.md `nyquist_compliant: false -> true`

**File flipped (local-only):** `.planning/milestones/v1.0-phases/05-council-chair-synthesis/05-VALIDATION.md`

- Frontmatter: `status: draft -> passed`, `nyquist_compliant: false -> true`, `wave_0_complete: false -> true`, added `approval: passed (retroactive)`
- Per-Task Verification Map: all 6 rows (CHAIR-01..06) flipped `⬜ pending -> ✅ green` in Status column; File Exists column flipped `❌ W0 -> ✅ W0 closed` (CHAIR-01..05) and `⚠ Extend Case D + new test-chair-synthesis.sh -> ✅ W0 closed` (CHAIR-06)

**Retroactive-validation citation (verbatim from the flipped file):**

> - `scripts/test-chair-synthesis.sh` is green in CI (.github/workflows/ci.yml "Run Chair synthesis test" step) and has been since v1.0.0 shipped; last confirmed green on v1.0.2 (2026-04-24). Per phase planner's own test manifest: 17/17 test cases.
> - `.planning/milestones/v1.0-phases/05-council-chair-synthesis/05-VERIFICATION.md` structural verification recorded 5/5 roadmap success criteria + 6/6 CHAIR-xx requirements + 3/3 UAT items all green.
> - All six CHAIR-01..CHAIR-06 requirements in the Per-Task Verification Map of this file have been satisfied by shipped code — `scripts/test-chair-synthesis.sh` covers CHAIR-01/02/03/05/06 (integration + ID stability); `bin/dc-validate-synthesis.sh` covers CHAIR-04 (banned-token scan) and ships in v1.0.x.

**D-11 disposition:** conservative (actual structural evidence enumerated, not release-chain-by-inference).

**Deviation note:** The plan preferred `/gsd-validate-phase 5` as the primary close-out mechanism. That slash command requires an interactive Claude Code session and is not runnable from inside a non-interactive GSD executor agent. Per the plan's own fallback specification, the manual-flip path with citation was used instead — the rendered retroactive-validation section is substantively equivalent to what a `/gsd-validate-phase 5` artifact would have stamped.

### TD-07 — README `/plugin marketplace update` documentation

**Files edited (tracked, committed):**

- `README.md` — inserted new `### 2. Install picks up old version after tag bump` H3 directly after `### 1. Plugin cache staleness after version bump`; renumbered existing items 2-8 to 3-9; updated cross-reference anchor at line 250 from `[Troubleshooting #3]` to `[Troubleshooting #4]`.
- `CHANGELOG.md` — added `### Added` block under `## [Unreleased]` documenting the TD-07 troubleshooting entry.

**CHANGELOG entry (verbatim):**

> - **Troubleshooting: `/plugin marketplace update` refresh step** (TD-07) — README Troubleshooting section #2 now documents that after a new tag ships, users must run `/plugin marketplace update devils-council` before `/plugin install devils-council@devils-council` picks up the new version. Previously, uninstall+reinstall alone was insufficient when the marketplace descriptor was cached locally.

**D-13 disposition:** content matches plan specification verbatim.

## File Disposition (tracked vs local-only)

| File | Tracked | Committed? |
|------|---------|------------|
| `README.md` | yes | yes (Batch 1) |
| `CHANGELOG.md` | yes | yes (Batch 1) |
| `.planning/milestones/v1.0-phases/01-plugin-scaffolding-codex-setup/01-VERIFICATION.md` | no (`.planning/` gitignored) | no — local-only audit record |
| `.planning/milestones/v1.0-phases/04-remaining-core-personas/04-VERIFICATION.md` | no | no — local-only |
| `.planning/milestones/v1.0-phases/04-remaining-core-personas/04-HUMAN-UAT.md` | no | no — local-only |
| `.planning/milestones/v1.0-phases/05-council-chair-synthesis/05-VALIDATION.md` | no | no — local-only |

`commit_docs: false` honored per `.planning/config.json` — archived v1.0 phase artifacts are flipped on disk (source-of-truth for audit status) but not staged. D-12 citation discipline is satisfied by having the retroactive-evidence blocks embedded in each archived file AND cross-referenced here.

## Commit

**Hash:** `a180833`
**Full hash:** `a180833fda80fcdce71ff5ae018f0815635bf629`
**Subject:** `docs(01-batch-1): close TD-01/02/03/07 tracking debt`
**Files staged:** README.md, CHANGELOG.md (exactly 2)
**Co-Authored-By trailer:** zero occurrences (verified via `git log -1 --format=%B | grep -c Co-Authored-By` → 0)

Matches D-15 specification exactly.

## Overall Verification

All 10 overall success assertions from the plan passed:

1. `grep -q "^status: passed$" 01-VERIFICATION.md` — PASS (TD-01)
2. `grep -q "^status: passed$" 04-VERIFICATION.md` — PASS (TD-02)
3. `grep -q "^status: resolved-by-downstream$" 04-HUMAN-UAT.md` — PASS (TD-02)
4. `grep -q "^nyquist_compliant: true$" 05-VALIDATION.md` — PASS (TD-03)
5. `grep -qE "### [0-9]+\. Install picks up old version after tag bump" README.md` — PASS (TD-07)
6. `grep -q "/plugin marketplace update devils-council" README.md` — PASS (TD-07)
7. `grep -q "TD-07" CHANGELOG.md` — PASS (TD-07)
8. `git log -1 --format=%s` equals `docs(01-batch-1): close TD-01/02/03/07 tracking debt` — PASS (D-15)
9. `git log -1 --format=%B | grep -c "Co-Authored-By"` returns `0` — PASS (CLAUDE.md rule)
10. README Troubleshooting H3 numbering 1-9 with no gaps — PASS (renumber integrity)

## Deviations from Plan

### None that affect truths / artifacts / key_links

**Rule N/A — Procedural fallback documented in plan itself:** TD-03 used the plan's documented fallback (manual flip with citation) rather than `/gsd-validate-phase 5` because slash commands cannot be driven from a non-interactive executor. This is not a deviation from the plan — it is the plan's explicit fallback path per CONTEXT.md §TD-03 D-11.

**Cosmetic note on frontmatter key placement:** In `04-VERIFICATION.md`, the `retroactive_closed` + `retroactive_closed_in` keys landed immediately after `re_verification: null` (before the multi-line `human_verification:` array) rather than immediately before the closing `---`. This keeps scalar keys grouped together and is valid YAML. The plan specified "immediately before the closing `---`" — both positions satisfy the functional requirement ("in frontmatter") and the `grep` assertions pass identically.

## Deferred Issues

None — Batch 1 scope was fully completed in 5 tasks.

## Known Stubs

None introduced by this plan.

## Threat Flags

None — plan only flipped documentation/audit artifacts and added user-facing troubleshooting content. No new surface (endpoints, auth paths, file access, schema) introduced.

## Self-Check: PASSED

- All 6 listed files exist at their documented paths (verified via `ls`).
- Commit `a180833` exists in git log (`git log --oneline -1` → `a180833 docs(01-batch-1): close TD-01/02/03/07 tracking debt`).
- README + CHANGELOG are clean in `git status --short` (no `M` prefix on the two tracked files).
- Archived `.planning/milestones/**` flips persist on disk (grep assertions green); untracked by design per `.gitignore` and `commit_docs: false`.
