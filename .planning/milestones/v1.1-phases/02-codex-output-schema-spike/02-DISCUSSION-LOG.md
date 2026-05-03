# Phase 2: Codex `--output-schema` Spike - Discussion Log

> **Audit trail only.** Decisions captured in 02-CONTEXT.md — this log preserves alternatives considered.

**Date:** 2026-04-25
**Phase:** 02-codex-output-schema-spike
**Areas discussed:** Delegation corpus, Schema shape, Baseline latency, Measurement retention

---

## Area 1: Delegation corpus

### Q1.1 — Corpus composition

| Option | Content | Selected |
|--------|---------|----------|
| A. Synthetic minimal | 5 hand-crafted snippets | |
| B. Real-world diverse | 5 v1.0 fixtures + 2-3 anaconda-platform-chart diffs | |
| C. Adversarial | B + 2-3 pathological (depth, unions) | |
| **B-hybrid** (recommended mid-ground) | **3 v1.0 fixtures + 2 anaconda-platform-chart diffs + 2 adversarial = 7 items** | ✓ |

**User's choice:** B-hybrid
**Rationale:** Keeps corpus ~7 items, above the 5+ floor. Gets adversarial stress-test on exactly the features STACK.md §Q1 flagged MEDIUM-confidence (unions, depth) without C's full pathological set.

---

## Area 2: Schema shape

### Q2.1 — Strictness

| Option | Shape | Selected |
|--------|-------|----------|
| A. Minimal | `findings[]` of `{target, claim, evidence}` only | |
| B. Mirror v1.0 scorecard contract | Full shape: target, claim, evidence, ask, severity enum, category | ✓ |
| C. Strict + future-proof | B + finding_id hash + nested evidence_location | |

**User's choice:** B
**Rationale:** Measure the exact production shape Phase 6 would ship. Adding finding_id or evidence_location is v1.1 scope creep baked into spike.

---

## Area 3: Baseline latency measurement

### Q3.1 — What baseline(s)?

| Option | Baseline | Selected |
|--------|----------|----------|
| A. Current v1.0 wrapped path only | `bin/dc-codex-delegate.sh` as-is | |
| B. Stripped codex exec only | Bare `codex exec --json --sandbox read-only` | |
| C. Both | Measure both — wrapped + stripped | ✓ |

**User's choice:** C
**Rationale:** Runtime cost is trivial (~3x = still <4min total). Separating wrapper overhead from Codex-side overhead prevents false NO-GO when wrapper is the dominant cost (wrapper fix = Phase 6 ticket, not Phase 2 blocker).

---

## Area 4: Measurement retention

### Q4.1 — Where do raw results live?

| Option | Storage | Selected |
|--------|---------|----------|
| A. Inline tables in memo only | No raw data | |
| B. Memo + JSONL | Aggregated memo + `.planning/research/codex-schema-spike-runs.jsonl` with per-run raw data | ✓ |
| C. Full artifacts | B + one file per Codex response under spike-raw/ | |

**User's choice:** B
**Rationale:** JSONL fidelity is right — enough to re-analyze without re-invoking Codex (saves API cost) and small enough to attach to follow-up issues. 21-file directory is overkill.

---

## Claude's Discretion

- Exact prompt wording per corpus item
- Spike fixture directory location (`tests/fixtures/codex-schema-spike/` vs `.planning/research/spike-fixtures/`)
- Spike harness script name (suggest `scripts/test-codex-schema-spike.sh`)
- Whether to add error-handling corpus items if interesting during first 3-5 runs
- Additional JSONL debug fields beyond the 12 in D-11

## Deferred Ideas

- `finding_id` hash in schema (Q2 Option C) → v1.2 if Phase 6 surfaces need
- Full artifact retention per response (Q4 Option C) → rejected, JSONL sufficient
- Minimal synthetic corpus (Q1 Option A) → rejected, weak external validity
- Feature-detect fallback, MANIFEST error enum, dc-codex-delegate.sh rollout → all Phase 6 scope
