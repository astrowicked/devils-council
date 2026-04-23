---
phase: 07-hardening-injection-defense-response-workflow
plan: 07
subsystem: render-transform
tags: [resp-04, d-72, d-73, severity-render, show-nits, dedup, last-autonomous-plan]

# Dependency graph
requires:
  - phase: 05-council-chair-synthesis
    provides: D-34/D-35 Chair Top-3 candidate set (severity render sources Top-3 from SYNTHESIS.md, does not recompute)
  - phase: 06-classifier-bench-personas-cost-instrumentation
    provides: D-58 flag-parsing idiom (--only/--exclude/--cap-usd); --show-nits follows the same pattern
  - phase: 07-hardening-injection-defense-response-workflow
    provides: Plan 06 suppression anchors (## Apply responses.md suppression, Chair candidate-set filter, ## Render responses.md suppression note)
provides:
  - commands/review.md extensions — --show-nits flag parser + sha256 dedup + severity-tier render transform
  - SHOW_NITS + ARGS_FOR_PREP + SKIP_FANOUT shell variables on the conductor
  - scripts/test-severity-render.sh — 12-assertion render-spec regression gate
  - tests/fixtures/severity-render/ — 6-finding synthetic scorecard (1 blocker + 2 major + 2 minor + 1 nit) + matching MANIFEST + minimal SYNTHESIS
affects: [phase-08-documentation-release]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Render-time transform pattern: per-persona findings[] partitioned by severity; blockers already in Chair Top-3 → skip; major one-liners; minor collapsed summary; nits collapsed (expanded under --show-nits)"
    - "Flag-parser extension via case-statement shell-inject: echoes SHOW_NITS + ARGS_FOR_PREP key-value pairs, conductor reads them as simple text variables"
    - "Content-addressed dedup for re-render: sha256(artifact) + jq input_filename over .council/*/MANIFEST.json to locate prior runs; reuse RUN_DIR without re-spawning the engine"
    - "Cross-phase test drift handling: when Plan 07 replaces the render-block header from Phase 5's conventions, amend the Phase 5 regression test to accept both header shapes rather than re-adding legacy text"

key-files:
  created:
    - scripts/test-severity-render.sh
    - tests/fixtures/severity-render/staff-engineer.md
    - tests/fixtures/severity-render/MANIFEST.json
    - tests/fixtures/severity-render/SYNTHESIS.md
    - .planning/phases/07-hardening-injection-defense-response-workflow/07-07-SUMMARY.md
  modified:
    - commands/review.md
    - scripts/test-chair-synthesis.sh

key-decisions:
  - "Variable rename: ARTIFACT_RESOLVED → RESOLVED_PATH to avoid lexical collision with D-68 static-grep banned \\$ARTIFACT pattern; preserves Phase 6 injection-surface invariant without exception"
  - "Amend test-chair-synthesis.sh Case E to accept both old (`## Render all four scorecards inline`) and new (`## Render all four scorecards (severity-tier transform — D-72 / D-73)`) header forms; Phase 5 test drift vs Phase 7 D-72 render rename"
  - "SHOW_FULL reserved-but-unwired pattern: future --full flag would set SHOW_FULL=1 to restore Phase 4/5 verbatim dump; Phase 7 intentionally does not wire it (D-73 narrow)"
  - "Dedup match on artifact_path OR sha256: artifact_path matches the common re-run-same-file case; sha256 matches when artifact is renamed/moved between runs (per research §3.3 Option iii recommendation)"

patterns-established:
  - "Shell-inject variable propagation: case statement emits `KEY=VALUE` lines to stdout; conductor reads each and uses the variable by name in later blocks. Same idiom Phase 6 D-58 uses for --only/--exclude/--cap-usd"
  - "Severity-tier transform as command-output only: D-72 locks the constraint that SYNTHESIS.md + per-persona scorecards on disk are NEVER modified by render; test-severity-render.sh asserts byte-identical file hashes pre/post render as the enforcement mechanism"
  - "Guard-and-fall-through flag handling: --show-nits with no prior run emits a single warning line and falls through to fresh-run; avoids dedicated `no prior run` error path while preserving O(1) cost when prior run exists"

requirements-completed: [RESP-04]

# Metrics
duration: ~22min
completed: 2026-04-23
---

# Phase 07 Plan 07: Severity-Tier Render Transform + `--show-nits` Summary

**RESP-04 delivered: commands/review.md now ships `--show-nits` flag parsing, sha256-based prior-run dedup, and a severity-tier render transform (D-72) that collapses nits by default + expands them under `--show-nits` — disk artifacts remain untouched (render-layer-only transform).**

## Performance

- **Duration:** ~22 min
- **Started:** 2026-04-23T23:28Z
- **Completed:** 2026-04-23T23:50Z
- **Tasks:** 3 (Task 1 fixtures, Task 2 review.md edits, Task 3 test)
- **Files created:** 5 (3 fixtures, 1 test, 1 SUMMARY)
- **Files modified:** 2 (commands/review.md, scripts/test-chair-synthesis.sh)

## Accomplishments

- **Three additive edits to commands/review.md, all with zero overlap against Plan 06.** Flag-parser section `## --show-nits (D-73 / RESP-04)` + dedup section `## --show-nits dedup (D-73 Option iii)` inserted after the Phase 6 `## Parse Phase 6 flags from $ARGUMENTS` block (they set SHOW_NITS/ARGS_FOR_PREP/SKIP_FANOUT/RUN_DIR via shell-inject). The `## Run preparation` heading gains a one-paragraph SKIP_FANOUT early-return note. The `## Render all four scorecards inline` section at line 717 is REPLACED with `## Render all four scorecards (severity-tier transform — D-72 / D-73)` at line 717 — legacy verbatim dump becomes the unreachable `SHOW_FULL=1` branch; default path emits blockers-via-Chair + major one-liners + minor collapsed-count + nits collapsed (or expanded under SHOW_NITS=1).

- **commands/review.md line delta: 734 → 886 LOC (+152 lines).** Flag+dedup block adds ~74 lines; render-transform replacement adds ~78 lines over the old inline dump. Plan 06's three anchors — `## Apply responses.md suppression (RESP-01)` (line 534), Chair candidate-set filter (line 572), `## Render responses.md suppression note (D-71)` (line 701) — remain byte-identical to their Plan 06 state. Verified by `grep -c` on each marker: still 1 each except the D-71 render marker which has 2 (self-reference + the generated rendering prose).

- **D-68 static-grep invariant preserved under lexical collision.** Initial dedup implementation used `ARTIFACT_RESOLVED` as the resolved-path variable, which tripped the D-68 banned pattern `\$ARTIFACT` (research §5.2 expanded pattern list). Renamed to `RESOLVED_PATH` across all 5 references; `grep -cE '\$ARTIFACT|\$\(cat\s+INPUT\.md\)|\$\(cat\s+\$INPUT\)' commands/review.md` → 0. `scripts/test-injection-corpus.sh` D-68 static check stays green with no amendment needed.

- **Synthetic render-fixture set (Task 1).** `tests/fixtures/severity-render/staff-engineer.md` ships 6 findings with all four severity tiers (1 blocker, 2 major, 2 minor, 1 nit) + matching `MANIFEST.json` (personas_run[0].findings aligned by id) + minimal `SYNTHESIS.md` with the three required Chair sections (Contradictions / Top-3 Blocking Concerns / Agreements). The Top-3 section cites `staff-engineer-blocker1` so downstream tests can verify blockers render inline via the Chair and are NOT duplicated by the severity-tier block.

- **scripts/test-severity-render.sh ships with 12 PASS assertions in ~331ms.** Six default-mode checks (major one-liners present, minor collapsed, nits collapsed, no [nit] leak, no nit-claim leak), three --show-nits checks (major still present, nit one-liner expands, collapse line absent), three RESP-04 read-only invariant checks (staff-engineer.md / MANIFEST.json / SYNTHESIS.md hashes byte-identical pre/post render). Test uses a python helper that mirrors the pseudocode in commands/review.md render block — does NOT invoke `claude` CLI and does NOT write to `.council/`.

- **Cross-phase test drift resolved (auto-fix Rule 1).** `scripts/test-chair-synthesis.sh` Case E hard-coded the old Phase 4 header `## Render all four scorecards inline` as a required section. Plan 07's D-72 rename replaces that header with the severity-tier form. Amended Case E to accept either header via a compatibility regex (`^## Render all four scorecards( inline| \(severity-tier transform)`); Phase 5 semantics preserved (Spawn → Validate → Render order still asserted), Phase 7 header rename honored.

- **All 11 prior regression suites stay green.** `test-engine-smoke.sh` (Cases A-F), `test-chair-synthesis.sh` (Cases A-E after amendment), `test-classify.sh`, `test-budget-cap.sh`, `test-codex-delegation.sh`, `test-dropped-scorecard.sh`, `test-coexistence.sh`, `test-responses-suppression.sh` (8 assertions), `test-injection-corpus.sh` (Phase 1 static + Phase 2 9 fixtures + Phase 3 R1/R2), `validate-personas.sh`, and the new `test-severity-render.sh` (12 assertions) — plus `claude plugin validate .` → `✔ Validation passed`. Tests requiring live Agent metadata (`test-cache-reduction.sh`, `test-order-swap.sh`, `test-persona-voice.sh`) skip cleanly as expected per plan context.

## Task Commits

Each task committed atomically with `--no-verify` per parallel-executor contract:

1. **Task 1: Author synthetic render-fixture set** — `80bd03e` (test)
2. **Task 2: Flag parser + dedup + severity-tier render transform + Phase 5 test amendment** — `bb4117e` (feat)
3. **Task 3: scripts/test-severity-render.sh** — `a11ef3a` (test)

Plan metadata commit will be created by orchestrator.

## Files Created/Modified

- `tests/fixtures/severity-render/staff-engineer.md` (created, 48 LOC) — mocked persona scorecard with 6 findings across all severity tiers.
- `tests/fixtures/severity-render/MANIFEST.json` (created, 23 LOC) — matches scorecard; `suppressed_findings: []` + `validation[0].findings_kept: 6`.
- `tests/fixtures/severity-render/SYNTHESIS.md` (created, 17 LOC) — minimal Chair output with Contradictions / Top-3 / Agreements sections citing blocker id.
- `commands/review.md` (modified, +165 / −13 lines; 734 → 886 LOC) — three additive edits + one header rename per D-72.
- `scripts/test-chair-synthesis.sh` (modified, +6 / −4 lines) — Case E accepts both old and new render-block header shapes.
- `scripts/test-severity-render.sh` (created, 153 LOC, executable) — 12-assertion render-spec regression gate.
- `.planning/phases/07-hardening-injection-defense-response-workflow/07-07-SUMMARY.md` (this file).

## Verification Evidence

### Task 3 Severity-Render Test Output (authoritative PASS log)

```
PASS: default: major1 one-liner present
PASS: default: major2 one-liner present
PASS: default: minor collapsed summary present
PASS: default: nits collapse line present
PASS: default: no [nit] one-liners emitted (correctly collapsed)
PASS: default: nit claim text not present (correctly collapsed)
PASS: --show-nits: major1 still present
PASS: --show-nits: nit one-liner present
PASS: --show-nits: no collapse line (correctly expanded)
PASS: read-only: staff-engineer.md hash unchanged
PASS: read-only: MANIFEST.json hash unchanged
PASS: read-only: SYNTHESIS.md hash unchanged
RESP-04 SEVERITY-RENDER TEST: PASSED
```

### Full Regression Suite (11/11 green)

```
OK  test-engine-smoke.sh
OK  test-chair-synthesis.sh
OK  test-classify.sh
OK  test-budget-cap.sh
OK  test-codex-delegation.sh
OK  test-dropped-scorecard.sh
OK  test-coexistence.sh
OK  test-responses-suppression.sh
OK  test-injection-corpus.sh
OK  test-severity-render.sh
OK  validate-personas.sh
```

### Plugin Validate

```
Validating marketplace manifest: /.../.claude-plugin/marketplace.json
✔ Validation passed
```

### Acceptance-Marker Grep Totals (commands/review.md)

| Marker | Count (expected ≥) |
|---|---|
| `SHOW_NITS` | 11 (≥ 3 required) |
| `SKIP_FANOUT` | 5 (≥ 2 required) |
| `ARGS_FOR_PREP` | 6 (≥ 2 required) |
| `severity-tier transform` | 3 (≥ 1 required) |
| `nits collapsed from` | 1 (≥ 1 required) |
| `show-nits to expand` | 1 (≥ 1 required) |
| `cat .council/<run>/` | 5 (≥ 2 required) |
| `## --show-nits (D-73 / RESP-04)` | 1 (required) |
| `## --show-nits dedup (D-73 Option iii)` | 1 (required) |
| `## Render all four scorecards (severity-tier transform` | 1 (required) |
| `## Apply responses.md suppression` (Plan 06, unchanged) | 1 (required) |
| `## Render responses.md suppression note` (Plan 06, unchanged) | 2 |
| `## Render delegation status lines (CDEX-05 fail-loud)` (unchanged) | 1 (required) |
| `^    4 personas ran\.` (meta-summary, unchanged) | 1 (required) |
| `\$ARTIFACT\|\$\(cat\s+INPUT\.md\)\|...` (D-68 invariant) | 0 (required) |

### Confirmation — Chair synthesis + CDEX-05 delegation blocks unchanged

The Chair synthesis render (`## Validate synthesis and render synthesis-first`, now at line 659) and the CDEX-05 delegation status block (`## Render delegation status lines (CDEX-05 fail-loud)`, now at line 864) remain textually unchanged from their pre-Phase-7-Plan-07 state — Plan 07's edits are strictly bounded to the flag-parser region, the pre-prep dedup insertion, and the render-block replacement. Line numbers shift forward (by +74 for sections after the flag-parser / dedup insertion, and by +78 for sections after the render replacement) but content is byte-identical. Verified by `git diff bb4117e^ bb4117e -- commands/review.md` showing only additions in the intended edit regions plus the one-paragraph SKIP_FANOUT note prepended to `## Run preparation`.

## Plan 07 Edit-Region Isolation (verified)

Plan 06's three anchors remain present and unmodified:
- `## Apply responses.md suppression (RESP-01)` — still at a single site (grep count = 1).
- Chair prompt candidate-set filter clause (`MANIFEST.suppressed_findings[].finding_id`) — still inside the Chair spawn prompt.
- `## Render responses.md suppression note (D-71)` — still between synthesis render and per-persona scorecards (immediately above the severity-tier render block).

Plan 07's three additions — flag parser, dedup, severity-tier render — sit outside Plan 06's line ranges. Zero overlap. The `SKIP_FANOUT` early-return note added to `## Run preparation` is the only Plan 07 edit that annotates (but does not modify) a section the rest of the pipeline shares with every prior phase.

## Decisions Made

1. **`ARTIFACT_RESOLVED` → `RESOLVED_PATH` rename.** The D-68 static grep (HARD-01 invariant) treats `$ARTIFACT` as a prefix-match against banned patterns. Using `$ARTIFACT_RESOLVED` as an internal variable lexically collides with that grep even though semantically it holds a validated local file path, not artifact content. Renaming to `$RESOLVED_PATH` keeps the D-68 invariant clean without weakening the grep.
2. **Phase 5 test Case E amendment over rollback.** Plan 07 D-72 explicitly renames `## Render all four scorecards inline` → `## Render all four scorecards (severity-tier transform — D-72 / D-73)`. `test-chair-synthesis.sh` Case E was written for Phase 5 and hard-coded the old header. Options: (a) amend the test to accept both header forms (forward-compat), (b) keep both headers in review.md (defeats D-72 "replaces inline dump"), (c) roll back the rename (violates Plan 07 acceptance criterion). Chose (a) — the test's structural intent (Spawn → Validate → Render ordering) is preserved; only the header-literal assertion loosens to `^## Render all four scorecards( inline| \(severity-tier transform)`.
3. **`SHOW_FULL` reserved but unwired.** D-73 is deliberately narrow: one flag for one collapse case. A future `--full` flag would restore Phase 4/5 verbatim dump by setting `SHOW_FULL=1`. Phase 7 ships the branch skeleton (the `if SHOW_FULL=1 ... else ...` pattern in the render block) but NOT the flag parser — so `SHOW_FULL=1` is unreachable in v1. This makes the v1.1 addition a two-line flag-parser diff instead of a render-block rewrite.
4. **`--show-nits` warning-and-fall-through when no prior run exists.** If the user runs `/devils-council:review foo.md --show-nits` and no `.council/<ts>-<slug>/MANIFEST.json` has a matching `artifact_path` or `sha256`, the dedup logic leaves `SKIP_FANOUT` unset and the pipeline runs fresh. The render block emits one warning line near the top of the output (`No prior run found for this artifact; running fresh.`) so the user understands why a fresh run happened and that `--show-nits` still flips the nit-expansion branch on this new run.
5. **Dedup match on `artifact_path OR sha256`.** Research §3.3 Option iii recommended both — `artifact_path` match handles the common "re-run-same-file" case, `sha256` match handles the renamed-file-same-content case. Both paths are implemented via a single `jq select(.artifact_path == $p or .sha256 == $sha)` filter; first match wins.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Renamed `ARTIFACT_RESOLVED` → `RESOLVED_PATH` to preserve D-68 invariant**
- **Found during:** Task 2 verification (D-68 static grep returned 4 matches instead of 0).
- **Issue:** The dedup block used `ARTIFACT_RESOLVED` as a shell variable name. The D-68 banned-pattern grep `\$ARTIFACT|\$\(cat\s+INPUT\.md\)|\$\(cat\s+\$INPUT\)` treats `$ARTIFACT` as a prefix match, so `$ARTIFACT_RESOLVED` tripped the invariant — even though semantically the variable holds a validated local file path (not artifact content).
- **Fix:** Renamed to `$RESOLVED_PATH` across all 5 references in the dedup block. D-68 grep now returns 0 matches.
- **Files modified:** commands/review.md
- **Verification:** `grep -cE '\$ARTIFACT|\$\(cat\s+INPUT\.md\)|\$\(cat\s+\$INPUT\)' commands/review.md` → 0; `scripts/test-injection-corpus.sh` Phase 1 static check still exits 0.
- **Committed in:** `bb4117e` (folded into Task 2 commit since it was a single iteration on the Task 2 edits).

**2. [Rule 1 - Bug] Amended `scripts/test-chair-synthesis.sh` Case E to accept new render-block header**
- **Found during:** Task 2 regression test run (test-chair-synthesis FAILED on Case E).
- **Issue:** Case E hard-coded `^## Render all four scorecards inline$` as a required header. Plan 07's D-72 explicitly renames that header to `## Render all four scorecards (severity-tier transform — D-72 / D-73)`. The Phase 5 test and the Phase 7 plan acceptance criterion are in direct conflict.
- **Fix:** Amended Case E's header-presence check and section-ordering awk pattern to accept either header form: `^## Render all four scorecards( inline| \(severity-tier transform)`. Structural invariant (Spawn → Validate → Render ordering) preserved.
- **Files modified:** scripts/test-chair-synthesis.sh
- **Verification:** `bash scripts/test-chair-synthesis.sh` → all Cases A-E pass; `CHAIR SYNTHESIS TEST: PASSED`.
- **Committed in:** `bb4117e` (folded into Task 2 commit).

---

**Total deviations:** 2 auto-fixes (both Rule 1 — bug fixes) • Both arose from legitimate Plan 07 changes colliding with pre-existing invariants/tests and were resolved by surgical edits that preserved semantics.

## Issues Encountered

- **Worktree-branch check at entry.** Worktree HEAD and merge-base were already aligned at `a08020b` (the orchestrator's instructed base). No rebase or reset needed. Standard protocol confirmed clean.
- **PreToolUse read-reminder hook fired on every Edit.** The hook emitted a READ-BEFORE-EDIT reminder on each Edit to `commands/review.md` / `test-chair-synthesis.sh` even though both files had been read earlier in the session via the `<files_to_read>` initial load and explicit follow-up Read calls. Hook is advisory — edits succeeded. Not a blocker.

## Threat Flags

None. Plan 07's render transform is render-layer-only (D-72 invariant) — no new network endpoints, auth paths, or schema surfaces. The dedup shell block reads `.council/*/MANIFEST.json` via jq (plugin-owned path) and computes sha256 of a local file (already an established pattern in `bin/dc-prep.sh`). T-07-26 (`--show-nits` flag-value injection) and T-07-27 (dedup iteration DoS) remain as disposed in the plan's own threat register (mitigated + accepted).

## Known Stubs

None. The render transform implements the full D-72 spec (blockers-via-Chair + major + minor + nit) and both SHOW_NITS branches (default collapsed + --show-nits expanded). `SHOW_FULL=1` branch is intentionally reserved-but-unreachable per Decision #3; this is a documented future-flag anchor, not a stub that prevents Plan 07's goal.

## User Setup Required

None - no external service configuration required. `--show-nits` is discoverable via the command's `argument-hint` (extends existing Phase 6 flag family; a future doc plan in Phase 8 can add a README mention).

## Next Phase Readiness

- **Phase 7 autonomous plans complete.** This is the last autonomous plan for Phase 7 per the orchestrator's instruction; remaining Phase 7 work (if any) is documentation/release coordination.
- **Manual validation per 07-VALIDATION.md.** Andy runs `/devils-council:review tests/fixtures/plan-sample.md` on his dev machine, confirms Top-3 renders inline from the Chair, major findings render as one-liners, minor findings render as a collapsed summary, and nits render as a single `N nits collapsed — run with --show-nits to expand` line. Then `/devils-council:review tests/fixtures/plan-sample.md --show-nits` confirms dedup reuses the existing `.council/<ts>-<slug>/` dir (no new run dir created, fast completion) and nits expand to one-liners.

## Self-Check: PASSED

Verified post-write:

- `tests/fixtures/severity-render/staff-engineer.md` → FOUND (6 findings across blocker/major/minor/nit)
- `tests/fixtures/severity-render/MANIFEST.json` → FOUND (personas_run[0].findings length 6)
- `tests/fixtures/severity-render/SYNTHESIS.md` → FOUND (Top-3 cites `staff-engineer-blocker1`)
- `commands/review.md` → 886 LOC; all 10 acceptance markers present; Plan 06 anchors intact; D-68 static grep clean (0 matches)
- `scripts/test-severity-render.sh` → FOUND (executable, 12 PASS assertions, ~331ms runtime)
- `scripts/test-chair-synthesis.sh` → amended Case E accepts both old and new render-block header shapes
- Commit `80bd03e` (Task 1 fixtures) → FOUND in `git log`
- Commit `bb4117e` (Task 2 review.md + Phase 5 test amendment) → FOUND in `git log`
- Commit `a11ef3a` (Task 3 severity-render test) → FOUND in `git log`
- All 11 primary regression test suites exit 0
- `claude plugin validate .` exits 0

---
*Phase: 07-hardening-injection-defense-response-workflow*
*Completed: 2026-04-23*
