# Phase 1: Tech-Debt Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 01-CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-24
**Phase:** 01-tech-debt-foundation
**Areas discussed:** Shell-inject pre-parser strictness, Adversarial fixture design, Chair strictness regex scope, Plan order + parallelization, TD-01/02/03 evidence citations

---

## Area 1: Shell-inject pre-parser strictness (TD-04)

### Q1.1 — Hook behavior on unexpected `!<cmd>` patterns

| Option | Behavior | Selected |
|--------|----------|----------|
| A. Hard-block | PreToolUse hook exits 1; author must fix or allowlist | ✓ |
| B. Warn-only | Hook logs, exits 0; CI catches at merge time | |
| C. Hybrid | Hard-block outside fenced code blocks; warn inside | |

**User's choice:** A (hard-block)
**Notes:** Matches existing persona-validator hook discipline; v1.0.0 P0 is exactly the class where warn-only would have shipped the bug.

### Q1.2 — Allowlist mechanism

| Option | Mechanism | Selected |
|--------|-----------|----------|
| File-based | `scripts/shell-inject-allowlist.txt` with filepath:line:pattern | ✓ (both) |
| Inline comment | `<!-- dc-shell-inject-ok: reason -->` marker above intentional uses | ✓ (both) |
| Both | File for ship-time known-good + inline for per-occurrence context | ✓ |

**User's choice:** Both
**Notes:** File is greppable + PR-reviewable; inline marker documents *why* at the occurrence.

---

## Area 2: Adversarial fixture design (TD-04 + TD-05)

### Q2.1 — Fixture scope

| Option | Content | Selected |
|--------|---------|----------|
| A. Minimal | 1 regression fixture each for TD-04/TD-05 | |
| B. Extended | 3-5 fixtures per TD covering edge cases | ✓ |
| C. Evolvable | Extended + `tests/fixtures/td-regression/` meta-dir | |

**User's choice:** B (extended)
**Notes:** Worth the hour it adds; catches edge classes the audit flagged. C's meta-dir is YAGNI until v1.2 surfaces a third class.

### Q2.2 — Fixture directory layout

| Option | Layout | Selected |
|--------|--------|----------|
| Separate | `tests/fixtures/shell-inject/` + `tests/fixtures/chair-strictness/` | ✓ |
| Together | `tests/fixtures/td-regression/` (= Q2.1 option C) | |

**User's choice:** Separate
**Notes:** Matches v1.0 convention (one subdir per regression class); each gets own test runner.

---

## Area 3: Chair strictness regex scope (TD-05)

### Q3.1 — Enforcement layer

| Option | Mechanism | Selected |
|--------|-----------|----------|
| A. Pure validator regex | Validator rejects composites; Chair prompt unchanged | |
| B. Pure prompt | Forbidden-language line in Chair prompt only; no validator check | |
| C. Prompt + validator backstop | Both layers; defense in depth | ✓ |

**User's choice:** C
**Notes:** Matches v1.0 banned-phrase discipline (prompt + validator). LLM self-enforcement alone isn't reliable under budget pressure.

### Q3.2 — Validator composite-target threshold

| Option | Regex | Selected |
|--------|-------|----------|
| Strict | `\s+(and|&|/|,|\|)\s+` — catches everything, false-positives "client/server" | |
| Medium | `\s+(and|or)\s+\w+` + `,\s*\w+,\s*\w+` — catches "A and B"/"A,B,C" only | ✓ |
| Lenient | Only 3+ comma-separated items | |

**User's choice:** Medium
**Notes:** Strict creates false-positives on legit names; lenient misses common "A and B" failures.

### Q3.3 — Remediation on rejection

| Option | Behavior | Selected |
|--------|----------|----------|
| Fail synthesis (bare) | Exit 1, generic error | |
| Drop silently, pick next candidate | Log drop, continue | |
| Fail with diagnostic hint | Exit 1 with message naming entry + target | ✓ |

**User's choice:** Fail with hint
**Notes:** Silent drop masks problems; hint makes it debuggable. Matches v1.0 fail-loud pattern.

---

## Area 4: Phase 1 plan order + parallelization

### Q4.1 — Sequencing strategy

| Option | Structure | Selected |
|--------|-----------|----------|
| A. All parallel | 7 TD plans, no gates | |
| B. TD-04 smoke-first, rest parallel | Validate highest-risk first | |
| C. Smart sequencing (3 batches) | Doc batch → structural batch → isolated TD-05 | ✓ |
| D. Strict sequential | 7 TD plans, fully ordered | |

**User's choice:** C
**Notes:** Respects real dependencies; docs unblock fast; TD-05 gets isolated attention so any Chair regression is attributable.

### Q4.2 — Batch 1 commit granularity

| Option | Commits | Selected |
|--------|---------|----------|
| One commit | `docs(01-batch-1): close TD-01/02/03/07 tracking debt` | ✓ |
| Separate commits | One per TD item | |

**User's choice:** One commit
**Notes:** Doc-only, tightly related, all retroactive flips. Blame granularity not meaningfully better with 4 commits.

### Q4.3 — TD-04 hook shipping posture

| Option | Config | Selected |
|--------|--------|----------|
| Ship enabled, no opt-out | Hook always on | |
| Default-true `userConfig.shell_inject_guard` | Opt-out available | ✓ |
| Ship disabled; user opts in | Conservative rollout | |

**User's choice:** Default-true userConfig flag
**Notes:** Safe default + v1.0 configurability precedent + escape hatch if parser regresses.

---

## Area 5: TD-01/02/03 evidence citations

### Q5.1 — Evidence discipline

| Option | TD-01/02/03 approach | Selected |
|--------|---------------------|----------|
| A. Liberal (all) | Release chain + 08-UAT citations, flip all three | |
| B. Conservative (all) | Re-run full verification for each | |
| C. Hybrid | Liberal for TD-01/02; conservative re-run for TD-03 | ✓ |

**User's choice:** C (hybrid)
**Notes:** TD-01 marketplace install objectively tested by every user; TD-02 superseded by Phase 7 PQUAL-03 scope; TD-03 Nyquist re-run is cheap and produces clean audit artifact.

### Q5.2 — Citation location

| Option | Where | Selected |
|--------|-------|----------|
| Edit archived files in place | Flip `.planning/milestones/v1.0-phases/*` directly | |
| Leave archives; note in 01-SUMMARY | Historical preservation | |
| Both | Archive flip + SUMMARY note | ✓ |

**User's choice:** Both
**Notes:** Archives are source of truth for audit status; SUMMARY provides v1.1 traceability. `commit_docs: false` means no git impact either way.

---

## Claude's Discretion

- Exact regex syntax for composite-target detection (honor D-06's medium threshold)
- Exact fixture file contents (representative of regression classes; each fixture has 1-2 sentence comment explaining what it tests)
- `userConfig.shell_inject_guard` JSON schema shape (mirror v1.0 `userConfig.gsd_integration`)
- Exact Chair forbidden-language example wording

## Deferred Ideas

- `tests/fixtures/td-regression/` meta-directory (Q2.1 C / Q2.2 B) — revisit at v1.2 if third regression class emerges
- Pure-prompt TD-05 enforcement (Q3.1 B) — rejected; LLM self-enforcement insufficient
- Warn-only TD-04 (Q1.1 B) — rejected; would have shipped v1.0.0 P0
- Per-TD commits for Batch 1 (Q4.2 separate) — rejected for doc-only batch
- Strict sequential Phase 1 plan order (Q4.1 D) — rejected as over-cautious
