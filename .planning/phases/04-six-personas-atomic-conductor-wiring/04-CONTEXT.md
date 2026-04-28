# Phase 4: Six Personas + Atomic Conductor Wiring - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Author 6 new persona files (5 bench signal-triggered + Junior Engineer as bench always-invokable on code-diff), wire them into the conductor's bench whitelist as an atomic cardinality change 4→9, and validate voice differentiation at scale via adversarial fixtures, overlap detection, and blinded-reader evaluation.

**In scope:** BNCH2-01..05 (5 new bench personas), CORE-EXT-01 (Junior Engineer), PQUAL-01 (voice-distinctness validator), PQUAL-02 (adversarial Exec Sponsor fixture), PQUAL-03 (blinded-reader evaluation).

**Out of scope:**
- Scaffolder skill (Phase 5)
- Codex schema rollout (Phase 6)
- Real-artifact UAT on anaconda-platform-chart (Phase 7 — Phase 4 uses synthetic fixtures only)
- Custom persona directory `userConfig.custom_personas_dir` (deferred to v1.2)

**Depends on:**
- Phase 1 (TD-05 Chair strictness + TD-06 rename) — complete
- Phase 3 (all 5 new signal IDs in signals.json + Haiku whitelist at 8 slugs) — complete

</domain>

<decisions>
## Implementation Decisions

### Persona authoring strategy

- **D-01:** One plan per persona = **8 plans total**: 6 persona plans (one per new persona) + 1 conductor-wiring plan + 1 fixtures/validation plan. Each persona plan includes: `agents/<slug>.md` + `persona-metadata/<slug>.yml` + unit test assertions. Most parallelizable — all 6 persona plans can run in Wave 1.
- **D-02:** Compliance Reviewer control-ID research happens **inline in the persona plan** (not a separate research plan). The executor reads authoritative citation patterns (GDPR Art. 5, HIPAA §164.312, SOC2 CC7.2, PCI Req 10) and embeds them directly into the persona prompt and worked examples.
- **D-03:** Executive Sponsor gets **one iteration pass**. Author + adversarial fixture test in the same plan. If the fixture fails after one fix attempt, ship what works and note remaining issues for v1.1.1. Exec Sponsor ships last per ROADMAP guidance.
- **D-04:** Wave structure: **Wave 1** = 6 persona plans (parallel). **Wave 2** = conductor-wiring plan (atomic bench whitelist 4→9 + always_invoke_on wiring). **Wave 3** = fixtures/validation plan (adversarial Exec Sponsor fixture + voice-distinctness validator + blinded-reader evaluation + 10-persona Chair synthesis fixture).

### Junior Engineer wiring

- **D-05:** New sidecar field `always_invoke_on: [code-diff]` in `persona-metadata/junior-engineer.yml`. The conductor reads this field in `bin/dc-budget-plan.sh` and auto-appends Junior Engineer to `BENCH_SPAWN_LIST` when `artifact_type` matches, regardless of classifier signal output.
- **D-06:** Junior Engineer **bypasses the bench budget cap entirely** — runs outside the budget system like core personas. Budget cap only applies to signal-triggered bench personas. Consistent with Phase 3 D-12 ("runs outside the bench priority system alongside core personas in the conductor").
- **D-07:** The conductor-wiring plan (Wave 2) bundles all conductor changes: (1) bench whitelist 4→9 in `commands/review.md`, (2) `always_invoke_on` field reading in `bin/dc-budget-plan.sh`, (3) JE auto-append to spawn list on code-diff. One plan owns all conductor plumbing.

### Voice-distinctness validation (PQUAL-01)

- **D-08:** Baseline banned phrases (`consider`, `think about`, `be aware of`) are **excluded from overlap calculation**. A `baseline_banned_phrases` set is defined in the validator. When computing overlap %, both persona phrase sets have baseline subtracted before comparison. Only persona-specific phrases count toward the 40% threshold.
- **D-09:** Voice-distinctness validation runs in **warn-mode only** for v1.1 (per ROADMAP SC-3 verbatim). Overlap detection runs but doesn't fail `validate-personas.sh`. Upgrade to block-mode in v1.2 after real-world calibration.

### Blinded-reader evaluation (PQUAL-03)

- **D-10:** **LLM-as-judge with golden key**. Run a 6+ persona review on a test artifact. Strip persona names from scorecards. Feed each anonymized scorecard to a fresh LLM prompt: "Given these 9 persona descriptions, which persona wrote this scorecard?" Compare to ground truth. Script produces attribution accuracy %. Reproducible, automatable, no human in the loop.
- **D-11:** Test artifact is a **synthetic multi-signal fixture** created specifically to trigger all 9 bench signals simultaneously. Ensures every persona produces output. Fixture lives in `tests/fixtures/` and is deterministic. Real-artifact evaluation deferred to Phase 7 UAT.

### Adversarial Exec Sponsor fixture (PQUAL-02)

- **D-12:** **One temptation artifact + two assertions**. Single test artifact: a plan dripping with strategic register ('align stakeholders', 'unlock value') but with ZERO numbers/dates/customer names. Two assertions: (1) if persona emits any banned nominalization → CI FAIL, (2) persona either cites a specific number/artifact OR emits `findings: []` with explanatory Summary → CI PASS.

### Conductor atomic wiring

- **D-13:** All 6 persona files land first (Wave 1), then the conductor wiring lands as a **single atomic commit** in Wave 2 (per ROADMAP SC-1). Bench whitelist grows from 4 to 9 entries in one commit. No incremental whitelist growth.
- **D-14:** `validate-personas.sh` runs across all 13 personas (4 core + 9 bench + Chair + classifier) as part of the conductor-wiring plan's verification step — ensures R7 trigger validation passes for all new sidecars referencing Phase 3 signal IDs.

### Chair synthesis at 9-persona scale (SC-6)

- **D-15:** **Extend existing fixture** in `tests/fixtures/chair-strictness/` to include 6 new scorecard files (5 bench + JE). Reuse existing MANIFEST structure with expanded persona list.
- **D-16:** **Test first, update Chair prompt only if needed.** Chair prompt is already designed for variable-count input. Run the 10-persona fixture through existing Chair. Only update Chair prompt if contradictions exceed ≤5 threshold. Avoids premature prompt engineering.

### Claude's Discretion

- Exact persona prompt wording and voice-kit calibration for each of the 6 new personas (within REQUIREMENTS.md constraints)
- Specific regulatory citation patterns for Compliance Reviewer (beyond the 4 starter citations)
- Synthetic multi-signal fixture content (must trigger all 9 bench signals)
- LLM-as-judge prompt template for blinded-reader evaluation
- 10-persona Chair fixture scorecard content
- Plan numbering and task breakdown within each persona plan

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1.1 milestone context
- `.planning/REQUIREMENTS.md` §BNCH2 — BNCH2-01 through BNCH2-05 (5 new bench persona specs with specific banned phrases, trigger signals, and discipline requirements)
- `.planning/REQUIREMENTS.md` §CORE-EXT — CORE-EXT-01 (Junior Engineer spec: first-person comprehension failure, NOT docstring-nannying)
- `.planning/REQUIREMENTS.md` §PQUAL — PQUAL-01 (voice-distinctness validator), PQUAL-02 (adversarial Exec Sponsor fixture), PQUAL-03 (blinded-reader evaluation)
- `.planning/ROADMAP.md` §Phase 4 — 6 success criteria
- `.planning/research/STACK.md` — persona format, voice-kit structure, subagent constraints
- `.planning/research/ARCHITECTURE.md` — conductor integration, budget-plan flow, spawn-list mechanics
- `.planning/research/PITFALLS.md` — P-01 (persona dilution), P-06 (Chair contradiction overflow), P-08 (composite-target frequency), P-11 (Executive Sponsor register drift)

### Existing persona templates (v1.0 — follow these patterns)
- `agents/security-reviewer.md` — canonical bench persona agent file (frontmatter + voice + review protocol + worked examples)
- `persona-metadata/security-reviewer.yml` — canonical bench sidecar (tier, triggers, primary_concern, blind_spots, characteristic_objections, banned_phrases)
- `agents/AUTHORING.md` — persona authoring guide (structure, rules, examples)
- `skills/persona-voice/PERSONA-SCHEMA.md` — validator rule definitions (R1-R9, W1-W3)
- `skills/persona-voice/SKILL.md` — voice rubric (tone tags, banned-phrase discipline, worked-example requirements)

### Code surfaces Phase 4 modifies
- `commands/review.md` — conductor entrypoint; bench whitelist at line ~304 (Phase 6 bench fan-out section); `BENCH_SPAWN_LIST` mechanics
- `bin/dc-budget-plan.sh` — budget plan; reads `bench_priority_order` from config.json; computes `BENCH_SPAWN_LIST`; Phase 4 adds `always_invoke_on` reading
- `scripts/validate-personas.sh` — persona validator; R1-R9 + W1-W3; Phase 4 extends with voice-distinctness overlap check
- `scripts/test-chair-synthesis.sh` — Chair synthesis test; Phase 4 adds 10-persona fixture
- `.github/workflows/ci.yml` — Phase 4 adds adversarial Exec Sponsor fixture step

### Phase 3 outputs consumed by Phase 4
- `lib/signals.json` — 21 entries including the 5 new signal IDs referenced by Phase 4 persona sidecars
- `config.json` — `.budget.bench_priority_order` 9-entry array (Phase 4 personas must appear in this list)
- `agents/artifact-classifier.md` — Haiku whitelist at 8 slugs (Phase 4 personas must be routable by Haiku)

### Prior phase context (decisions carried forward)
- `.planning/phases/03-classifier-extension/03-CONTEXT.md` — D-01 (Haiku whitelist 8 slugs), D-09 (bench_priority_order), D-12 (Junior Eng outside priority system)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Persona agent template** (`agents/security-reviewer.md`): 3-section structure (voice paragraph + "How you review" + "## Findings" output format + "## Examples"). All 6 new personas follow this exact structure.
- **Sidecar template** (`persona-metadata/security-reviewer.yml`): YAML with tier, triggers, primary_concern, blind_spots, characteristic_objections, banned_phrases. Phase 4 adds `always_invoke_on` field (JE only).
- **validate-personas.sh**: Already validates R1-R9 + W1-W3. Phase 4 extends with voice-distinctness overlap check (new rule, warn-mode).
- **test-chair-synthesis.sh**: Existing 8-persona fixture. Phase 4 extends to 10-persona.
- **bin/dc-budget-plan.sh**: Reads `bench_priority_order` from config.json, computes ordered `BENCH_SPAWN_LIST`. Phase 4 adds `always_invoke_on` field reading.

### Established Patterns

- **Bench persona wiring**: Signal ID in signals.json → trigger in sidecar → classifier matches → budget plan orders → conductor spawns. Phase 4 personas follow this exact pipeline (except JE which bypasses via `always_invoke_on`).
- **Chair synthesis**: Chair reads all persona scorecards, produces ## Contradictions + ## Top-3 Blockers. Existing strictness check (`dc-validate-synthesis.sh`) enforces no composite targets. Phase 4 verifies this holds at 10-persona scale.
- **Adversarial fixtures**: v1.0 used injection-corpus fixtures. Phase 4 adds Exec Sponsor adversarial fixture following the same pattern (dedicated fixture dir + assertion script).

### Integration Points

- `commands/review.md` line ~304: bench fan-out loop iterates `BENCH_SPAWN_LIST` — Phase 4 expands this from max-4 to max-9
- `bin/dc-budget-plan.sh` line 72: `PRIORITY_ORDER_JSON` fallback array — Phase 4 ensures the 9-entry config.json array is the primary source (fallback stays at old 4-entry for backward compat)
- `scripts/validate-personas.sh`: Phase 4 adds voice-distinctness overlap check as a new validation pass after R1-R9

</code_context>

<specifics>
## Specific Ideas

- **Executive Sponsor adversarial fixture** must be a plan artifact that contains strategic nominalizations ("align stakeholders", "unlock value", "north star metric") but with ZERO quantified claims (no dollar amounts, no dates, no customer counts). The persona must either find a specific quantifiable gap ("no budget estimate for the migration") or correctly emit `findings: []` with an explanatory Summary ("artifact lacks quantifiable claims to evaluate").

- **Junior Engineer voice** per CORE-EXT-01: primary signal is first-person comprehension failure ("I had to re-read this three times to understand the flow"). NOT docstring-nannying or style linting. Banned from Staff Engineer's simplification register. The voice should sound like a smart junior who is genuinely confused, not a linter.

- **Competing Team Lead** per BNCH2-05: MUST name a specific consumer (team, repo, service, endpoint). Framed as shared-infra reviewer, not turf-warrior. The voice should sound like a team lead who is worried about their team's integration breaking, not someone defending territory.

- **Compliance Reviewer** starter citations: GDPR Art. 5(1)(e) (storage limitation), HIPAA §164.312(b) (audit controls), SOC2 CC7.2 (system operations monitoring), PCI Req 10 (track and monitor access). Executor may expand beyond these based on artifact content.

</specifics>

<deferred>
## Deferred Ideas

- **Real-artifact blinded-reader evaluation** on anaconda-platform-chart or outerbounds-data-plane — deferred to Phase 7 UAT (REL-01, REL-02). Phase 4 uses synthetic fixture only.
- **Block-mode voice-distinctness validation** — deferred to v1.2 after real-world calibration. v1.1 uses warn-mode only.
- **Three-artifact gradient for Exec Sponsor adversarial testing** — one temptation artifact is sufficient for Phase 4. Gradient testing can be added in v1.2 if persona discipline proves fragile.
- **Parameterized fixture generator** for N-persona Chair tests — overkill for one-time jump from 8 to 10. Consider if persona count grows again in v1.2+.
- **`userConfig.custom_personas_dir`** — deferred to v1.2. Phase 4 ships stock personas only.

</deferred>

---

*Phase: 04-six-personas-atomic-conductor-wiring*
*Context gathered: 2026-04-28*
