# Phase 4: Six Personas + Atomic Conductor Wiring - Research

**Researched:** 2026-04-28
**Domain:** Persona authoring, conductor wiring, voice-differentiation validation
**Confidence:** HIGH

## Summary

Phase 4 is the largest phase in v1.1: six new persona files (5 bench signal-triggered + Junior Engineer as bench always-invokable on code-diff), atomic conductor wiring expanding the bench whitelist from 4 to 9, and three validation mechanisms (adversarial Executive Sponsor fixture, voice-distinctness validator, blinded-reader evaluation). All upstream dependencies are complete: Phase 1 TD items are closed (TD-05 Chair strictness, TD-06 AUTHORING.md rename), and Phase 3 delivered all 5 new signal IDs in `lib/signals.json`, the 9-entry `bench_priority_order` in `config.json`, and the Haiku classifier whitelist expanded to 8 slugs.

The core technical challenge is not complexity but discipline: each of the 6 new personas must produce voice-differentiated output that survives blinded-reader evaluation at the 9-persona scale. The existing codebase provides a mature template (security-reviewer.md + security-reviewer.yml), a working validator (R1-R9 + W1-W3), and a deterministic signal-to-persona pipeline. Phase 4's job is to replicate this pattern six times with precision, wire all six into the conductor atomically, and prove the result holds under scale via adversarial fixtures and overlap detection.

**Primary recommendation:** Author all 6 personas in parallel (Wave 1), wire the conductor atomically (Wave 2), then validate with fixtures (Wave 3). Follow the security-reviewer template exactly for agent file structure and sidecar shape. The `always_invoke_on` field for Junior Engineer is the only genuinely new plumbing -- everything else is pattern replication with persona-specific content.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** One plan per persona = 8 plans total: 6 persona plans (one per new persona) + 1 conductor-wiring plan + 1 fixtures/validation plan. Most parallelizable -- all 6 persona plans can run in Wave 1.
- **D-02:** Compliance Reviewer control-ID research happens inline in the persona plan (not a separate research plan). The executor reads authoritative citation patterns (GDPR Art. 5, HIPAA 164.312, SOC2 CC7.2, PCI Req 10) and embeds them directly into the persona prompt and worked examples.
- **D-03:** Executive Sponsor gets one iteration pass. Author + adversarial fixture test in the same plan. If the fixture fails after one fix attempt, ship what works and note remaining issues for v1.1.1. Exec Sponsor ships last per ROADMAP guidance.
- **D-04:** Wave structure: Wave 1 = 6 persona plans (parallel). Wave 2 = conductor-wiring plan (atomic bench whitelist 4->9 + always_invoke_on wiring). Wave 3 = fixtures/validation plan (adversarial Exec Sponsor fixture + voice-distinctness validator + blinded-reader evaluation + 10-persona Chair synthesis fixture).
- **D-05:** New sidecar field `always_invoke_on: [code-diff]` in `persona-metadata/junior-engineer.yml`. The conductor reads this field in `bin/dc-budget-plan.sh` and auto-appends Junior Engineer to `BENCH_SPAWN_LIST` when `artifact_type` matches, regardless of classifier signal output.
- **D-06:** Junior Engineer bypasses the bench budget cap entirely -- runs outside the budget system like core personas. Budget cap only applies to signal-triggered bench personas.
- **D-07:** The conductor-wiring plan (Wave 2) bundles all conductor changes: (1) bench whitelist 4->9 in `commands/review.md`, (2) `always_invoke_on` field reading in `bin/dc-budget-plan.sh`, (3) JE auto-append to spawn list on code-diff.
- **D-08:** Baseline banned phrases (consider, think about, be aware of) are excluded from overlap calculation. A `baseline_banned_phrases` set is defined in the validator.
- **D-09:** Voice-distinctness validation runs in warn-mode only for v1.1.
- **D-10:** LLM-as-judge with golden key for blinded-reader evaluation.
- **D-11:** Test artifact is a synthetic multi-signal fixture created specifically to trigger all 9 bench signals simultaneously.
- **D-12:** One temptation artifact + two assertions for adversarial Exec Sponsor fixture.
- **D-13:** All 6 persona files land first (Wave 1), then the conductor wiring lands as a single atomic commit in Wave 2. Bench whitelist grows from 4 to 9 entries in one commit.
- **D-14:** `validate-personas.sh` runs across all 13 personas as part of the conductor-wiring plan's verification step.
- **D-15:** Extend existing fixture in `tests/fixtures/chair-strictness/` to include 6 new scorecard files.
- **D-16:** Test first, update Chair prompt only if needed.

### Claude's Discretion
- Exact persona prompt wording and voice-kit calibration for each of the 6 new personas (within REQUIREMENTS.md constraints)
- Specific regulatory citation patterns for Compliance Reviewer (beyond the 4 starter citations)
- Synthetic multi-signal fixture content (must trigger all 9 bench signals)
- LLM-as-judge prompt template for blinded-reader evaluation
- 10-persona Chair fixture scorecard content
- Plan numbering and task breakdown within each persona plan

### Deferred Ideas (OUT OF SCOPE)
- Real-artifact blinded-reader evaluation on anaconda-platform-chart or outerbounds-data-plane -- deferred to Phase 7 UAT
- Block-mode voice-distinctness validation -- deferred to v1.2
- Three-artifact gradient for Exec Sponsor adversarial testing -- one temptation artifact sufficient
- Parameterized fixture generator for N-persona Chair tests -- overkill for one-time 8->10 jump
- `userConfig.custom_personas_dir` -- deferred to v1.2
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BNCH2-01 | Compliance Reviewer persona + sidecar; cites GDPR Art. 5(1)(e), HIPAA 164.312(b), SOC2 CC7.2, PCI Req 10; triggered by `compliance_marker` | Regulatory citation patterns researched (see Code Examples); persona template pattern verified from security-reviewer.md; `compliance_marker` signal already in signals.json with `signal_strength: moderate`, `min_evidence: 2` |
| BNCH2-02 | Performance Reviewer persona + sidecar; characterizes call frequency before severity; triggered by `performance_hotpath` | Voice differentiation from SRE researched (algorithmic lens vs operational lens); `performance_hotpath` signal present with `min_evidence: 2` |
| BNCH2-03 | Test Lead persona + sidecar; catches circular tests, flaky patterns, src+test imbalance; triggered by `test_imbalance` | Anti-pattern catalog researched; `test_imbalance` signal present with `signal_strength: strong`, `min_evidence: 1` |
| BNCH2-04 | Executive Sponsor persona + sidecar; findings MUST name a specific number or roadmap artifact; longest banned-phrase list; triggered by `exec_keyword` | P-11 adversarial defense researched; `exec_keyword` signal present with `signal_strength: weak`, `min_evidence: 2`, artifact_type gate `plan|rfc` |
| BNCH2-05 | Competing Team Lead persona + sidecar; MUST name specific consumer; framed as shared-infra reviewer; triggered by `shared_infra_change` | Voice differentiation from Staff Eng researched (consumer-naming vs deletion lens); `shared_infra_change` signal present with `signal_strength: strong`, `min_evidence: 1` |
| CORE-EXT-01 | Junior Engineer persona + sidecar (bench tier, `always_invoke_on: [code-diff]`); primary signal: first-person comprehension failure, NOT docstring-nannying | `always_invoke_on` conductor wiring researched; voice differentiation from Staff Eng researched (confusion voice vs deletion voice) |
| PQUAL-01 | Voice-distinctness validator: flags >40% banned-phrase overlap or >30% characteristic-objection overlap; warn-mode | Overlap calculation algorithm designed (baseline exclusion per D-08); integration into validate-personas.sh researched |
| PQUAL-02 | Adversarial CI fixture for Executive Sponsor: temptation artifact with NO quantification; CI fails if banned nominalization emitted | Fixture design researched (strategic-register plan without numbers); assertion mechanics defined |
| PQUAL-03 | Blinded-reader evaluation: attribute scorecards to personas >=80% accuracy on 9-bench roster | LLM-as-judge approach designed per D-10; prompt template pattern researched |
</phase_requirements>

## Standard Stack

### Core

Phase 4 introduces no new libraries or tools. The entire phase operates within the existing devils-council plugin infrastructure:

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Claude Code subagent format | Current (agents/*.md) | Persona files | The project's established persona delivery format; 11 existing agents validate the pattern [VERIFIED: codebase inspection] |
| YAML sidecar format | persona-metadata/*.yml | Voice kit + triggers | 10 existing sidecars; validator R1-R9 enforces schema [VERIFIED: codebase inspection] |
| bash (validate-personas.sh) | System shell | Persona validation + voice-distinctness extension | Existing 659-line validator; Phase 4 extends, not replaces [VERIFIED: codebase inspection] |
| jq | 1.7.1 | JSON processing in conductor scripts | Already used in dc-budget-plan.sh, dc-validate-synthesis.sh [VERIFIED: environment check] |
| yq | 4.45.4 | YAML parsing in validate-personas.sh | Already used throughout the validator [VERIFIED: environment check] |

### Supporting

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `scripts/test-chair-synthesis.sh` | Chair synthesis testing at 10-persona scale | Wave 3 fixture creation |
| `bin/dc-validate-synthesis.sh` | Synthesis validation (contradiction count check) | Wave 3 Chair fixture verification |
| `bin/dc-budget-plan.sh` | Budget plan with `always_invoke_on` extension | Wave 2 conductor wiring |
| `.github/workflows/ci.yml` | CI pipeline for adversarial Exec Sponsor fixture | Wave 3 fixture integration |

**Installation:** No new packages required. All tools are already installed and verified.

## Architecture Patterns

### Persona File Structure (Canonical Template)

Every new persona follows this exact structure derived from `agents/security-reviewer.md`: [VERIFIED: codebase inspection]

```
agents/<slug>.md
---
name: <slug>
description: "<one-sentence trigger description under 300 chars>"
model: inherit
---

<voice paragraph: value-system-anchor, NOT role description>

## How you review
<standard review protocol referencing INPUT.md, evidence rules, severity scale>

## Output contract -- READ CAREFULLY
<standard two-part output: YAML frontmatter findings + prose Summary>

## Complete worked example -- copy this exact shape
<2 good findings + delegation_request if applicable>

### What NOT to do
<1 bad finding demonstrating banned-phrase drop>

## Banned-phrase discipline
<persona-specific explanation of why each phrase is banned>

## Examples
<references the worked example above for W2 compliance>
```

### Sidecar Structure (Canonical Template)

Every new sidecar follows `persona-metadata/security-reviewer.yml`: [VERIFIED: codebase inspection]

```yaml
tier: bench
triggers:
  - <signal_id_from_signals.json>
primary_concern: "<one question -- the value-system anchor>"
blind_spots:
  - <domain_this_persona_ignores>
  - <another_blind_spot>
characteristic_objections:
  - "<verbatim phrase 1>"
  - "<verbatim phrase 2>"
  - "<verbatim phrase 3>"
  - "<verbatim phrase 4>"
banned_phrases:
  - consider
  - think about
  - be aware of
  - <role-specific-ban-1>
  - <role-specific-ban-2>
  # ... more role-specific bans
tone_tags: [<tag1>, <tag2>, <tag3>]
```

### Junior Engineer Sidecar Extension

Junior Engineer's sidecar introduces one new field not present in existing sidecars: [ASSUMED -- new field, needs conductor implementation]

```yaml
tier: bench
always_invoke_on:
  - code-diff
triggers: []     # empty -- not signal-driven
primary_concern: "<question>"
# ... standard fields ...
```

The `always_invoke_on` field is read by `bin/dc-budget-plan.sh` (or the conductor directly in `commands/review.md`) and causes Junior Engineer to be auto-appended to the spawn list when `artifact_type` matches any value in the list, bypassing both the classifier and the budget cap.

### Conductor Wiring Surfaces (Atomic Commit in Wave 2)

The following edits MUST land in a single commit per D-13: [VERIFIED: codebase inspection]

| File | Location | Edit |
|------|----------|------|
| `commands/review.md` ~line 155 | Haiku whitelist | Already 8 entries from Phase 3 (no change needed) |
| `commands/review.md` ~line 302 | Core spawn list | Unchanged -- JE is bench tier, not core (per user override) |
| `commands/review.md` ~lines 319-323 | Bench persona enumeration | Add 5 new bench slugs: compliance-reviewer, performance-reviewer, test-lead, executive-sponsor, competing-team-lead |
| `commands/review.md` ~lines 382-384 | Validator loop canonical order | Keep `[staff-engineer, sre, product-manager, devils-advocate]` + BENCH_SPAWN_LIST (bench order comes from budget-plan, not hardcoded) |
| `commands/review.md` ~lines 797-807 | Display-name map | Add 6 entries for new personas |
| `bin/dc-budget-plan.sh` | New feature | Read `always_invoke_on` from sidecar; auto-append JE when artifact_type matches |

### Voice Differentiation Matrix

Critical overlap pairs that require explicit voice separation: [VERIFIED: REQUIREMENTS.md + existing sidecars]

| Persona A | Persona B | Overlap Risk | Differentiation Strategy |
|-----------|-----------|-------------|--------------------------|
| Compliance Reviewer | Security Reviewer | Both fire on auth/crypto artifacts | Compliance asks "which control ID covers this?" -- Security asks "which line does the attacker take?". Compliance blind_spots include `attack_surface_analysis`; Security blind_spots include `regulatory_citable_controls` [CITED: PITFALLS.md P-01] |
| Performance Reviewer | SRE | Both examine resource-exhaustion | Performance asks "what's the call frequency?" (algorithmic lens) -- SRE asks "what pages me at 3am?" (operational lens). Performance blind_spots include `operational_runbook`; SRE blind_spots include `greenfield_architecture` [CITED: PITFALLS.md P-01] |
| Junior Engineer | Staff Engineer | Both flag complex code | JE says "I had to re-read this three times" (confusion voice) -- Staff Eng says "delete this and inline the three lines" (deletion voice). JE is BANNED from Staff Eng's simplification register [CITED: REQUIREMENTS.md CORE-EXT-01] |
| Competing Team Lead | Devil's Advocate | Both challenge assumptions | CTL MUST name a specific consumer (team/repo/service/endpoint) -- DA asks "what premise are we not questioning?". CTL is shared-infra-scoped; DA is artifact-scope-agnostic [CITED: REQUIREMENTS.md BNCH2-05] |
| Competing Team Lead | Staff Engineer | Both question necessity | CTL asks "which team depends on this contract?" -- Staff Eng asks "what can we delete?". CTL is consumer-facing; Staff Eng is author-facing [ASSUMED] |
| Executive Sponsor | Product Manager | Both concerned with business value | Exec Sponsor MUST cite a specific number -- PM asks "who filed the ticket?". Exec Sponsor is quantification-forward; PM is stakeholder-forward [CITED: REQUIREMENTS.md BNCH2-04] |

### Anti-Patterns to Avoid

- **Generic-concern persona:** A persona whose characteristic_objections could apply to any artifact. Every objection must reference the persona's specific domain (e.g., Compliance says "Which GDPR article covers this data flow?" -- not "Have you considered compliance?"). [CITED: PITFALLS.md P-01]
- **Duplicate voice registers:** Two personas sharing >3 banned phrases beyond the baseline three (consider, think about, be aware of). Each persona's role-specific bans must be unique to its vague-register. [VERIFIED: existing sidecars have no role-specific overlap]
- **Noun-phrase primary_concern:** Writing "API contract stability" instead of "Which downstream contract does this change break?" -- the question form forces specificity and drives the persona's review lens. [CITED: PITFALLS.md P-03]
- **Docstring-nannying in Junior Engineer:** JE must express first-person confusion, not style-lint findings. "I had to re-read this three times" is correct; "This function lacks a docstring" is a failure mode. [CITED: REQUIREMENTS.md CORE-EXT-01]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Persona schema validation | Custom per-persona checks | `scripts/validate-personas.sh` (R1-R9 + W1-W3) | Already enforces all required fields, tier rules, trigger-signal resolution, banned-phrase presence. 659 lines of battle-tested bash [VERIFIED: codebase] |
| Signal-to-persona routing | New routing logic | Existing `lib/classify.py` + `lib/signals.json` pipeline | Phase 3 already delivered all 5 new signal IDs. Persona sidecars just reference them via `triggers:` [VERIFIED: signals.json inspection] |
| Budget cap / priority ordering | Custom ordering code | `bin/dc-budget-plan.sh` reads `config.json .budget.bench_priority_order` | 9-entry priority array already in config.json from Phase 3 [VERIFIED: config.json] |
| Persona display names | Name generation logic | Hardcoded display-name map in `commands/review.md` | Pattern established for 8 existing personas; extend with 6 new entries [VERIFIED: review.md line 797] |
| Haiku classifier whitelist | Dynamic whitelist | Hardcoded in `agents/artifact-classifier.md` | Already at 8 slugs from Phase 3; no Phase 4 changes needed [VERIFIED: artifact-classifier.md] |

**Key insight:** Phase 4 is 95% content authoring and 5% plumbing. The plumbing (conductor wiring, `always_invoke_on`) is the only genuinely new code. Every persona file is a pattern replication of the security-reviewer template with domain-specific content.

## Common Pitfalls

### Pitfall 1: Executive Sponsor Register Drift (P-11) -- HIGHEST RISK

**What goes wrong:** Executive Sponsor emits vague strategic language despite the banned-phrase list. The model satisfies the formal constraint (no exact banned phrases) while producing functionally identical exec-speak: risk statements that apply to any plan, affirmative observations, or concerns without a specific number. [CITED: PITFALLS.md P-11]
**Why it happens:** Exec-speak is the richest vague-register vocabulary in LLM training data. Banning specific phrases pushes the model to synonyms.
**How to avoid:** (1) The adversarial fixture must be genuinely adversarial -- a plan with strategic register language and ZERO quantification. (2) The banned-phrase list must include nominalized synonyms: `strategic considerations`, `alignment concerns`, `risk factors` without a named risk. (3) The `findings: []` path with explanatory Summary must be explicitly taught via worked example. (4) The two-assertion test (no banned nominalization + either cited number OR empty findings) is the gate.
**Warning signs:** The adversarial fixture contains any quantified claim -- that makes it too easy and defeats the test.

### Pitfall 2: Persona Dilution at 9-Bench Scale (P-01)

**What goes wrong:** Compliance/Security and Performance/SRE produce functionally identical findings with different headers. Two overlapping pairs produce noticeable noise inflation. [CITED: PITFALLS.md P-01]
**Why it happens:** Adjacent-domain personas share vocabulary if voice kits are not precisely differentiated.
**How to avoid:** For every overlap-risk pair (see Voice Differentiation Matrix above): (1) primary_concern phrased as a different question, (2) zero overlapping characteristic_objections, (3) banned_phrases include the adjacent persona's most natural register words. (4) blind_spots explicitly declare the adjacent domain as out-of-scope.
**Warning signs:** A blinded reader correctly identifies fewer than 80% of personas by voice alone.

### Pitfall 3: Chair Contradictions Explosion at N=10 (P-06)

**What goes wrong:** With 10 personas (4 core + JE + up to 5 bench), 45 pairwise contradiction possibilities exist. Chair emits 6+ contradictions on a real artifact, making the synthesis harder to read than the raw scorecards. [CITED: PITFALLS.md P-06]
**Why it happens:** More personas = more cross-discipline tension, but not all tension is worth surfacing.
**How to avoid:** D-16 says test first, update Chair prompt only if needed. The 10-persona Chair fixture asserts `## Contradictions` count at most 5. If the fixture produces more, add a "pick the sharpest 3-5 contradictions" instruction to `agents/council-chair.md`.
**Warning signs:** Chair fixture consistently produces >5 contradictions across different synthetic scorecard sets.

### Pitfall 4: `always_invoke_on` Wiring Bug

**What goes wrong:** Junior Engineer doesn't appear in the spawn list despite `always_invoke_on: [code-diff]` being set, because `bin/dc-budget-plan.sh` doesn't read the field yet.
**Why it happens:** The `always_invoke_on` field is new -- no existing code reads it. The budget plan script currently only reads `triggered_personas` from MANIFEST.json and `bench_priority_order` from config.json.
**How to avoid:** Wave 2 conductor-wiring plan must: (1) add `always_invoke_on` reading to the conductor (either in `commands/review.md` or `bin/dc-budget-plan.sh`), (2) auto-append JE to the spawn list before the budget cap is applied, (3) ensure JE doesn't count against the budget cap. Test with a fixture where artifact_type=code-diff and assert JE appears in spawn list.
**Warning signs:** Budget cap test at 9-bench scenario doesn't include JE in the spawn list.

### Pitfall 5: Non-Atomic Conductor Wiring

**What goes wrong:** The bench whitelist in `commands/review.md` is expanded incrementally (e.g., adding personas one at a time) instead of in a single atomic commit. An intermediate state where the whitelist has 6 entries but only 4 sidecars exist would break the PreToolUse hook validation path.
**Why it happens:** Wave 1 persona files land first, tempting incremental whitelist updates.
**How to avoid:** D-13 mandates all 6 persona files land in Wave 1, then the conductor wiring lands as a SINGLE atomic commit in Wave 2. Do not merge whitelist updates piecemeal.
**Warning signs:** Multiple commits touching `commands/review.md` bench persona enumeration section.

## Code Examples

### Persona Agent File Pattern

Verified from `agents/security-reviewer.md` (121 lines): [VERIFIED: codebase]

```markdown
---
name: <slug>
description: "<bench persona trigger description under 300 chars>"
model: inherit
---


<voice paragraph -- value-system anchor, NOT role title>

## How you review

- Read `INPUT.md` at the run directory specified by the conductor.
- Cite specific lines verbatim in the `evidence` field.
- Phrase `claim` and `ask` without banned phrases.
- Severity: blocker | major | minor | nit.
- Prefer one sharp finding over five hedged ones.

## Output contract -- READ CAREFULLY

Write your scorecard to `$RUN_DIR/<slug>-draft.md`. Two parts:
1. YAML frontmatter with `findings:` array
2. Prose body with Summary only

## Complete worked example -- copy this exact shape

```markdown (nested)
---
persona: <slug>
artifact_sha256: <placeholder>
findings:
  - target: "<specific location>"
    claim: "<domain-specific, evidence-backed claim>"
    evidence: |
      <verbatim quote from INPUT.md>
    ask: "<specific, actionable request>"
    severity: <level>
    category: <domain-tag>
---

## Summary

<one paragraph in persona voice>
```

### What NOT to do
<finding using banned phrases, no evidence>

## Banned-phrase discipline
<persona-specific explanation>

## Examples
See worked example above.
```

### Sidecar Pattern (bench persona with triggers)

Verified from `persona-metadata/security-reviewer.yml`: [VERIFIED: codebase]

```yaml
tier: bench
triggers:
  - <signal_id>
primary_concern: "<question form, ends with ?>"
blind_spots:
  - <domain_1>
  - <domain_2>
  - <domain_3>
characteristic_objections:
  - "<verbatim first-person phrase>"
  - "<verbatim first-person phrase>"
  - "<verbatim first-person phrase>"
  - "<verbatim first-person phrase>"
banned_phrases:
  - consider
  - think about
  - be aware of
  - <role-specific-1>
  - <role-specific-2>
  # ... more role-specific bans
tone_tags: [<tag1>, <tag2>, <tag3>]
```

### Junior Engineer Sidecar (always_invoke_on pattern)

New field not present in existing sidecars: [ASSUMED -- needs implementation]

```yaml
tier: bench
always_invoke_on:
  - code-diff
triggers: []
primary_concern: "Where did I get lost reading this?"
blind_spots:
  - deletion_candidates
  - deployment_topology
  - cost_optimization
characteristic_objections:
  - "I had to re-read this three times to understand the flow."
  - "This variable name says one thing but the code does another."
  - "I can't tell what state this is supposed to be in after this function runs."
banned_phrases:
  - consider
  - think about
  - be aware of
  - best practices
  - industry standard
  - modern approach
  - clean code
  - refactor
  - naming convention
  - code smell
tone_tags: [confused, first-person, concrete-question]
```

### Voice-Distinctness Overlap Check (new validator extension)

Algorithm for PQUAL-01: [ASSUMED -- new code, not yet implemented]

```bash
# Pseudocode for banned-phrase overlap check
BASELINE=("consider" "think about" "be aware of")

for each persona pair (A, B):
  bans_A = sidecar_A.banned_phrases - BASELINE
  bans_B = sidecar_B.banned_phrases - BASELINE
  overlap = intersection(bans_A, bans_B)
  overlap_pct = |overlap| / min(|bans_A|, |bans_B|)
  if overlap_pct > 0.40:
    warn "Personas $A and $B share >40% banned-phrase overlap"

for each persona pair (A, B):
  objs_A = sidecar_A.characteristic_objections
  objs_B = sidecar_B.characteristic_objections
  # Substring or fuzzy match -- exact algorithm TBD by executor
  overlap_count = count_matching_pairs(objs_A, objs_B)
  overlap_pct = overlap_count / min(|objs_A|, |objs_B|)
  if overlap_pct > 0.30:
    warn "Personas $A and $B share >30% objection overlap"
```

### Adversarial Exec Sponsor Fixture (temptation artifact)

Content pattern for PQUAL-02: [ASSUMED -- fixture to be authored]

```markdown
# Q3 Platform Modernization Strategy

## Executive Summary

This initiative aligns our engineering north star with the strategic
vision for platform consolidation. By unlocking value across the
customer lifecycle, we de-risk the migration while moving the needle
on developer productivity.

## Approach

Consolidate the three legacy services into a unified platform layer.
Stakeholder alignment sessions will identify the optimal integration
points. The competitive landscape demands we accelerate this initiative
to capture the opportunity window.

## Risks

Timeline risk is inherent in any transformation of this magnitude.
We must balance the strategic imperative with operational reality.
```

Note: This artifact has ZERO specific numbers (no dollars, no dates, no customer counts, no ticket IDs). A disciplined Executive Sponsor must either find quantifiable gaps ("no budget estimate", "no timeline") or emit `findings: []` with "this plan does not contain the quantified business context required for Executive Sponsor review."

### Compliance Reviewer Citation Patterns

Starter regulatory citations per D-02: [ASSUMED -- based on training knowledge; executor should verify exact article/section numbers against authoritative sources if accuracy is critical]

| Framework | Citation Pattern | What It Covers |
|-----------|-----------------|----------------|
| GDPR Art. 5(1)(e) | Storage limitation | Personal data kept no longer than necessary |
| GDPR Art. 5(1)(f) | Integrity and confidentiality | Appropriate security of personal data |
| HIPAA 164.312(a)(1) | Access control | Unique user identification, emergency access |
| HIPAA 164.312(b) | Audit controls | Record and examine activity in systems with ePHI |
| SOC2 CC7.2 | System operations monitoring | Monitor system components for anomalies |
| SOC2 CC6.1 | Logical and physical access controls | Restrict access to authorized users |
| PCI DSS Req 10 | Track and monitor access | Log mechanisms, audit trails to network resources |
| PCI DSS Req 6 | Develop secure systems | Address common coding vulnerabilities |

### Display-Name Map Extension

Six new entries for `commands/review.md` display-name map: [VERIFIED: existing pattern at lines 797-807]

```
- `compliance-reviewer` -> `Compliance Reviewer`
- `performance-reviewer` -> `Performance Reviewer`
- `test-lead` -> `Test Lead`
- `executive-sponsor` -> `Executive Sponsor`
- `competing-team-lead` -> `Competing Team Lead`
- `junior-engineer` -> `Junior Engineer`
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Core cardinality 4 + bench 4 | Core 4 + bench 9 (JE as bench always-invokable) | v1.1 Phase 4 | Budget cap becomes meaningful: 9 candidates for 6 slots; priority_order decides who runs |
| No voice overlap detection | Overlap validator (PQUAL-01) in warn-mode | v1.1 Phase 4 | Catches persona dilution before it ships |
| Manual voice assessment | LLM-as-judge blinded-reader evaluation | v1.1 Phase 4 | Reproducible, automatable voice differentiation test |
| 4-entry Haiku whitelist | 8-entry whitelist (from Phase 3) | v1.1 Phase 3 | No Phase 4 change needed -- Phase 3 already expanded |

## Assumptions Log

> List all claims tagged [ASSUMED] in this research.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `always_invoke_on` field in sidecar YAML will be read by `bin/dc-budget-plan.sh` or `commands/review.md` conductor | Junior Engineer Sidecar Extension | If the field isn't read by existing code (it isn't -- this is new plumbing), the Wave 2 conductor-wiring plan must implement the reading logic. Risk: LOW (D-05 and D-07 explicitly specify this implementation) |
| A2 | Voice-distinctness overlap algorithm uses set-intersection for banned phrases and substring/fuzzy matching for objections | Voice-Distinctness Overlap Check | If a different algorithm is needed, the executor adjusts. Risk: LOW (D-08 provides the baseline-exclusion rule; exact algorithm is Claude's Discretion) |
| A3 | Adversarial Exec Sponsor fixture content will effectively tempt exec-speak | Adversarial Exec Sponsor Fixture | If the fixture is too easy (contains numbers) or too hard (contains nothing recognizable), the test is meaningless. Risk: MEDIUM (P-11 is the highest single failure risk per PITFALLS.md) |
| A4 | Regulatory citation patterns are accurate (GDPR articles, HIPAA sections, SOC2 controls, PCI requirements) | Compliance Reviewer Citation Patterns | If citation numbers are wrong, the Compliance Reviewer persona teaches incorrect regulatory references. Risk: MEDIUM (D-02 says inline research; executor should verify) |
| A5 | Competing Team Lead voice is distinct from Staff Engineer and Devil's Advocate | Voice Differentiation Matrix | If overlap is too high, blinded-reader evaluation fails PQUAL-03. Risk: LOW (explicit consumer-naming constraint in BNCH2-05 provides strong differentiation) |

## Open Questions

1. **Where does `always_invoke_on` reading live?**
   - What we know: D-05 says `bin/dc-budget-plan.sh`; D-07 says the conductor-wiring plan bundles all changes
   - What's unclear: Does the reading happen in `commands/review.md` (before calling budget-plan) or inside `bin/dc-budget-plan.sh` itself? The budget-plan script currently reads `triggered_personas` from MANIFEST -- JE wouldn't be in that list since it's not signal-driven
   - Recommendation: The conductor (`commands/review.md`) should auto-append JE to the spawn list BEFORE the budget-plan script runs, OR the budget-plan script should scan sidecar files for `always_invoke_on` matches. The former is simpler (one line of bash in the conductor). The planner decides.

2. **Characteristic-objection overlap detection algorithm**
   - What we know: D-08 excludes baseline banned phrases; >30% threshold per PQUAL-01
   - What's unclear: Exact string matching vs fuzzy matching for objections. Two objections can be semantically similar without sharing exact words
   - Recommendation: Start with exact substring matching (one objection is a substring of another). If that's too strict/lenient, the executor can calibrate. Warn-mode means false positives are acceptable.

3. **LLM-as-judge prompt template**
   - What we know: D-10 specifies LLM-as-judge with golden key; strip persona names, feed each to fresh prompt
   - What's unclear: Which model serves as judge? Same model (Sonnet) or a different one? How to handle non-determinism in attribution?
   - Recommendation: Use the same model at temperature 0 (or lowest available). Run each attribution 3 times and take majority vote. Script outputs accuracy % and per-persona attribution matrix.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| jq | Conductor scripts, MANIFEST manipulation | Yes | 1.7.1 | -- |
| yq | Persona validator (YAML parsing) | Yes | 4.45.4 | -- |
| python3 | LLM-as-judge script (if implemented in Python) | Yes | 3.11.4 | Bash-only alternative |
| bash | All scripts | Yes | System | -- |
| bats-core | Potential test framework | No | -- | Plain bash test scripts (existing pattern) |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:**
- bats-core is not installed, but the project uses plain bash test scripts (`scripts/test-*.sh`) as the idiomatic test pattern. No action needed.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Plain bash test scripts (no formal framework) |
| Config file | None -- each `scripts/test-*.sh` is standalone |
| Quick run command | `./scripts/validate-personas.sh` |
| Full suite command | Run all `scripts/test-*.sh` scripts; CI workflow runs them in sequence |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BNCH2-01 | Compliance Reviewer passes R1-R9 + W1-W3 | unit | `./scripts/validate-personas.sh agents/compliance-reviewer.md` | Wave 1 creates |
| BNCH2-02 | Performance Reviewer passes R1-R9 + W1-W3 | unit | `./scripts/validate-personas.sh agents/performance-reviewer.md` | Wave 1 creates |
| BNCH2-03 | Test Lead passes R1-R9 + W1-W3 | unit | `./scripts/validate-personas.sh agents/test-lead.md` | Wave 1 creates |
| BNCH2-04 | Executive Sponsor passes R1-R9 + W1-W3 | unit | `./scripts/validate-personas.sh agents/executive-sponsor.md` | Wave 1 creates |
| BNCH2-05 | Competing Team Lead passes R1-R9 + W1-W3 | unit | `./scripts/validate-personas.sh agents/competing-team-lead.md` | Wave 1 creates |
| CORE-EXT-01 | Junior Engineer passes R1-R9 + W1-W3 | unit | `./scripts/validate-personas.sh agents/junior-engineer.md` | Wave 1 creates |
| PQUAL-01 | Voice-distinctness validator warns on overlap | unit | `./scripts/validate-personas.sh` (extended with overlap check) | Wave 3 extends |
| PQUAL-02 | Adversarial Exec Sponsor fixture fails on banned nominalization | integration | New CI step in `.github/workflows/ci.yml` | Wave 3 creates |
| PQUAL-03 | Blinded-reader evaluation >=80% attribution accuracy | integration | `./scripts/test-blinded-reader.sh` (new) | Wave 3 creates |
| SC-1 | Bench whitelist 4->9 atomic commit | smoke | `grep -c` assertions in conductor-wiring plan verification | Wave 2 verifies |
| SC-5 | Core cardinality stays at 4 | smoke | `grep -c "^tier: core$" persona-metadata/*.yml` returns 4 | Wave 2 verifies |
| SC-6 | Chair synthesis <=5 contradictions at 10-persona scale | integration | `./scripts/test-chair-synthesis.sh` (extended with 10-persona fixture) | Wave 3 extends |

### Sampling Rate

- **Per task commit:** `./scripts/validate-personas.sh` (quick -- validates individual persona)
- **Per wave merge:** Full validator + relevant test scripts
- **Phase gate:** Full CI suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] No new test framework install needed -- existing bash scripts pattern continues
- [ ] `tests/fixtures/exec-sponsor-adversarial/` -- adversarial temptation artifact (Wave 3 creates)
- [ ] `tests/fixtures/blinded-reader/` -- multi-signal synthetic fixture (Wave 3 creates)
- [ ] `tests/fixtures/chair-strictness/` -- 6 new scorecard files for 10-persona fixture (Wave 3 extends)
- [ ] `scripts/test-blinded-reader.sh` -- LLM-as-judge evaluation script (Wave 3 creates)
- [ ] Voice-distinctness overlap check in `scripts/validate-personas.sh` (Wave 3 extends)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A -- Phase 4 is content authoring + shell scripts |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A |
| V5 Input Validation | Yes (marginally) | `scripts/validate-personas.sh` validates YAML frontmatter; existing yq-based parsing handles untrusted persona file content |
| V6 Cryptography | No | N/A |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Persona file injection (malicious YAML frontmatter) | Tampering | PreToolUse hook runs `validate-personas.sh` on every Write/Edit to `agents/*.md`; validator R1-R9 rejects malformed frontmatter [VERIFIED: hooks/hooks.json] |
| Shell injection via persona content | Elevation of Privilege | `scripts/validate-shell-inject.sh` runs on every Write/Edit to `commands/*.md` (TD-04); persona files don't support shell-injection syntax [VERIFIED: hooks/hooks.json] |
| Adversarial fixture bypassing CI | Spoofing | Fixture assertions are deterministic bash grep/regex -- not LLM-dependent; CI runs on every push [VERIFIED: ci.yml] |

## Sources

### Primary (HIGH confidence)
- `agents/security-reviewer.md` -- canonical bench persona agent file (full template structure)
- `persona-metadata/security-reviewer.yml` -- canonical bench sidecar shape
- `persona-metadata/*.yml` (all 10 existing sidecars) -- voice kit patterns, banned-phrase inventories
- `agents/AUTHORING.md` -- persona authoring guide (structure, rules, references)
- `skills/persona-voice/PERSONA-SCHEMA.md` -- validator rule definitions (R1-R9, W1-W3)
- `skills/persona-voice/SKILL.md` -- voice rubric (tone tags, banned-phrase discipline)
- `scripts/validate-personas.sh` (lines 500-659) -- validation logic, R7 trigger resolution, R8/R9 tier rules
- `commands/review.md` (lines 140-340, 790-830) -- conductor wiring surfaces (Haiku whitelist, spawn list, display-name map)
- `bin/dc-budget-plan.sh` -- budget plan script (priority_order reading, spawn list computation)
- `config.json` -- 9-entry bench_priority_order already in place from Phase 3
- `lib/signals.json` -- all 21 signal entries including 5 new Phase 3 signals
- `agents/artifact-classifier.md` -- Haiku whitelist already at 8 slugs from Phase 3
- `.planning/phases/04-six-personas-atomic-conductor-wiring/04-CONTEXT.md` -- all locked decisions (D-01 through D-16)
- `.planning/phases/03-classifier-extension/03-CONTEXT.md` -- Phase 3 decisions (D-01 Haiku whitelist, D-09 priority order, D-12 JE outside priority system)
- `.planning/research/PITFALLS.md` -- P-01 (persona dilution), P-06 (Chair contradictions), P-07 (core cardinality), P-11 (Exec Sponsor register drift)
- `.planning/research/ARCHITECTURE.md` -- conductor integration points, stress tests, build order
- `.planning/REQUIREMENTS.md` -- BNCH2-01..05, CORE-EXT-01, PQUAL-01..03 full specs

### Secondary (MEDIUM confidence)
- `.planning/ROADMAP.md` -- Phase 4 success criteria (6 items), plan estimate (6-7)

### Tertiary (LOW confidence)
- Regulatory citation accuracy (GDPR article numbers, HIPAA sections, SOC2 controls, PCI requirements) -- based on training knowledge, tagged as [ASSUMED]. Executor should verify against authoritative regulatory text if citation precision is critical for the Compliance Reviewer persona.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all tools already present and verified in the codebase
- Architecture: HIGH -- all patterns are replications of existing security-reviewer template
- Pitfalls: HIGH -- grounded in PITFALLS.md research with direct codebase evidence
- Persona voice content: MEDIUM -- voice calibration is inherently iterative; D-03 acknowledges Exec Sponsor may need v1.1.1 follow-up
- Regulatory citations: LOW -- assumed from training knowledge; verify if precision matters

**Research date:** 2026-04-28
**Valid until:** 2026-05-28 (stable -- no external dependencies expected to change)
