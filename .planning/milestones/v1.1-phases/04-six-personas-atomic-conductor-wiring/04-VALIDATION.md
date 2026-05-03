---
phase: 04
slug: six-personas-atomic-conductor-wiring
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-28
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Plain bash test scripts (no formal framework) |
| **Config file** | None — each `scripts/test-*.sh` is standalone |
| **Quick run command** | `./scripts/validate-personas.sh` |
| **Full suite command** | `./scripts/validate-personas.sh && ./scripts/test-chair-synthesis.sh && ./scripts/test-blinded-reader.sh` |
| **Estimated runtime** | ~15 seconds (validator) + ~5 seconds (chair fixture) + ~30 seconds (blinded-reader LLM call) |

---

## Sampling Rate

- **After every task commit:** `./scripts/validate-personas.sh`
- **After every plan wave:** Full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 50 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-xx | 01 | 1 | BNCH2-01 | — | Persona YAML frontmatter validated | unit | `./scripts/validate-personas.sh agents/compliance-reviewer.md` | ❌ W1 | ⬜ pending |
| 04-02-xx | 02 | 1 | BNCH2-02 | — | Persona YAML frontmatter validated | unit | `./scripts/validate-personas.sh agents/performance-reviewer.md` | ❌ W1 | ⬜ pending |
| 04-03-xx | 03 | 1 | BNCH2-03 | — | Persona YAML frontmatter validated | unit | `./scripts/validate-personas.sh agents/test-lead.md` | ❌ W1 | ⬜ pending |
| 04-04-xx | 04 | 1 | BNCH2-04 | — | Persona YAML frontmatter validated | unit | `./scripts/validate-personas.sh agents/executive-sponsor.md` | ❌ W1 | ⬜ pending |
| 04-05-xx | 05 | 1 | BNCH2-05 | — | Persona YAML frontmatter validated | unit | `./scripts/validate-personas.sh agents/competing-team-lead.md` | ❌ W1 | ⬜ pending |
| 04-06-xx | 06 | 1 | CORE-EXT-01 | — | Persona YAML frontmatter validated | unit | `./scripts/validate-personas.sh agents/junior-engineer.md` | ❌ W1 | ⬜ pending |
| 04-07-xx | 07 | 2 | SC-1, SC-5 | — | Bench whitelist atomic, core cardinality=4 | smoke | `grep -c` assertions on review.md + persona-metadata | ❌ W2 | ⬜ pending |
| 04-08-xx | 08 | 3 | PQUAL-01 | — | Voice overlap <40% banned / <30% objection | unit | `./scripts/validate-personas.sh` (extended) | ❌ W3 | ⬜ pending |
| 04-08-xx | 08 | 3 | PQUAL-02 | — | Adversarial fixture fails on banned nominalization | integration | CI step in `.github/workflows/ci.yml` | ❌ W3 | ⬜ pending |
| 04-08-xx | 08 | 3 | PQUAL-03 | — | Blinded-reader >=80% attribution | integration | `./scripts/test-blinded-reader.sh` | ❌ W3 | ⬜ pending |
| 04-08-xx | 08 | 3 | SC-6 | — | Chair <=5 contradictions at 10-persona scale | integration | `./scripts/test-chair-synthesis.sh` (extended) | ❌ W3 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] No new test framework install needed — existing bash scripts pattern continues
- [ ] `tests/fixtures/exec-sponsor-adversarial/` — adversarial temptation artifact (Wave 3 creates)
- [ ] `tests/fixtures/blinded-reader/` — multi-signal synthetic fixture (Wave 3 creates)
- [ ] `tests/fixtures/chair-strictness/` — 6 new scorecard files for 10-persona fixture (Wave 3 extends)
- [ ] `scripts/test-blinded-reader.sh` — LLM-as-judge evaluation script (Wave 3 creates)
- [ ] Voice-distinctness overlap check in `scripts/validate-personas.sh` (Wave 3 extends)

*Existing infrastructure covers Wave 1 and Wave 2 requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Voice quality subjective assessment | PQUAL-03 | LLM-as-judge automation supplements but doesn't replace human reading of persona output | Read 2-3 scorecards per persona; verify voice is distinct and domain-appropriate |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 50s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
