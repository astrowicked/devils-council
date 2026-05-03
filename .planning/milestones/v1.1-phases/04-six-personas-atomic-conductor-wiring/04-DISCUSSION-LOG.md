# Phase 4: Six Personas + Atomic Conductor Wiring - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-28
**Phase:** 04-six-personas-atomic-conductor-wiring
**Areas discussed:** Persona authoring strategy, Junior Engineer wiring, Voice-distinctness validation, Blinded-reader evaluation, Conductor atomic wiring, Adversarial Exec Sponsor fixture, Chair synthesis at 9-persona scale

---

## Persona Authoring Strategy

### Batching

| Option | Description | Selected |
|--------|-------------|----------|
| One plan per persona | 6 persona plans + 1 conductor-wiring plan + 1 fixtures plan = 8 plans. Most parallelizable. | ✓ |
| Group by complexity tier | 3 plans: straightforward trio, research-heavy duo, Junior Eng alone. Fewer plans. | |
| Two waves only | Wave 1: all 6 parallel. Wave 2: conductor + fixtures. Maximally parallel but heavier per plan. | |

**User's choice:** One plan per persona (Recommended)

### Compliance Research

| Option | Description | Selected |
|--------|-------------|----------|
| Inline in persona plan | Executor reads citations and embeds directly. No separate research phase. | ✓ |
| Separate research plan first | Dedicated 04-00 research plan produces reference doc. | |
| Hardcode starter set | Ship with 4-5 well-known citations, expand in v1.2. | |

**User's choice:** Inline in the persona plan (Recommended)

### Executive Sponsor Iteration Budget

| Option | Description | Selected |
|--------|-------------|----------|
| One iteration pass | Author + fixture test. Fix once. Ship what works, note issues for v1.1.1. | ✓ |
| Two iteration passes | Explicit re-test after first fix. Higher confidence. | |
| Defer to v1.1.1 proactively | Skip Exec Sponsor entirely in Phase 4. | |

**User's choice:** One iteration pass (Recommended)

---

## Junior Engineer Wiring

### Conductor Detection

| Option | Description | Selected |
|--------|-------------|----------|
| New sidecar field: always_invoke_on | Declarative, extensible. Conductor reads field in budget-plan. | ✓ |
| Hardcode in conductor | Special-case code path. Simpler but doesn't generalize. | |
| Classify as core-adjacent | New tier between core and bench. Clean but changes semantics. | |

**User's choice:** New sidecar field: always_invoke_on (Recommended)

### Budget Treatment

| Option | Description | Selected |
|--------|-------------|----------|
| Bypass budget cap | Runs outside budget system like core. Consistent with D-12. | ✓ |
| Count against bench budget | Competes with signal-triggered personas. | |
| Separate budget line | New category for always-invoke. Overkill for one persona. | |

**User's choice:** Bypass budget cap (Recommended)

---

## Voice-Distinctness Validation

### Baseline Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Exclude baseline from overlap calc | Subtract shared baseline phrases before comparing. | ✓ |
| Include baseline, raise threshold | Count all phrases but raise threshold to 55%. | |
| Per-pair exemption list | Config file for expected overlaps. Most flexible. | |

**User's choice:** Exclude baseline from overlap calc (Recommended)

### Severity Mode

| Option | Description | Selected |
|--------|-------------|----------|
| Warn-mode only | Per ROADMAP SC-3. Visibility without blocking. | ✓ |
| Block on >60%, warn on >40% | Two thresholds. More aggressive. | |

**User's choice:** Warn-mode only (Recommended)

---

## Blinded-Reader Evaluation

### Method

| Option | Description | Selected |
|--------|-------------|----------|
| LLM-as-judge with golden key | Automated, reproducible, no human in loop. | ✓ |
| Human evaluation | Gold standard but not automatable. | |
| Hybrid: LLM screening + human spot-check | Most thorough but most expensive. | |

**User's choice:** LLM-as-judge with golden key (Recommended)

### Test Artifact

| Option | Description | Selected |
|--------|-------------|----------|
| Synthetic multi-signal fixture | Purpose-built, triggers all 9 signals. Deterministic. | ✓ |
| Real artifact (anaconda-platform-chart) | Most realistic but non-deterministic. | |
| Both: synthetic for Phase 4, real for Phase 7 | Best coverage across phases. | |

**User's choice:** Synthetic multi-signal fixture (Recommended)

---

## Conductor Atomic Wiring

### Sequencing

| Option | Description | Selected |
|--------|-------------|----------|
| All 6 personas first, then atomic wiring | Wave 1: personas. Wave 2: conductor wiring as single commit. | ✓ |
| Persona + wiring interleaved | Each plan updates whitelist incrementally. Contradicts SC-1. | |
| Wiring first (stub personas) | Placeholder files first. May confuse validator. | |

**User's choice:** All 6 personas first, then atomic wiring (Recommended)

### JE in Wiring Plan

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, bundle in conductor plan | One plan owns all conductor changes (whitelist + always_invoke_on). | ✓ |
| Separate JE-wiring plan | Cleaner isolation but adds another plan. | |

**User's choice:** Yes, bundle in conductor plan (Recommended)

---

## Adversarial Exec Sponsor Fixture

| Option | Description | Selected |
|--------|-------------|----------|
| One temptation artifact + two assertions | Minimal but proves discipline. CI FAIL on nominalizations, PASS on findings: [] or cited number. | ✓ |
| Three-artifact gradient | Three temptation levels. More coverage but 3x work. | |
| Inline in persona plan | No separate fixture plan. Mixes authoring with CI fixture. | |

**User's choice:** One temptation artifact + two assertions (Recommended)

---

## Chair Synthesis at 9-Persona Scale

### Fixture Construction

| Option | Description | Selected |
|--------|-------------|----------|
| Extend existing fixture to 10 scorecards | Add 6 new scorecards to existing chair-strictness dir. | ✓ |
| New standalone 10-persona fixture | Fresh fixture. Cleaner but duplicates structure. | |
| Parameterized fixture generator | Generates N-persona fixtures. Overkill for one-time jump. | |

**User's choice:** Extend existing fixture to 10 scorecards (Recommended)

### Chair Prompt Update

| Option | Description | Selected |
|--------|-------------|----------|
| Test first, update if needed | Run 10-persona fixture through existing Chair. Only update if >5 contradictions. | ✓ |
| Preemptively update Chair prompt | Add 10+ scorecard handling instructions. May not be needed. | |
| Cap contradictions in validator | Enforce ≤5 in dc-validate-synthesis.sh. Post-hoc enforcement. | |

**User's choice:** Test first, update if needed (Recommended)

---

## Claude's Discretion

- Exact persona prompt wording and voice-kit calibration
- Specific regulatory citation patterns beyond starter set
- Synthetic multi-signal fixture content
- LLM-as-judge prompt template
- 10-persona Chair fixture scorecard content
- Plan numbering and task breakdown

## Deferred Ideas

- Real-artifact blinded-reader evaluation — Phase 7 UAT
- Block-mode voice-distinctness validation — v1.2
- Three-artifact gradient for Exec Sponsor — v1.2 if needed
- Parameterized fixture generator — v1.2+ if persona count grows
- userConfig.custom_personas_dir — v1.2
