---
phase: 05-council-chair-synthesis
plan: 05
subsystem: testing
tags: [bash, jq, python3, pyyaml, github-actions, integration-test, synthesis-validator]

# Dependency graph
requires:
  - phase: 05-council-chair-synthesis
    provides: stamped-id scorecard validator (05-01), Council Chair persona + metadata (05-02), bin/dc-validate-synthesis.sh (05-03), synthesis-first render wiring in commands/review.md (05-04)
  - phase: 03-engine-shell
    provides: bin/dc-prep.sh + bin/dc-validate-scorecard.sh + tests/fixtures/plan-sample.md + scripts/test-engine-smoke.sh (ADD-2 pattern template)
provides:
  - End-to-end CHAIR-01..06 integration test using prebuilt-run-dir technique (no live claude CLI)
  - tests/fixtures/contradiction-seed.md — PM-valuable vs SRE-operational-risk tension fixture
  - scripts/test-chair-synthesis.sh — 17-assertion regression guard covering all six CHAIR requirements
  - CI wiring on ubuntu-latest + macos-latest
affects: [phase-06-bench-personas, phase-07-response-integration, ci-regressions]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Prebuilt-run-dir test pattern: construct a run directory with synthetic HEREDOC drafts, call validator binaries directly, assert MANIFEST + file shape — no live Claude Code session dependency"
    - "CHAIR-06 two-layer protection: Plan 05-01 Case F (single-process canonicalization snapshot) + this plan's Case C (cross-run id-set equality on independent prep invocations)"
    - "Banned-token regression guard via single banned word in Tension prose (Case B APPROVE)"

key-files:
  created:
    - tests/fixtures/contradiction-seed.md
    - scripts/test-chair-synthesis.sh
    - .planning/phases/05-council-chair-synthesis/05-05-SUMMARY.md
  modified:
    - .github/workflows/ci.yml

key-decisions:
  - "Mirror scripts/test-engine-smoke.sh ADD-2 pattern — no headless `claude` invocation; all drafts synthesized inline from HEREDOCs and validators called directly"
  - "Case A uses a single blank-line-delimited entry in Contradictions that cites 2 ids to satisfy min_contradiction_anchors=2 cleanly"
  - "Case B reuses Case A's run dir (same stamped-id manifest) and rewrites only SYNTHESIS.md.draft so the banned-token path exercises the full validator on a realistic candidate-set"
  - "Case D uses fabricated 8-hex ids (product-manager-deadbeef, sre-dea dbee1) that match the regex but are not in stamped_ids — isolates contradiction_id_not_resolvable from other checks"
  - "Case E is grep-and-awk structural only — validates commands/review.md retains Spawn -> Validate -> Render order after Plan 05-04; live-render is out of scope for CI"

patterns-established:
  - "Prebuilt-run-dir E2E pattern: extend this template for any future Chair-involving test (e.g., bench persona integration in Phase 6)"
  - "Two-layer CHAIR-06 verification: snapshot test + cross-run integration test"

requirements-completed: [CHAIR-01, CHAIR-02, CHAIR-03, CHAIR-04, CHAIR-05, CHAIR-06]

# Metrics
duration: 6min
completed: 2026-04-23
---

# Phase 5 Plan 05: Chair Synthesis End-to-End Test Summary

**Prebuilt-run-dir E2E harness with 17 assertions covering CHAIR-01..06, plus CI wiring on ubuntu + macOS — zero live LLM calls, <5s runtime.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-04-23T03:26:02Z
- **Completed:** 2026-04-23T03:32:41Z
- **Tasks:** 3
- **Files modified:** 3 (2 created, 1 modified)

## Accomplishments

- **Fixture** engineered to produce cross-persona contradictions: PM anchors on Acme commitment + "ship it on by default", SRE anchors on in-memory state loss + 9am PT deploy blast-radius, Staff Eng anchors on one-caller middleware generality, Devil's Advocate anchors on the unexamined demo-simplicity-vs-rollback trade.
- **Test harness** with 17 assertions across 5 cases (A happy path, B banned-token, C id stability, D unresolvable id, E review.md wiring). Exits non-zero on any failure; log output clearly attributes which CHAIR requirement regressed.
- **CI wiring** in the same `validate` job as engine-smoke; matrix inherits ubuntu + macOS + jq + python3 + PyYAML already installed upstream.

## Task Commits

1. **Task 1: Author tests/fixtures/contradiction-seed.md** — `568d8fc` (feat)
2. **Task 2: Author scripts/test-chair-synthesis.sh end-to-end harness** — `0655d35` (feat)
3. **Task 3: Wire test-chair-synthesis.sh into .github/workflows/ci.yml** — `01122ab` (feat)

## Files Created/Modified

- `tests/fixtures/contradiction-seed.md` (45 lines) — Quota Limiter / Acme demo plan engineered to surface PM vs SRE tension on the same target (`## Proposal` "No feature flag" line).
- `scripts/test-chair-synthesis.sh` (419 lines, executable) — 5-case E2E harness.
- `.github/workflows/ci.yml` (+9 lines) — New "Run Chair synthesis test" step after the engine-smoke step.

## Test Outcomes (Local Run)

```
--- Case A: happy path ---
9 PASS lines (scorecards stamped, ids conform, validator exit 0, SYNTHESIS.md + MANIFEST shape, CHAIR-02/03/04 structural)
--- Case B: banned-token rejection ---
2 PASS lines (exit 1 + .invalid created, MANIFEST errors[] contains banned_token)
--- Case C: ID stability across re-runs (CHAIR-06) ---
1 PASS line (stamped ids byte-identical across two independent prep invocations)
--- Case D: unresolvable-id rejection ---
2 PASS lines (exit non-zero, MANIFEST records contradiction_id_not_resolvable)
--- Case E: CHAIR-05 structural ---
3 PASS lines (all three Phase 5 sections present, ordering Spawn -> Validate -> Render, dc-validate-synthesis.sh invoked)

CHAIR SYNTHESIS TEST: PASSED (cases A-E)
```

- `./scripts/test-engine-smoke.sh` → PASSED (all cases A-F, no regression)
- `./scripts/validate-personas.sh` → exit 0 (advisory warnings only, unchanged from baseline)
- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` → YAML valid

## Phase 5 Requirement Closure

| Req | Covered By | Where |
|-----|------------|-------|
| CHAIR-01 | Validator-driven SYNTHESIS.md write-after-all-personas-validated | Case A (SYNTHESIS.md created after 4-persona stamping; MANIFEST.synthesis.ran=true) |
| CHAIR-02 | Contradictions section with persona names + verbatim claim «quotes» + stamped-id citations; unresolvable ids rejected | Case A grep (structure) + Case D (reject fabricated ids) |
| CHAIR-03 | Top-3 section with id attribution + candidate-set membership | Case A grep (structure) + existing Plan 05-03 validator check (top3_off_candidate_set) |
| CHAIR-04 | Banned-token rejection with MANIFEST error capture | Case B (APPROVE triggers banned_token check) |
| CHAIR-05 | Raw scorecards rendered alongside synthesis — structural guarantee that commands/review.md preserves render wiring | Case E (three sections + ordering + validator invocation) |
| CHAIR-06 | Id stability across re-runs (cross-run equality, not just same-process reproduction) | Case C (two independent prep runs, same fixture → identical stamped id set) — complements Plan 05-01 Case F snapshot test |

## Decisions Made

None beyond those listed in frontmatter. Harness follows Plan 05-05 specification verbatim; zero mid-flight architectural changes.

## Deviations from Plan

None — plan executed exactly as written. All acceptance criteria, verification commands, and structural assertions match the plan text.

## Issues Encountered

None. Single clean pass on first run for all 17 assertions.

## User Setup Required

None — no external service configuration. CI runs automatically on push/PR via the existing GitHub Actions workflow.

## Handoff Note for Phase 7

`MANIFEST.synthesis.validation.errors[]` is now populated on every rejection (banned_token, contradiction_id_not_resolvable, top3_off_candidate_set, etc.) with `{check, detail}` shape. Phase 7's `responses.md` can read this block to surface "this finding was dropped from synthesis because X" context to the user — the structural errors are first-class, machine-readable regressions-with-reason.

## Next Phase Readiness

- All six CHAIR-XX requirements have automated verification routed through this script + the earlier per-plan tests (Plan 05-01 Case F, Plan 05-03 validator).
- Phase 5 static verification is complete; live-runtime verification remains (needs a human UAT run against the fixture that exercises actual Claude Code subagent fan-out).
- Ready for Phase 6 bench-persona work: the bench-personas marker in commands/review.md is intact; the prebuilt-run-dir test pattern extends naturally to bench-persona integration tests by adding extra drafts to `build_run_with_four_scorecards`.

## Self-Check: PASSED

- `tests/fixtures/contradiction-seed.md` → FOUND
- `scripts/test-chair-synthesis.sh` → FOUND (executable)
- `.github/workflows/ci.yml` → MODIFIED (contains `test-chair-synthesis.sh` and `Run Chair synthesis test`)
- Commit `568d8fc` → FOUND
- Commit `0655d35` → FOUND
- Commit `01122ab` → FOUND
- `./scripts/test-chair-synthesis.sh` → exit 0, "CHAIR SYNTHESIS TEST: PASSED"
- `./scripts/test-engine-smoke.sh` → exit 0 (no regression)
- `./scripts/validate-personas.sh` → exit 0 (no regression)

---
*Phase: 05-council-chair-synthesis*
*Completed: 2026-04-23*
