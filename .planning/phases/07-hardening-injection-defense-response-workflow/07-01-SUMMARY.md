---
phase: 07-hardening-injection-defense-response-workflow
plan: 01
subsystem: planning
tags: [doc-amendments, requirements, roadmap, traceability]

# Dependency graph
requires:
  - phase: 06-classifier-bench-personas-cost-instrumentation
    provides: BNCH-09 (hard budget cap) and BNCH-10 (observable prompt-cache reduction) shipped; their existence makes HARD-03/HARD-04 duplicates
  - phase: 01-plugin-scaffolding-codex-setup
    provides: D-07 path reconciliation to `.council/responses.md` (RESP-01 already reconciled in REQUIREMENTS.md; this plan brings ROADMAP.md into agreement)
provides:
  - Canonical post-amendment Phase 7 requirement set {HARD-01, HARD-02, HARD-05, RESP-01, RESP-03, RESP-04}
  - RESP-02 traceability moved to Phase 8 (matches Phase 8 success criterion #3 wording)
  - ROADMAP Phase 7 success criterion #3 path `.council/responses.md` aligned with REQUIREMENTS.md RESP-01
  - ROADMAP Phase 7 success criterion #6 rephrased to fold over-budget fixture coverage into HARD-01 `tool-hijack/` class (no new capability; clarity only)
  - Arithmetically consistent coverage counts: REQUIREMENTS.md v1=65; ROADMAP Coverage Total=61
affects: [07-02, 07-03, 07-04, 07-05, 07-06, 07-07, 07-08, 08-gsd-hook-integration-dig-in-docs-release]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Artifact-hygiene amendments shipped as an isolated doc-only plan for trivial revertability (RESEARCH.md §8 pattern)"
    - "grep-based acceptance criteria on exact regex patterns make verifier assertions mechanical and scriptable"

key-files:
  created:
    - .planning/ROADMAP.md (newly git-tracked in this worktree; previously untracked in main)
  modified:
    - .planning/REQUIREMENTS.md

key-decisions:
  - "D-62 applied: HARD-03 and HARD-04 deleted from REQUIREMENTS.md (duplicates of BNCH-10/BNCH-09 shipped in Phase 6)"
  - "D-63 applied: RESP-02 traceability moved REQUIREMENTS.md Phase 7 → Phase 8 row; ROADMAP Phase 8 coverage row gains RESP-02"
  - "D-64 applied: ROADMAP Phase 7 success criterion #3 path `.devils-council/responses.md` → `.council/responses.md`"
  - "Phase 7 success criterion #6 rephrased to fold over-budget adversarial fixture into HARD-01 `tool-hijack/` class (no regression of BNCH-09)"
  - "Coverage Note paragraph extended with an inline amendment footnote rather than rewritten — preserves the existing arithmetic audit trail while noting the 63 → 61 post-amendment total"

patterns-established:
  - "Doc-only amendment plan pattern: isolated from feature plans, atomic single-commit per file, grep-based acceptance gates"
  - "Cross-file invariant: REQUIREMENTS.md traceability rows + ROADMAP.md `**Requirements**:` line per phase + ROADMAP.md Coverage table row must agree on requirement IDs and count"

requirements-completed: [doc-amendments]

# Metrics
duration: ~6min
completed: 2026-04-23
---

# Phase 7 Plan 01: REQUIREMENTS.md + ROADMAP.md Amendments Summary

**Deletes HARD-03/HARD-04 duplicates, moves RESP-02 traceability Phase 7 → Phase 8, and reconciles ROADMAP Phase 7 prose (`.council/responses.md` path + success criterion #6 rephrase) — producing a canonical 6-requirement Phase 7 set of {HARD-01, HARD-02, HARD-05, RESP-01, RESP-03, RESP-04}**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-04-23T23:05:00Z (approximate — branch rebase + context read)
- **Completed:** 2026-04-23T23:11:22Z (Task 2 commit)
- **Tasks:** 2
- **Files modified:** 2 (REQUIREMENTS.md edited in place; ROADMAP.md newly git-tracked in this worktree)

## Accomplishments

- HARD-03 and HARD-04 entries removed from REQUIREMENTS.md Hardening section (duplicates of BNCH-10/BNCH-09 now owned by Phase 6)
- REQUIREMENTS.md traceability table updated: Phase 7 HARD row narrowed to `HARD-01, HARD-02, HARD-05`; Phase 7 RESP row narrowed to `RESP-01, RESP-03, RESP-04`; new row `RESP-02 | Phase 8 | Pending` added
- REQUIREMENTS.md coverage recount: `v1 requirements: 67 total` / `Mapped to phases: 67` → `65 total` / `65`
- REQUIREMENTS.md footer appended with a dated 2026-04-23 Phase 7 amendment note citing D-62/D-63/D-64
- ROADMAP.md Phase 7 `**Requirements**:` line reduced from 9 IDs to the 6 canonical IDs
- ROADMAP.md Phase 7 success criterion #3 path `.devils-council/responses.md` → `.council/responses.md` (matches Phase 1 D-07 + REQUIREMENTS.md RESP-01)
- ROADMAP.md Phase 7 success criterion #6 rephrased to reference HARD-01 `tool-hijack/` adversarial fixture + BNCH-09 no-regression assertion
- ROADMAP.md Coverage table: Phase 7 row (count 9 → 6), Phase 8 row gains RESP-02 (count 10 → 11), Total (63 → 61); Coverage Note paragraph extended with the amendment reconciliation footnote

## Task Commits

Each task was committed atomically:

1. **Task 1: Amend REQUIREMENTS.md** — `45b9bbc` (docs)
2. **Task 2: Amend ROADMAP.md** — `763880a` (docs)

## Files Created/Modified

- `.planning/REQUIREMENTS.md` — HARD-03/HARD-04 lines deleted (L79–L80 region), traceability table L159–L160 split + new RESP-02 Phase 8 row, coverage counts L165–L166 (67 → 65), amendment note appended at L172
- `.planning/ROADMAP.md` — Phase 7 Requirements line L127 (9 IDs → 6 IDs); Phase 7 success criterion #3 L131 (path reconcile); Phase 7 success criterion #6 L134 (rephrase); Coverage table rows L183–L184 (Phase 7 count 9 → 6; Phase 8 gains RESP-02, count 10 → 11); Total L185 (63 → 61); Coverage Note L187 (appended amendment footnote). File was untracked in git prior to this plan — now tracked in the worktree branch via `git add -f`

## Verification Log

Every acceptance criterion in the plan was asserted via grep and passed:

### Task 1 (REQUIREMENTS.md)

| Assertion | Expected | Observed |
|-----------|----------|----------|
| `^- \[ \] \*\*HARD-03\*\*` | 0 | 0 ✓ |
| `^- \[ \] \*\*HARD-04\*\*` | 0 | 0 ✓ |
| `\*\*HARD-01\*\*` | 1 | 1 ✓ |
| `\*\*HARD-02\*\*` | 1 | 1 ✓ |
| `\*\*HARD-05\*\*` | 1 | 1 ✓ |
| `^\| RESP-02 \| Phase 8 \| Pending \|$` | 1 | 1 ✓ |
| `^\| HARD-01, HARD-02, HARD-05 \| Phase 7 \| Pending \|$` | 1 | 1 ✓ |
| `^\| RESP-01, RESP-03, RESP-04 \| Phase 7 \| Pending \|$` | 1 | 1 ✓ |
| `^- v1 requirements: 65 total$` | 1 | 1 ✓ |
| `^- Mapped to phases: 65$` | 1 | 1 ✓ |
| `Phase 7 amendments:.*HARD-03/HARD-04 deleted` | 1 | 1 ✓ |

### Task 2 (ROADMAP.md)

| Assertion | Expected | Observed |
|-----------|----------|----------|
| `\.devils-council/responses\.md` | 0 | 0 ✓ |
| `\.council/responses\.md` | ≥ 1 | 1 ✓ |
| `\*\*Requirements\*\*: HARD-01, HARD-02, HARD-05, RESP-01, RESP-03, RESP-04` | 1 | 1 ✓ |
| `HARD-01, HARD-02, HARD-03, HARD-04` | 0 | 0 ✓ |
| `^\| 7 \| HARD-01, HARD-02, HARD-05, RESP-01, RESP-03, RESP-04 \| 6 \|$` | 1 | 1 ✓ |
| `^\| 8 \| GSDI-01\.\.04, DOCS-01\.\.06, RESP-02 \| 11 \|$` | 1 | 1 ✓ |
| `tool-hijack/.*adversarial fixture` | 1 | 1 ✓ |
| `Phase 7 D-62/D-63/D-64 amendments` | 1 | 1 ✓ |

### Cross-file invariant (verification block)

| Assertion | Expected | Observed |
|-----------|----------|----------|
| `grep -l '\.devils-council/responses\.md' .planning/REQUIREMENTS.md .planning/ROADMAP.md` | 0 | 0 ✓ |

All 20 grep assertions pass.

## Byte/Line Footprint

- **REQUIREMENTS.md:** `1 file changed, 6 insertions(+), 6 deletions(-)` per `git show 45b9bbc --stat` — two requirement bullets deleted, two traceability rows split into three, coverage counts updated, amendment footer appended
- **ROADMAP.md:** Semantic diff (main working tree vs this worktree's committed copy) is 5 substantive replacements spanning lines 127, 131, 134, 183–185, 187 — the git-level `+190` insertion count reflects that ROADMAP.md was untracked in git prior to this commit

## Decisions Made

- None beyond the plan — followed the locked D-62/D-63/D-64 decisions verbatim.
- Coverage Note paragraph in ROADMAP.md: chose to APPEND an amendment footnote to the existing Note rather than rewrite the audit arithmetic. Rationale: preserves the prior 63-count reasoning for historical audit and keeps the diff minimal; the new `Post-amendment total: 61.` statement is the authoritative count going forward.
- ROADMAP.md top-of-file `**Coverage:** 65/65 v1 requirements mapped ✓` (line 6) — left unchanged per plan instructions (not enumerated in Task 2 edits; the plan explicitly scoped edits to Phase 7 Requirements line, success criteria #3 and #6, Coverage table rows, Total, and Note paragraph). This line is pre-existing drift between the top-of-file headline and the Coverage table Total (63/61/65 all appear in different places); the plan accepted this and did not ask me to reconcile it. A future cleanup plan may unify the top-of-file headline with the Coverage table Total.

## Deviations from Plan

None - plan executed exactly as written.

All five edit directives in Task 2 and five edit directives in Task 1 were applied verbatim. Every grep assertion in the plan's `<acceptance_criteria>` and `<verify>` blocks passed on the first attempt.

## Issues Encountered

- **ROADMAP.md not present in the worktree.** The `.planning/ROADMAP.md` file is listed in `.gitignore` (`.planning/`) and had never been added via `git add -f`, so the worktree created from the main repo had no copy. Resolved by copying `/Users/andywoodard/dev/devils-council/.planning/ROADMAP.md` into the worktree's `.planning/` directory before editing, then committing via `git add -f`. REQUIREMENTS.md was already tracked (grandfathered-in before `.planning/` was added to .gitignore) so no such copy was needed.
- **`git add` without `-f` refused both files** because `.planning/` is in .gitignore. Resolved with `git add -f`. The orchestrator's `--no-verify` instruction was honored on both commits.
- **Pre-existing worktree base drift.** The worktree branch HEAD was at `557e4d4` (main's HEAD prior to the Phase 6 CI-wiring commit) rather than the target `424bb61`. Verified `557e4d4` was an ancestor of `424bb61` (fast-forward safe) and `git reset --hard 424bb61`. No work lost.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 7 REQ-ID scope is now canonical. Plans 07-02 through 07-08 can reference the 6-requirement set without ambiguity.
- Downstream `gsd-verifier` / `gsd-plan-checker` / `gsd-code-reviewer` invocations will find matching REQ IDs between plan frontmatter `requirements:` fields and the REQUIREMENTS.md traceability table.
- RESP-02 is now flagged for Phase 8 in both files; the `/devils-council:dig` command implementation lands with the other `commands/*.md` additions there.
- No blockers for Plan 07-02 (HARD-02 zero-kept stub-drop branch). That plan can proceed immediately.

## Self-Check: PASSED

- `.planning/REQUIREMENTS.md`: FOUND (in worktree, committed in `45b9bbc`)
- `.planning/ROADMAP.md`: FOUND (in worktree, committed in `763880a`)
- Commit `45b9bbc`: FOUND (`git log --oneline --all | grep 45b9bbc`)
- Commit `763880a`: FOUND (`git log --oneline --all | grep 763880a`)
- All 20 grep assertions from Task 1 + Task 2 + verification block pass (see Verification Log above)

---
*Phase: 07-hardening-injection-defense-response-workflow*
*Completed: 2026-04-23*
