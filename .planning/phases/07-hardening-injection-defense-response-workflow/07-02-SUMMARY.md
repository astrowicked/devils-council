---
phase: 07-hardening-injection-defense-response-workflow
plan: 02
subsystem: engine/validator
tags: [hard-02, d-65, a10-dual-write, validator, drop-from-synthesis, stub-scorecard]
requires:
  - Phase 3 bin/dc-validate-scorecard.sh (single-pass pipeline, D-12 single-writer)
  - Phase 4 D-21 stub model (failure: frontmatter field)
  - Phase 5 D-38 finding-id stamping (unchanged)
  - Phase 5 D-43 Chair Missing Perspectives logic (unchanged — reads outcome)
provides:
  - HARD-02 zero-kept drop branch in bin/dc-validate-scorecard.sh
  - MANIFEST.validation[persona].dropped_from_synthesis conditional key (D-65 literal)
  - MANIFEST.personas_run[persona].outcome = "dropped_from_synthesis" (A10 dual-write)
  - scripts/test-dropped-scorecard.sh CI gate
affects:
  - Phase 5 D-43 Missing Perspectives (gains new outcome-enum case — handled via existing skip-list extension in commands/review.md Chair prompt, NOT required by this plan)
  - Any downstream Chair-iteration code reading personas_run[].outcome
tech-stack:
  added: []
  patterns:
    - jq conditional-key emission via `with_entries(select(.value != null))` (keeps happy-path MANIFESTs byte-identical)
    - Python3 + PyYAML stub writer (matches Phase 3 frontmatter-rewrite parser path)
key-files:
  created:
    - tests/fixtures/dropped-scorecard/INPUT.md
    - tests/fixtures/dropped-scorecard/all-findings-fail.md
    - scripts/test-dropped-scorecard.sh
  modified:
    - bin/dc-validate-scorecard.sh (+101 / -17 lines; 582 → 666 total)
decisions:
  - A10 dual-write: wrote D-65 literal (MANIFEST.validation[].dropped_from_synthesis) AND personas_run[].outcome (Chair-iteration helper). RESEARCH.md §A10 recommended defensive dual-write — applied verbatim.
  - Stub persona file shape matches Phase 4 D-21 (failure: frontmatter field) so Chair's Missing Perspectives logic (Phase 5 D-43) needs zero prompt changes this plan.
  - Dropped_from_synthesis key emitted conditionally (stripped when false via with_entries(select(.value != null))) — preserves MANIFEST byte-identity on the happy path, keeping the Phase 3-6 regression gate clean.
  - Normal path (kept > 0) and validly-silent path (kept == 0 AND dropped == 0) both take the existing atomic-swap branch with outcome: "success". Only (kept == 0 AND dropped > 0) triggers the stub.
metrics:
  duration: "~1.25h"
  tasks-completed: 3
  commits: 3
  files-created: 3
  files-modified: 1
  completed: 2026-04-23
---

# Phase 7 Plan 02: HARD-02 Zero-Kept Drop Branch Summary

HARD-02 closed: when a persona's scorecard finishes validation with every finding dropped, `bin/dc-validate-scorecard.sh` now writes a Phase 4 D-21 stub (`failure: "validation_all_findings_dropped"`) instead of a filtered frontmatter, and dual-writes `MANIFEST.validation[persona].dropped_from_synthesis: true` + `MANIFEST.personas_run[persona].outcome = "dropped_from_synthesis"`. Silent inclusion of malformed persona output is structurally impossible.

## Objective

Implement HARD-02 (T-07-02 mitigation): persona output that fails schema validation is dropped from synthesis with a structural error logged, not silently included. Chair's existing Missing Perspectives logic (Phase 5 D-43) picks this up unchanged via the outcome-enum extension, keeping the engine contract single-pass (ENGN-07 / D-15).

## What Shipped

### 1. Fixture: tests/fixtures/dropped-scorecard/ (Task 1)

- **`INPUT.md`** — 20-line neutral plan ("Rotate TLS certs on edge load balancers"). No banned phrases, no injection payloads. Exists solely so the validator's evidence-verbatim check has a corpus to match against.
- **`all-findings-fail.md`** — 3-finding staff-engineer draft engineered so every finding fails validation:
  - Finding 1 (`section-approach`): `claim` and `ask` contain `consider` → `banned_phrase_detected`.
  - Finding 2 (`section-risks`): `evidence` is a hand-crafted string absent from INPUT.md → `evidence_not_verbatim`.
  - Finding 3 (`section-rollout`): `claim` contains `think about` → `banned_phrase_detected`.

Mix exercises both drop_reasons the validator emits for the zero-kept case.

### 2. Validator extension: bin/dc-validate-scorecard.sh (Task 2)

Three additive edits, all gated on a single `HARD02_DROPPED` flag:

**Step 9.5 (new):** After step 9 computes the filtered frontmatter, check `KEPT_COUNT == 0 AND DROPPED_COUNT > 0`. If yes, set `HARD02_DROPPED=1` and write the stub scorecard via Python3 + PyYAML:

```yaml
---
persona: <slug>
findings: []
dropped_findings:
  - {id, reason, phrase}  # all N original findings with drop reasons
failure: validation_all_findings_dropped
---

## Summary

All findings from this persona failed validator checks. This scorecard
is structurally dropped from synthesis. See MANIFEST.validation[] for
drop reasons per finding.
```

Delete the draft file. The stub is the final file — no atomic swap needed.

**Step 10 (modified):** Guarded the existing atomic-swap block with `if [ "$HARD02_DROPPED" -eq 0 ]`. Normal path untouched.

**Step 11 VALIDATION_ENTRY (modified):** Added `--argjson dropped_from_syn "$HARD02_DROPPED"` + conditional jq key emission. `with_entries(select(.value != null))` strips the key when false — happy-path MANIFESTs stay byte-identical to pre-Phase-7.

**Step 11 personas_run[] (modified):** Added `outcome: $outcome` field (value: `"dropped_from_synthesis"` when `HARD02_DROPPED==1`, `"success"` otherwise). Dual-writes BOTH the D-65 literal (MANIFEST.validation[].dropped_from_synthesis) AND the A10 Chair-iteration helper (personas_run[].outcome) per RESEARCH.md recommendation.

### 3. Test: scripts/test-dropped-scorecard.sh (Task 3)

Prebuilt-run-dir harness that:

1. Copies the Task 1 fixture into a `mktemp -d` run dir.
2. Initializes a minimal MANIFEST.json matching `bin/dc-prep.sh`'s schema (with `personas_run[0].outcome: "pending"`).
3. Invokes `bin/dc-validate-scorecard.sh staff-engineer <run-dir> core:always-on`.
4. Asserts 8 PASS conditions:
   - validator exit 0
   - stub `staff-engineer.md` exists
   - draft file removed
   - stub frontmatter (failure / findings / dropped_findings) correct (PyYAML-parsed)
   - `MANIFEST.validation[0].dropped_from_synthesis == true`
   - `MANIFEST.validation[0].findings_kept == 0`
   - `MANIFEST.validation[0].findings_dropped == 3`
   - `MANIFEST.personas_run[0].outcome == "dropped_from_synthesis"`

RUN_DIRS cleanup trap; portable `shasum`/`sha256sum` shim.

## Clean-run Test Output

```
$ bash scripts/test-dropped-scorecard.sh
PASS: validator exited 0
PASS: stub <persona>.md exists
PASS: draft file removed by validator
PASS: stub frontmatter (failure + findings + dropped_findings) correct
PASS: MANIFEST.validation[0].dropped_from_synthesis == true
PASS: MANIFEST.validation[0].findings_kept == 0
PASS: MANIFEST.validation[0].findings_dropped == 3
PASS: MANIFEST.personas_run[0].outcome == dropped_from_synthesis
HARD-02 DROPPED-SCORECARD TEST: PASSED
```

## Regression Gates (all green)

| Test | Purpose | Result |
|------|---------|--------|
| `scripts/test-engine-smoke.sh` | Phase 3 engine integrity — Cases A-F including validator kept > 0 path, CHAIR-06 id stability | PASSED |
| `scripts/test-chair-synthesis.sh` | Phase 5 Chair + synthesis — Cases A-E including banned-token rejection, unresolvable-id rejection | PASSED |
| `scripts/validate-personas.sh` | Persona frontmatter schema | exit 0 (advisory warnings unrelated) |
| `bash -n bin/dc-validate-scorecard.sh` | Syntax check after edits | PASSED |

Happy-path MANIFESTs byte-identical to pre-Phase-7: confirmed via Case D (1 kept / 2 dropped) still asserting the unchanged `validation[0]` shape — no `dropped_from_synthesis` key appears (stripped by `with_entries(select(.value != null))`).

## Acceptance Grep Counts

```
validation_all_findings_dropped: 2    (min 1 — satisfies >=1)
dropped_from_synthesis:          5    (min 2 — satisfies >=2)
HARD02_DROPPED:                  7    (min 3 — satisfies >=3)
```

## Line Deltas

| File | +/- |
|------|-----|
| `bin/dc-validate-scorecard.sh` | +101 / -17 (582 → 666 total) |
| `scripts/test-dropped-scorecard.sh` | +178 (new) |
| `tests/fixtures/dropped-scorecard/INPUT.md` | +20 (new) |
| `tests/fixtures/dropped-scorecard/all-findings-fail.md` | +26 (new) |
| **Total** | +325 / -17 |

## Commits

| Hash | Message |
|------|---------|
| `3b817ed` | test(07-02): add dropped-scorecard fixture (HARD-02 Task 1) |
| `39e3823` | feat(07-02): add HARD-02 zero-kept drop branch to dc-validate-scorecard.sh |
| `618ae9a` | test(07-02): add test-dropped-scorecard.sh for HARD-02 zero-kept branch |

## Deviations from Plan

None (Rule 1-4) — plan executed as written. Two small translation notes:

1. **Plan verify grep used 6-space indent, fixture uses 2-space indent.** The plan's `<verify>` block for Task 1 used `^      - target:` (6 leading spaces) but those spaces were part of the markdown code-fence indentation, not the YAML content. My fixture uses the correct 2-space YAML list indent. Verified via `python3 yaml.safe_load` acceptance criterion — YAML parses clean. Not a deviation; the plan's grep pattern was a markdown-paste artifact.

2. **Step C ("outcome") scope clarification.** Task 2 Step C said "Wherever the existing code writes `outcome: "success"`…" — but the validator didn't previously write outcome at all (that's conductor's job in `commands/review.md`). I followed the spec's intent: added `outcome` as an additive field in the personas_run[] jq write, conditional on `HARD02_DROPPED`. Existing conductor-written outcome values (e.g., `"pending"`) are upgraded in-place to the terminal value. No conductor changes needed.

## Threat Register Coverage (Plan 07-02 threat_model)

| Threat ID | Status | Mitigation Delivered |
|-----------|--------|----------------------|
| T-07-02 | closed | HARD-02 branch writes stub with `failure: validation_all_findings_dropped`; MANIFEST dual-write signals Chair via existing D-43 path |
| T-07-12 | closed | Task 3 test asserts `failure`, `findings`, `dropped_findings` keys via PyYAML — stub shape matches Phase 4 D-21 + RESEARCH §6.3 exactly |
| T-07-13 | closed | `test-engine-smoke.sh` (kept > 0 regression) + `test-dropped-scorecard.sh` (kept == 0 specific) — both green |
| T-07-14 | closed | Stub's `dropped_findings:` list preserves every dropped entry with drop_reason; MANIFEST.validation[].drop_reasons same |

## Follow-ups / Downstream Hooks

- **Phase 5 Chair skip-list extension** is NOT required by this plan because this plan dual-wrote `personas_run[].outcome = "dropped_from_synthesis"` (A10). Chair's existing prompt language (`commands/review.md` lines 465+, "outcome is NOT `failed_missing_draft` or `failed_validator_error`") already excludes failed-prefix entries; `dropped_from_synthesis` is a new enum value that future Plan 07 or Phase 5 amendment should add to the skip-set. Scoped out of THIS plan per acceptance criteria — Chair prompt changes not listed as a deliverable. Flagged here for the next planner.
- Phase 7 injection corpus (Plan 07-01, HARD-01) can leverage this path: a persona that emits `category: prompt_injection` findings with paraphrased evidence will have findings dropped → HARD-02 branch writes stub → pass under D-67 criterion 3.

## Known Stubs

None. The HARD-02 stub `<persona>.md` itself is the product (not an unresolved stub): it is intentional per D-65, structurally required for Chair, and exercised by Task 3's test.

## Self-Check: PASSED

Verified all claims before acceptance:

- `tests/fixtures/dropped-scorecard/INPUT.md` — FOUND
- `tests/fixtures/dropped-scorecard/all-findings-fail.md` — FOUND
- `scripts/test-dropped-scorecard.sh` — FOUND, executable
- `bin/dc-validate-scorecard.sh` — contains `validation_all_findings_dropped` (2x), `dropped_from_synthesis` (5x), `HARD02_DROPPED` (7x)
- Commit `3b817ed` — FOUND
- Commit `39e3823` — FOUND
- Commit `618ae9a` — FOUND
- `bash scripts/test-dropped-scorecard.sh` — exit 0, 8 PASS lines
- `bash scripts/test-engine-smoke.sh` — exit 0
- `bash scripts/test-chair-synthesis.sh` — exit 0
- `bash scripts/validate-personas.sh` — exit 0
