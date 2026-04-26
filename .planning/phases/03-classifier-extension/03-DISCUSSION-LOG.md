# Phase 3: Classifier Extension - Discussion Log

> **Audit trail only.** Decisions captured in 03-CONTEXT.md — this log preserves alternatives considered.

**Date:** 2026-04-25
**Phase:** 03-classifier-extension
**Areas discussed:** Haiku whitelist scope, signal strength mechanics, signal strength assignments, artifact_type plumbing, negative-fixture directory

---

## Area 1: Haiku whitelist scope (CLS-06)

Conflict: ROADMAP SC-4 says "expand from 4 to 8 bench slugs" but v1.1 adds 5 new bench personas (9 total signal-triggered). Which persona excluded?

| Option | Whitelist | Selected |
|--------|-----------|----------|
| **A. 8 slugs; exec-sponsor excluded** | 4 existing + 4 new minus exec-sponsor | ✓ |
| B. 9 slugs (SC-4 incorrect) | All 4 existing + all 5 new | |
| C. 8 slugs; competing-team-lead excluded | 4 existing + 4 new minus competing-team-lead | |

**User's choice:** A (accept recommendation)
**Rationale:** Executive Sponsor's `artifact_type` gate limits it to plan|rfc|design; Haiku fires on zero-structural-match runs. Exec-sponsor can't validly fire via Haiku anyway. Also mitigates PITFALLS P-11 (exec-sponsor register drift) by keeping it signal-driven-only.

---

## Area 2: Signal strength mechanics (CLS-02)

How does "weak signal requires 2+ distinct hits" work?

| Option | Mechanism | Selected |
|--------|-----------|----------|
| A. Same detector, 2+ evidence items | Detector must find ≥2 pieces of evidence in one artifact | |
| B. 2+ distinct detectors target same weak persona | Cross-detector hit count | |
| **C. `min_evidence` field per signal** | Each signal has min_evidence; strong=1, weak=2+ | ✓ |

**User's choice:** C (accept recommendation)
**Rationale:** Explicit per-signal, no spooky action between detectors, configurable during tuning.

---

## Area 3: Signal strength assignments

5 new signals classified with defaults (executor may tune during testing):

| Signal | Strength | min_evidence | Selected |
|--------|----------|--------------|----------|
| compliance_marker | moderate | 2 | ✓ |
| performance_hotpath | moderate | 2 | ✓ |
| test_imbalance | strong | 1 | ✓ |
| exec_keyword | weak | 2 (+ artifact_type gate) | ✓ |
| shared_infra_change | strong | 1 | ✓ |

**User's choice:** Accept defaults
**Rationale:** Mix of noisiness-per-signal; executor can tune during negative-fixture testing if strong false-positives.

---

## Area 4: artifact_type parameter propagation (CLS-03)

| Option | Signature | Selected |
|--------|-----------|----------|
| A. Positional arg | `classify(text, filename_hint, artifact_type)` | |
| **B. Keyword-only with default** | `classify(text, filename_hint, *, artifact_type="code-diff")` | ✓ |
| C. Via MANIFEST side-channel | Read inside classify() | |

**User's choice:** B (accept recommendation)
**Rationale:** Backward-compatible with v1.0 callers; `*` forces keyword-only for safety. Matches CLS-03's "backward-compatible with v1.0 detectors" requirement.

---

## Area 5: Negative-fixture directory

| Option | Strategy | Selected |
|--------|----------|----------|
| A. Greenfield | Write 15 new benign artifacts from scratch | |
| **B. Mix** | Scan bench-personas fixtures for keyword-incidental matches; fill gaps | ✓ |

**User's choice:** B (accept recommendation)
**Rationale:** Cheap, reuses validated fixtures. Planner/executor scans existing tests/fixtures/bench-personas/* during implementation.

---

## Claude's Discretion

- Exact regex patterns per detector (within STACK.md §Q5 guidance)
- Exact rationale-comment wording for bench_priority_order
- Rationale format: JSON comments via `_comment_*` keys vs sidecar markdown (suggested: `_comment_*` keys in config.json)
- Specific fixtures to reuse as negatives (D-15 starting suggestions only)
- Negative-fixture filenames (suggested pattern: `{detector}-benign-{N}.{ext}`)

## Deferred Ideas

- JSON Schema for signals.json itself → v1.2 bonus
- `design` artifact_type detection in dc-prep.sh → future phase (v1.1 gates exec_keyword to plan|rfc only)
- Cross-detector hit-count rule (Q2 B) → rejected
- Greenfield-only negative fixtures (Q5 A) → rejected
- executive-sponsor in Haiku whitelist (Q1 B) → rejected
- Junior Engineer in bench_priority_order → explicitly excluded (always-invokable, not signal-driven)
