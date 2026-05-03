---
phase: 02-codex-output-schema-spike
plan: 02-01
requirement: CODX-01
executed: 2026-04-25
commit: 2971eab
verdict: WRAPPER
validation_rate: 0.857
latency_ratio: 0.635
status: complete
---

# Plan 02-01 — Codex `--output-schema` Spike: Summary

## One-liner

Ran 21 real Codex invocations across 7-item corpus × 3 modes; verdict = **WRAPPER** (schema enforcement adopted behind strict-mode pre-check with unstructured fallback); schema runs 1.57× faster than unstructured at p50.

## What Shipped

**Git-tracked (committed in `2971eab feat(codex-spike): TD/CODX-01 Codex --output-schema spike harness + memo`):**
- `templates/codex-security-schema.json` — v1 Security scorecard schema, OpenAI strict-mode compatible (47 lines)
- `scripts/test-codex-schema-spike.sh` — 3-mode × 7-item spike harness (324 lines)

**Local-only (gitignored per `commit_docs: false`):**
- `.planning/research/CODEX-SCHEMA-MEMO.md` — verdict memo with aggregated metrics, findings, Phase 6 Wiring Rubric (reconstructed after worktree artifact loss; see Deviations below)
- `.planning/phases/02-codex-output-schema-spike/02-01-SUMMARY.md` — this file

**Not retained (worktree artifact loss):**
- `.planning/research/codex-schema-spike-runs.jsonl` — per-run raw data (21 lines)
- `.planning/research/spike-fixtures/item-0{1..7}-prompt.txt` — corpus prompts
- `.planning/research/spike-fixtures/item-07-adversarial-schema.json` — adversarial union schema variant
- `.planning/research/spike-fixtures/corpus-manifest.md` — corpus manifest

See "Deviations — Workflow Fix Required" below for root cause and mitigation.

## Verdict

**WRAPPER**: Adopt `codex exec --output-schema` in Phase 6 behind a strict-mode pre-check + unstructured-fallback wrapper.
- schema_validation_rate: 0.857 (6/7 — item 7 adversarial union schema rejected at submit, which is a schema-authoring constraint, not a validation failure)
- latency_ratio (with_schema p50 / wrapped_no_schema p50): 0.635 (schema is FASTER than unstructured)

Per ROADMAP SC-2 rubric:
- GO threshold: validation > 0.95 AND latency < 1.25 → not met (validation 0.857 < 0.95)
- NO-GO threshold: validation < 0.80 OR latency > 2.0 → not met (neither triggered)
- WRAPPER (between): correct verdict

## Key Findings

1. **OpenAI strict structured-outputs has a JSON Schema subset** — v1 schema rejected on first submit; stripped `default`, `minLength`, `format`, `pattern`, optional properties to get acceptance. Phase 6 must enforce this subset in schema linting.
2. **Adversarial item 7 (`oneOf` on `evidence` field) rejected at schema-submit (HTTP 400, <5s)** — proves the need for a `codex_schema_invalid` error class separate from `codex_schema_validation_error`.
3. **Item 5 (Helm values diff, content-heavy) returned YAML-not-JSON on unstructured modes** — `--output-schema` eliminates this failure mode entirely when the schema is submittable.
4. **Schema mode is faster than unstructured** — p50 latency 0.635× wrapped baseline. Structured output skips markdown fencing and hedges; model emits only declared fields.

See CODEX-SCHEMA-MEMO.md for full details and Phase 6 Wiring Rubric.

## Tasks Executed

| # | Task | Status |
|---|---|---|
| 1 | Write v1 JSON Schema at `templates/codex-security-schema.json` | ✓ (stripped to strict-mode subset during spike) |
| 2 | Assemble 7-item corpus + write 7 prompt files | ✓ (fixtures not retained — see Deviations) |
| 3 | Write 21-invocation harness `scripts/test-codex-schema-spike.sh` | ✓ |
| 4 | Execute spike — 21 real Codex invocations | ✓ (918s wall-clock) |
| 5 | Analyze JSONL, write CODEX-SCHEMA-MEMO.md with verdict | ✓ (memo reconstructed after artifact loss) |
| 6 | Commit tracked artifacts (schema + harness only) | ✓ (commit 2971eab, 2 files, 371 insertions) |

## Success Criteria Check (ROADMAP Phase 2 SC)

| SC | Requirement | Status |
|---|---|---|
| SC-1 | Memo exists with pinned codex-version, v1 schema at templates/, 5+ delegation measurements | ✓ Memo present; 21 invocations (exceeds 5+); schema + version pinned |
| SC-2 | Unambiguous verdict (GO/NO-GO/WRAPPER) | ✓ WRAPPER, rubric-grounded |
| SC-3 | If NO-GO: documented reasons + v1.0 path preserved | N/A (verdict = WRAPPER, not NO-GO) |
| SC-4 | If GO or WRAPPER: Phase 6 Wiring Rubric with feature-detect, fallback, error-class | ✓ Full rubric in memo: feature-detect on version, strict-mode pre-check, unstructured fallback, 2 new error classes (`codex_schema_invalid`, `codex_schema_validation_error`) |

## Deviations

### 1. Worktree artifact loss (gitignored `.planning/` data)

**What happened:** During worktree cleanup after merge, `git worktree remove --force --force` deleted gitignored files in the worktree's `.planning/` tree. The memo, JSONL, and 8 spike-fixture files were lost. Tracked artifacts (schema + harness, in git) survived.

**Root cause:** `commit_docs: false` gitignores `.planning/**`. Worktree isolation + force-removal = gitignored artifacts die with the worktree.

**Impact:**
- Verdict and metrics preserved (captured in agent return → reconstructed memo)
- Per-run JSONL detail lost (moderate impact; useful for future edge-case debugging, not required for Phase 6 decisioning)
- Corpus prompt files lost (spike is one-shot; not needed again unless re-running)

### 2. Workflow Fix Required: Preserving Gitignored Worktree Artifacts

**Problem pattern:** Any GSD phase that produces `.planning/**` deliverables (memos, JSONL, research docs) from within an executor worktree will lose those artifacts when `commit_docs: false` is set and the worktree is force-removed.

**Affected phases going forward:** Any phase writing to `.planning/research/`, `.planning/phases/*/SUMMARY.md`, `.planning/phases/*/VERIFICATION.md`, or similar — if produced inside a worktree rather than on main.

**Recommended orchestrator fix** (for execute-phase.md § worktree_cleanup step):

Before `git worktree remove --force`:
```bash
# Snapshot gitignored .planning/ artifacts from worktree before deletion
WT_PLANNING="$WT/.planning"
if [ -d "$WT_PLANNING" ]; then
  # Copy gitignored artifacts back to main's .planning/ tree
  # Use rsync to preserve directory structure; exclude tracked files (already merged)
  rsync -av --ignore-existing "$WT_PLANNING/" ".planning/" 2>/dev/null || true
fi
git worktree remove "$WT" --force --force
```

The `--ignore-existing` flag ensures we don't overwrite files that were merged via git. Gitignored files (only present in worktree) get copied to main. Tracked files stay as-merged.

**Alternative (simpler):** Executors that produce gitignored `.planning/**` artifacts should be instructed to ALSO `cp` their outputs to the main repo's `.planning/` tree before declaring completion. Put the responsibility on the executor rather than the orchestrator.

**Long-term:** Consider adding a `<preserve_gitignored>` directive to executor contracts, which would trigger the copy-before-remove pattern automatically in the orchestrator cleanup step.

### 3. Corpus item 1-3 redirect (planner-handled during planning)

CONTEXT.md D-01 referenced `tests/fixtures/codex-delegation/*` which doesn't exist in the tree. Planner redirected items 1-3 to `tests/fixtures/bench-personas/*`. Documented in plan Task 2 and in memo Execution Notes. No impact.

## Goal-Backward: Phase 6 Unblocking

Phase 6 now has everything it needs to proceed:
- **If Phase 6 goes ahead:** Schema file (`templates/codex-security-schema.json`) and harness pattern exist; memo Phase 6 Wiring Rubric section provides concrete feature-detect + fallback + error-class design.
- **If Phase 6 is deferred:** v1.0 path is unchanged; memo documents WRAPPER verdict as the path when Phase 6 does execute.
- **Schema discipline captured:** Future schemas (Compliance, Dual-Deploy, etc.) must follow the strict subset rules in memo § "Schema discipline going forward".

## No Regression Check

- `bin/dc-codex-delegate.sh` — not touched in this phase; git shows it byte-identical to pre-phase state.
- `agents/security-reviewer.md` — not touched.
- `bin/dc-validate-scorecard.sh` — not touched.
- All Phase 1 tests still green (validate-personas, test-shell-inject, test-chair-strictness, test-chair-synthesis).
- `claude plugin validate .` passes.

## Self-Check: PASSED
