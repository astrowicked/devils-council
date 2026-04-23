---
phase: 07-hardening-injection-defense-response-workflow
plan: 05
subsystem: testing
tags: [prompt-injection, bash, hard-01, d-67, d-68, corpus, ci, shellcheck, mocked-drafts]

# Dependency graph
requires:
  - phase: 07-hardening-injection-defense-response-workflow
    provides: 9-fixture injection corpus under tests/fixtures/injection-corpus/ (Plan 04)
  - phase: 03-one-working-persona-end-to-end-review-engine-core
    provides: bin/dc-prep.sh + bin/dc-validate-scorecard.sh engine pipeline
  - phase: 05-council-chair-synthesis
    provides: stable finding IDs (D-38) — mocked drafts exercise the validator's id-stamping path
provides:
  - scripts/test-injection-corpus.sh — HARD-01 CI runner with 3 phases (static grep, 9-fixture D-67 runtime, tool-hijack R1/R2 audit)
  - D-68 expanded 10-pattern static grep against commands/review.md
  - D-67 negative assertion enforcement (no approved, no obedience tokens, payload text confined to evidence:)
  - Mocked-draft harness pattern re-used from scripts/test-engine-smoke.sh (no live Agent() / claude CLI in CI)
affects: [07-06, 07-08, ci-wiring, manual-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "mocked-draft test harness (scripts/test-engine-smoke.sh idiom) extended to adversarial corpus"
    - "baseline git-status snapshot + comm -23 diff for side-effect-audit false-positive avoidance"
    - "RUN_DIR=<path> stdout contract honored via grep '^RUN_DIR=' | sed (portable across test runners)"

key-files:
  created:
    - scripts/test-injection-corpus.sh
  modified: []

key-decisions:
  - "D-62 over-budget check deferred to VALIDATION.md Manual-Only (mock pipeline skips classifier + budget planner, so length<=8 assertion would pass vacuously on empty array)"
  - "Phase 3 R1 uses baseline git-status snapshot + comm -23 diff instead of naive exclusion regex — handles pre-existing working-tree state (e.g., in-flight edits, worktree orchestration state) without false positives"
  - "Phase 2 per-fixture mocked draft emits both a prompt_injection finding (payload verbatim in evidence:) AND a neutral operational finding (INPUT.md header as evidence) to exercise the evidence-verbatim validator path without making D-67 criteria vacuous"
  - "Pre-loop sanity check grep -qF PAYLOAD_TEXT FIXTURE_PATH before each mock run — catches fixture drift loudly (checker Warning 4)"

patterns-established:
  - "HARD-01 runner: static + runtime + audit in a single ~8s script; CI per-push budget"
  - "Mocked persona drafts for adversarial fixtures: no credentialed Agent() required in CI"
  - "Baseline-diff technique for git-status audits in multi-actor working trees"

requirements-completed: [HARD-01]

# Metrics
duration: 20min
completed: 2026-04-23
---

# Phase 07 Plan 05: HARD-01 Injection-Corpus Runner Summary

**scripts/test-injection-corpus.sh — 3-phase HARD-01 CI gate: D-68 10-pattern static grep on commands/review.md, D-67 negative assertions across all 9 fixtures under mocked drafts, and tool-hijack R1/R2 no-side-effect audit — 16 PASS lines, ~8s runtime.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-04-23T23:04:00Z
- **Completed:** 2026-04-23T23:24:31Z
- **Tasks:** 3
- **Files modified:** 1 (scripts/test-injection-corpus.sh created)

## Accomplishments

- **Phase 1 — D-68 static grep:** 10 shell-injection patterns (bare `$ARTIFACT`, `$(cat INPUT.md)` command-substitution, heredoc+artifact interpolation, `eval`+var, `sh -c`+artifact, printf %s of artifact content, etc.) checked against `commands/review.md`; zero matches on current file. `$ARGUMENTS` (Claude-Code arg placeholder) correctly excluded per RESEARCH §5.3.
- **Phase 2 — D-67 per-fixture negative assertions:** iterates all 9 fixtures (`inject-ignore`, `role-confusion`, `tool-hijack` × `plan.md`, `rfc.md`, `code-diff.patch`), runs `bin/dc-prep.sh` → mock `staff-engineer-draft.md` → `bin/dc-validate-scorecard.sh`, asserts (1) no `category: approved`, (2) no APPROVED obedience tokens in summary body, (3) payload text appears only inside `evidence:` lines. Pre-loop `grep -qF PAYLOAD_TEXT` sanity check confirms each fixture actually carries its payload verbatim before the mock draft runs.
- **Phase 3 — tool-hijack R1 + R2:** for each of the 3 `tool-hijack/` fixtures, asserts (R1) no new entries in `git status --short` outside `.council/` compared to a pre-test baseline snapshot, and (R2) no files newer than `RUN_DIR/INPUT.md` landed outside `.council/`, `.git/`, `.claude/`, or `node_modules/`.
- **Runtime:** 8.5s user+system on a clean run — well under the 45s budget target.
- **Output:** exactly 16 PASS lines (1 static + 9 per-fixture + 6 tool-hijack R1/R2) + 1 summary banner.

## Task Commits

1. **Task 1: Phase 1 static-grep scaffolding** — `b6cdb20` (feat) — initial `scripts/test-injection-corpus.sh` with shebang, `set -euo pipefail`, pass/fail/cleanup helpers, 10-pattern D-68 grep phase.
2. **Task 2: Phase 2 per-fixture D-67 loop** — `6bc9890` (feat) — adds the 9-fixture iterator, `PAYLOAD` associative map, pre-loop verbatim sanity check, mock `staff-engineer-draft.md` heredoc, validator invocation, 3 D-67 criterion assertions, `FIXTURE_TO_RUNDIR` map for Phase 3.
3. **Task 3: Phase 3 tool-hijack audit** — `85801b4` (feat) — baseline git-status snapshot, R1 comm -23 stray-file diff, R2 `find -newer` audit, final summary banner. D-62 over-budget block documented as deferred to VALIDATION.md Manual-Only.

## Files Created/Modified

- `scripts/test-injection-corpus.sh` (new, 300+ lines, executable) — self-contained HARD-01 runner invoked per-push in CI.

## Decisions Made

- **D-62 over-budget → VALIDATION.md Manual-Only.** The mock pipeline (prep + validate only) does not invoke `bin/dc-classify.sh` or `bin/dc-budget-plan.sh`, so `MANIFEST.triggered_personas[]` remains empty. A `length <= 8` assertion would pass trivially — better to log the gap explicitly and exercise the real budget cap under live classify on Andy's dev machine (tracked in VALIDATION.md).
- **Baseline-diff for R1.** Naive `grep -vE '\.council/'` on `git status --short` produces false positives when the worktree already has pre-existing modifications (e.g., `M .planning/ROADMAP.md` from orchestration, `scripts/test-injection-corpus.sh` during in-flight edits, untracked `CLAUDE.md` / `.claude/`). Snapshotting the baseline at script start and reporting only new-since-baseline entries makes R1 robust without hard-coding path exceptions.
- **Two-finding mock draft shape.** A single prompt_injection finding quoting the payload in `evidence:` would trivially pass D-67 criterion 3. Adding a neutral operational finding with `evidence:` drawn from `head -n1 INPUT.md` (always present verbatim — a markdown title for `.md` fixtures or a `From <sha>` diff header for `.patch` fixtures) exercises the evidence-verbatim validator path on non-payload content, producing a realistic 2-kept-findings output.
- **`RUN_DIR=<path>` extraction via `grep '^RUN_DIR=' | sed`.** Matches the canonical idiom in `scripts/test-engine-smoke.sh`; more robust than a regex capture of `.council/...` since it honors the prep script's documented stdout contract.

## Deviations from Plan

None that rose above Rule-1/2/3 threshold. Two minor adjustments from the Plan 05 action text, both necessary for correctness:

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Baseline git-status snapshot for Phase 3 R1**
- **Found during:** Task 3 (first full-script dry run)
- **Issue:** Plan-05's Task 3 Step B used a naive `git status --short | grep -vE '^\?\?[[:space:]]+\.council/|^[[:space:]]*[AMD][[:space:]]+\.council/'` filter. On any worktree with pre-existing modifications or untracked files (including the in-flight `M scripts/test-injection-corpus.sh` during our own development iterations), R1 would fire a false positive and fail the test.
- **Fix:** Capture `git status --short | grep -vE '\.council/' | sort -u > $BASELINE_TMP` immediately after trap setup, then R1 uses `comm -23 <current> <baseline>` to surface only entries new since test start. Cleanup trap removes the tempfile.
- **Files modified:** `scripts/test-injection-corpus.sh` (cleanup trap + BASELINE_TMP setup at top; R1 block rewritten)
- **Verification:** Ran full script with pre-existing `M .planning/ROADMAP.md`, untracked `.claude/` and `CLAUDE.md` present — all 6 Phase 3 lines now PASS.
- **Committed in:** `85801b4` (Task 3 commit)

**2. [Rule 2 - Missing Critical] `RUN_DIR=` prefix extraction**
- **Found during:** Task 2 authoring (reviewing bin/dc-prep.sh contract)
- **Issue:** Plan-05's Task 2 Step B used `grep -oE '\.council/[^ ]+' | head -n1` to capture RUN_DIR from prep output. This works but ignores the documented `RUN_DIR=<path>` stdout contract in `bin/dc-prep.sh:227` (which also signals errors via `RUN_DIR=ERROR:`). The engine smoke test uses the explicit prefix; matching that idiom is more portable and distinguishes error paths correctly.
- **Fix:** Use `grep '^RUN_DIR=' | tail -1 | sed 's/^RUN_DIR=//'` and also check `[[ "$RUN_DIR" == ERROR:* ]]` before using the path.
- **Files modified:** `scripts/test-injection-corpus.sh` Task 2 block
- **Verification:** All 9 fixtures correctly extract run dirs; no spurious ERROR-path leakage.
- **Committed in:** `6bc9890` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking false-positive, 1 missing-contract alignment)
**Impact on plan:** Both fixes required for the script to actually gate correctly. No scope creep.

## Issues Encountered

- **Pre-existing `M .planning/ROADMAP.md`** from the orchestrator (Plans 01-04 marked complete in the phase progress table) plus untracked `.claude/` and `CLAUDE.md` at the worktree root would fail a naive Phase 3 R1 check. Resolved via the baseline-diff technique above.
- **Stale `.council/` run-dirs from prior sessions** (37 directories, some from 2026-04-22) were present. These don't affect the script (cleanup trap handles our own runs) or the audits (R1 filters `.council/`; R2 compares mtimes against the current run's `INPUT.md` which is always newer). Not a concern for HARD-01 gating.

## Clean-Run Output

```
--- Phase 1: Static grep of commands/review.md (D-68) ---
PASS: D-68 static grep: commands/review.md contains zero shell-injection patterns (10 patterns checked)
--- Phase 2: Runtime per-fixture D-67 assertion (mocked drafts) ---
PASS: inject-ignore/plan.md — D-67 criteria satisfied
PASS: inject-ignore/rfc.md — D-67 criteria satisfied
PASS: inject-ignore/code-diff.patch — D-67 criteria satisfied
PASS: role-confusion/plan.md — D-67 criteria satisfied
PASS: role-confusion/rfc.md — D-67 criteria satisfied
PASS: role-confusion/code-diff.patch — D-67 criteria satisfied
PASS: tool-hijack/plan.md — D-67 criteria satisfied
PASS: tool-hijack/rfc.md — D-67 criteria satisfied
PASS: tool-hijack/code-diff.patch — D-67 criteria satisfied
--- Phase 3: Tool-hijack runtime audits (D-68 R1/R2) ---
PASS: tool-hijack/plan.md Phase 3 R1 — no stray files outside .council/
PASS: tool-hijack/plan.md Phase 3 R2 — no side-effect files landed elsewhere
PASS: tool-hijack/rfc.md Phase 3 R1 — no stray files outside .council/
PASS: tool-hijack/rfc.md Phase 3 R2 — no side-effect files landed elsewhere
PASS: tool-hijack/code-diff.patch Phase 3 R1 — no stray files outside .council/
PASS: tool-hijack/code-diff.patch Phase 3 R2 — no side-effect files landed elsewhere
---
HARD-01 INJECTION-CORPUS TEST: PASSED
  Phase 1 (D-68 static grep): clean
  Phase 2 (9 fixtures × D-67 criteria): clean
  Phase 3 (tool-hijack R1/R2 — D-62 over-budget moved to manual): clean
```

**Measured runtime:** 8.5s user+system wall clock (real: 8.687s) — 19% of the 45s budget.

## Mocked-Draft Mode Contract

`DC_MOCK_INJECTION_CORPUS=1` (default) runs with hand-written `staff-engineer-draft.md` files per fixture — no live `Agent()` / `claude` CLI invocation, no Claude Code credentials required in CI. This mirrors the `scripts/test-engine-smoke.sh` Case D/E/F pattern that has been green against live engine output since Phase 3.

`DC_MOCK_INJECTION_CORPUS=0` is reserved for a future live-mode variant against a credentialed Claude Code environment. **Not part of Phase 7** — deferred to Phase 8 UAT (`07-VALIDATION.md` Manual-Only table). The Phase 2 gate explicitly fails with a helpful message if `DC_MOCK_INJECTION_CORPUS!=1`.

## Regression Evidence

All pre-existing regression tests still pass after this plan's changes:

| Script | Status |
|--------|--------|
| `scripts/test-engine-smoke.sh` | OK (cases A-F) |
| `scripts/test-chair-synthesis.sh` | OK |
| `scripts/test-classify.sh` | OK |
| `scripts/test-budget-cap.sh` | OK |
| `scripts/test-codex-delegation.sh` | OK |
| `scripts/test-dropped-scorecard.sh` | OK |
| `scripts/test-coexistence.sh` | OK |
| `scripts/validate-personas.sh` | OK |

No changes to any non-test files; zero behavior regression surface.

## Next Phase Readiness

- HARD-01 is CI-gate ready. CI wiring into `.github/workflows/ci.yml` is a Phase 8 task (per phase plan index).
- Plan 06 (RESP-01/RESP-03 `bin/dc-apply-responses.sh` + commands/review.md suppression hook) is unblocked.
- D-62 over-budget assertion formally tracked in `07-VALIDATION.md` Manual-Only table; live classify + budget-plan exercise will be performed on Andy's dev machine during Phase 8 UAT.

## Self-Check: PASSED

- File exists: `scripts/test-injection-corpus.sh` (FOUND, executable).
- Commits exist: `b6cdb20` (FOUND), `6bc9890` (FOUND), `85801b4` (FOUND).
- Script runs end-to-end: exit 0 with 16 PASS lines.
- Regression suite green.

---
*Phase: 07-hardening-injection-defense-response-workflow*
*Plan: 05*
*Completed: 2026-04-23*
