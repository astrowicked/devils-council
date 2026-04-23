---
phase: 06-classifier-bench-personas-cost-instrumentation
plan: 06
subsystem: conductor
tags: [budget, classifier, haiku-gate, bench-personas, flag-parsing, D-56, D-57, D-58, BNCH-07, BNCH-08, BNCH-09]
requires:
  - 06-02-PLAN (bin/dc-classify.sh exists, writes MANIFEST.classifier / triggered_personas / trigger_reasons)
  - 06-03-PLAN (agents/artifact-classifier.md Haiku subagent)
  - 06-04-PLAN (bench persona agents: security-reviewer, dual-deploy-reviewer, finops-auditor, air-gap-reviewer)
  - 06-05-PLAN (Plan 05 Codex delegation + fail-loud render sections in review.md)
provides:
  - config.json .budget block (D-57 canonical shape)
  - bin/dc-budget-plan.sh pre-spawn budget planner
  - MANIFEST.budget + MANIFEST.personas_skipped[] contracts
  - commands/review.md extensions: flag parsing, classifier shell-injection, Haiku gate,
    budget plan invocation, core --exclude filter, bench fan-out, extended render
  - scripts/test-budget-cap.sh (5 scenarios + non-numeric bonus)
  - 3 budget-classifier-*.json fixtures
affects:
  - commands/review.md (argument-hint extended; 4 new H2 sections; bench marker replaced; render extended)
tech-stack:
  added: []
  patterns:
    - pre-spawn budget gating (D-56): never kills running Agent(), only narrows candidates
    - --exclude wins over --only for same persona (D-58 precedence)
    - --cap-usd override with over-budget raises structural cap_exceeded error (MANIFEST.budget.errors[])
    - core personas never filtered by --only; only --exclude can suppress them
    - jq --argjson additive manifest merges mirroring bin/dc-validate-scorecard.sh
key-files:
  created:
    - config.json
    - bin/dc-budget-plan.sh
    - scripts/test-budget-cap.sh
    - tests/fixtures/bench-personas/budget-classifier-all-bench.json
    - tests/fixtures/bench-personas/budget-classifier-one-bench.json
    - tests/fixtures/bench-personas/budget-classifier-zero-bench.json
  modified:
    - commands/review.md
decisions:
  - "Bench priority order matches D-57 exactly: [security-reviewer, dual-deploy-reviewer, finops-auditor, air-gap-reviewer]. No deviation."
  - "--cap-usd validation runs BEFORE run-dir existence checks so malformed caps fail fast per T-06-04."
  - "personas_skipped[] classifies each non-spawned triggered persona as either budget_cap or excluded_by_flag; --exclude wins over --only when both name the same slug."
  - "Core --exclude handling documented in a dedicated H2 section in review.md (not inside bin/dc-budget-plan.sh) because budget-plan is bench-only and does not see core personas."
metrics:
  duration: ~20 min
  tasks_completed: 3
  files_created: 6
  files_modified: 1
  completed: 2026-04-23
---

# Phase 06 Plan 06: Budget Cap + Flag Parsing + Classifier Wiring Summary

Wired bin/dc-classify.sh shell-injection, agents/artifact-classifier.md Haiku gate, and bin/dc-budget-plan.sh pre-spawn budget planner into commands/review.md, with --only/--exclude/--cap-usd flag parsing, MANIFEST.budget + MANIFEST.personas_skipped[] contracts, and conditional bench persona fan-out at the replaced `<!-- bench-personas -->` marker.

## What Shipped

### config.json (project root, D-57 verbatim)

```json
{
  "budget": {
    "cap_usd": 0.50,
    "per_persona_estimate_usd": 0.08,
    "bench_priority_order": [
      "security-reviewer",
      "dual-deploy-reviewer",
      "finops-auditor",
      "air-gap-reviewer"
    ],
    "wall_clock_cap_seconds": 30
  }
}
```

Matches D-57 exactly; no deviation from the canonical priority order.

### bin/dc-budget-plan.sh (177 lines, 755)

Pre-spawn budget planner. Reads `<RUN_DIR>/MANIFEST.json .triggered_personas[]` and `config.json .budget`, applies `--only` → `--exclude` → priority-order → cap filters, writes `.budget` and `.personas_skipped[]` back into MANIFEST, emits `SPAWN_BENCH=csv` + `ERRORS=N` lines on stdout. Exit 0 even when over-budget; exit 2 only on usage error or malformed `--cap-usd`.

### scripts/test-budget-cap.sh (150 lines, 755)

Exercises 5 canonical scenarios + 1 bonus. **19 PASS assertions, 0 FAIL.**

| # | Scenario | Expected outcome |
|---|----------|------------------|
| 1 | under-cap-all-fit | All 4 triggered personas spawn; `over_budget=false` |
| 2 | over-cap-priority-selection | Tight cap=$0.08; security-reviewer wins on priority; 3 skipped with `budget_cap` reason |
| 3 | --only=finops-auditor | Only finops spawns; 3 skipped with `excluded_by_flag` |
| 4 | --exclude=finops,air-gap | security + dual-deploy spawn; 2 skipped with `excluded_by_flag` |
| 5 | --cap-usd=0.08 override + over-budget | `MANIFEST.budget.errors[0].code == cap_exceeded`, requested=4, allowed=1 |
| 6 (bonus) | --cap-usd=unlimited | Exit 2 (D-58 no-sentinel rule) |

### Fixtures (tests/fixtures/bench-personas/)

- `budget-classifier-all-bench.json` — 4 triggered bench personas, 8 deterministic signal matches
- `budget-classifier-one-bench.json` — 1 triggered (finops-auditor)
- `budget-classifier-zero-bench.json` — 0 triggered, `needs_haiku=true` (feeds Haiku-gate scenarios in later plans)

### commands/review.md (589 lines total; 173 added, 2 modified)

**Frontmatter change (line 4):** argument-hint extended:

```
"<artifact-path> [--type=<code-diff|plan|rfc>] [--only=<p1,p2>] [--exclude=<p1,p2>] [--cap-usd=<N>]"
```

**Classifier shell-injection** (line 12): after the prep injection, added:

```
!`${CLAUDE_PLUGIN_ROOT}/bin/dc-classify.sh "$(ls -t .council/*/INPUT.md 2>/dev/null | head -1)" "$(ls -t .council/*/MANIFEST.json 2>/dev/null | head -1)"`
```

**Four new H2 sections** between `## Interpreting the prep output` (line 21) and `## Prepare the injection-resistant framing` (line 140):

| Line | Heading |
|------|---------|
| 32 | `## Parse Phase 6 flags from $ARGUMENTS` — extracts `ONLY`, `EXCLUDE`, `CAP_USD` bash variables |
| 49 | `## Invoke Haiku classifier when needed (BNCH-02, D-53)` — conditional Agent(artifact-classifier) spawn when `classifier.needs_haiku==true`; merges whitelisted suggested_personas |
| 83 | `## Apply pre-spawn budget plan (BNCH-05, D-56)` — invokes bin/dc-budget-plan.sh, parses SPAWN_BENCH into BENCH_SPAWN_LIST |
| 108 | `## Apply --exclude filter to core personas (D-58)` — core filter; --exclude suppresses core; --only never narrows core |

**Bench fan-out replacement** (former line 87 `<!-- bench-personas ... -->` marker): replaced with a conditional fan-out block that issues Agent calls for each persona in BENCH_SPAWN_LIST in the SAME parallel turn as the 4 core personas. Documents the 4 supported bench persona drafts (`<slug>-draft.md`) and the `signal:<comma-joined-signal-ids>` trigger-reason contract passed to bin/dc-validate-scorecard.sh (BNCH-08).

**Render section extension** (`## Render all four scorecards inline`, ~line 509): added bench display name map, `N bench personas skipped: <persona> (<reason>)` one-line summary, and `Pre-spawn budget error: <code> — requested N personas, allowed M under cap $<cap_usd>.` line for cap_exceeded.

## Plan 05 preservation

- `## Reconcile Codex delegations (bench personas only)` — preserved at line 244 (intact)
- `## Render delegation status lines (CDEX-05 fail-loud)` — preserved at line 546 (intact)

Both sections verified via `grep -q` in the automated Task 3 verify clause.

## MANIFEST contract additions

Each `/devils-council:review` run now produces a MANIFEST with these new top-level blocks (on top of Phase 3/4/5 contents):

```json
{
  "classifier": {"version": 1, "deterministic_match_count": N, "needs_haiku": bool, "haiku_result"?: {...}},
  "triggered_personas": [...],
  "trigger_reasons": {"<slug>": ["<signal_id>", ...]},
  "budget": {
    "cap_usd": 0.50,
    "per_persona_estimate_usd": 0.08,
    "max_spawnable_bench": 6,
    "spawned_bench_count": 2,
    "skipped_personas": ["finops-auditor"],
    "actual_cost_usd": null,
    "over_budget": false,
    "errors": []
  },
  "personas_skipped": [{"persona": "finops-auditor", "reason": "budget_cap"}]
}
```

## Deviations from Plan

None — plan executed exactly as written. Bench priority order in config.json matches D-57 verbatim (no substitution).

### Auto-fixes (Rule 1-3) during execution

None. All three tasks hit their acceptance criteria on first run of each automated verify clause.

## Tests run after completion

- `bash scripts/test-budget-cap.sh` → **19 PASS / 0 FAIL** (exit 0)
- `bash scripts/test-classify.sh` → PASS (no regression; all pre-existing signal tests still pass)
- `bash scripts/test-codex-delegation.sh` → PASS (no regression; all 7 codex stubs still pass)

## Commits

| Task | Commit | Files |
|------|--------|-------|
| 1 | `3f9a14c` | config.json, bin/dc-budget-plan.sh, 3 fixtures |
| 2 | `b6d0734` | scripts/test-budget-cap.sh |
| 3 | `5443813` | commands/review.md |

## Self-Check: PASSED

- `config.json` — exists, `.budget.cap_usd == 0.50`, `.budget.bench_priority_order` length 4
- `bin/dc-budget-plan.sh` — exists, executable, `bash -n` clean
- `scripts/test-budget-cap.sh` — exists, executable, exit 0 with 19 PASS assertions
- `tests/fixtures/bench-personas/budget-classifier-{all-bench,one-bench,zero-bench}.json` — all 3 parse as valid JSON with required keys (classifier, triggered_personas, trigger_reasons)
- `commands/review.md` — 4 new H2 sections in correct position; bench marker replaced; BENCH_SPAWN_LIST referenced 7 times; argument-hint extended; Plan 05 sections preserved
- Commits `3f9a14c`, `b6d0734`, `5443813` all present in `git log`
