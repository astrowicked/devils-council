# Roadmap: devils-council

## Milestones

- ✅ **v1.0 MVP** — Phases 1-8, 63/63 requirements shipped (2026-04-22 → 2026-04-24 as v1.0.0/1/2)
- 📋 **v1.1 Expansion + Hardening** — Phases 1-7 (this milestone; phase numbering reset)

## Milestone v1.1 — Expansion + Hardening

**Goal:** Expand bench coverage (4 → 9 personas), ship custom-persona scaffolder, spike Codex `--output-schema` enforcement for Security deep scans, and close v1.0 tech-debt including the v1.0.0 P0 shell-inject regression class.

**Granularity:** standard
**Requirement coverage:** 35/35 mapped (0 orphans)
**Structure:** 7 phases, ~19-20 plans total, ~40% of v1.0's 48-plan footprint (feature-additive + hardening)

**Key scoping decision (deviation from research):** SUMMARY.md recommended treating Junior Engineer as core (changing core cardinality 4 → 5, rippling through 6 conductor surfaces). User overrode: **Junior Engineer is bench-tier**, auto-triggered on any `code-diff` artifact (no classifier signal required). This keeps core cardinality at 4 and localizes cardinality changes to bench-list expansion (4 → 9). P-07's six-surface atomic change narrows to a simpler bench-list expansion wiring, still handled atomically in Phase 4.

## Phases

- [ ] **Phase 1: Tech-Debt Foundation** — Close v1.0 audit items (TD-01..07) before any persona work can safely touch `commands/review.md` or land new agents/*.md files
- [ ] **Phase 2: Codex `--output-schema` Spike** — Go/no-go memo measuring validation rate + latency delta; gates Phase 6 scope (parallelizable with Phase 1)
- [ ] **Phase 3: Classifier Extension** — 5 new signal detectors + `signal_strength` field + `artifact_type` propagation + negative-fixture-first discipline; unblocks Phase 4 persona sidecars (validator R7 gate)
- [ ] **Phase 4: Six Personas + Atomic Conductor Wiring** — 5 new bench personas + Junior Engineer (bench always-invokable on code-diff) + bench whitelist expansion 4 → 9 + adversarial Executive Sponsor fixture + voice-distinctness validator
- [ ] **Phase 5: Scaffolder Skill** — `skills/create-persona/SKILL.md` with `AskUserQuestion` flow, fixture-validated triggers, voice-rubric coaching
- [ ] **Phase 6: Codex Schema Rollout** — Conditional on Phase 2 GO; wires `--output-schema` behind feature-detect with schemaless fallback preserved
- [ ] **Phase 7: Integration UAT + Release** — Real-artifact 9-bench run + blinded-reader + 9-bench budget-cap test + v1.1.0 tag + GitHub Release

## Phase Details

### Phase 1: Tech-Debt Foundation

**Goal:** All v1.0 audit-flagged tech debt is closed before Phase 4 starts editing `commands/review.md` or landing new persona files
**Depends on:** Nothing (first v1.1 phase; parallelizable with Phase 2)
**Requirements:** TD-01, TD-02, TD-03, TD-04, TD-05, TD-06, TD-07
**Success Criteria** (what must be TRUE):
  1. `scripts/validate-shell-inject.sh` exits 0 on the current clean `commands/review.md` AND exits 1 on the v1.0.0 P0 regression fixture (TD-04 smoke-test gate before hook wiring)
  2. Running the Phase 8 08-UAT known-good Chair synthesis through the updated `dc-validate-synthesis.sh` still exits 0 (TD-05 does not break v1.0 passing outputs; P-08 prevention)
  3. `agents/AUTHORING.md` exists; `agents/README.md` does not; `grep -r "agents/README" agents/ scripts/ bin/ hooks/ lib/ .claude-plugin/ .github/ --include="*.md" --include="*.sh" --include="*.yml" --include="*.json"` returns zero matches in live runtime code paths (TD-06 reference-sweep complete; P-10 prevention — historical references in .planning/ and v1.0 archive preserved per Plan 01-02 Task 3 authorization, narrowed scope approved 2026-04-25)
  4. README troubleshooting section documents `/plugin marketplace update` as a refresh prerequisite; CHANGELOG v1.1 entry notes this explicitly (TD-07)
  5. Phase 1 + Phase 4 VERIFICATION.md and Phase 5 VALIDATION.md files are flipped to `passed` with cited evidence (v1.0.x release chain, 08-UAT.md, CI green signals for TD-01/02/03)
**Plans:** 4 plans in 3 waves (batch structure per CONTEXT.md D-14)

- [x] 01-01-PLAN.md — Batch 1 (Wave 1, parallel): TD-01/02/03/07 doc-only flips (Phase 1 + Phase 4 VERIFICATION, Phase 5 VALIDATION retroactive flips; README troubleshooting + CHANGELOG v1.1 entry)
- [ ] 01-02-PLAN.md — Batch 2 (Wave 2, parallel with 01-03): TD-06 agents/README.md -> AUTHORING.md rename + validate-personas.sh edit + reference sweep
- [ ] 01-03-PLAN.md — Batch 2 (Wave 2, parallel with 01-02): TD-04 shell-inject dry-run pre-parser + fixtures + allowlist + userConfig.shell_inject_guard + PreToolUse hook (internal smoke-test gate before hook wiring)
- [ ] 01-04-PLAN.md — Batch 3 (Wave 3, isolated): TD-05 Chair prompt forbidden-target-shapes + dc-validate-synthesis.sh composite-target check + 08-UAT regression gate

### Phase 2: Codex `--output-schema` Spike

**Goal:** Measured go/no-go decision on whether Codex `--output-schema` is production-ready for Security persona deep scans; negative result is a valid outcome
**Depends on:** Nothing (parallelizable with Phase 1; no code dependencies)
**Requirements:** CODX-01
**Success Criteria** (what must be TRUE):
  1. `.planning/research/CODEX-SCHEMA-MEMO.md` exists with pinned `codex --version`, a v1 Security scorecard JSON Schema at `templates/codex-security-schema.json`, and measured results from 5+ test delegations (JSON-parse rate, schema-validation rate, latency delta vs baseline)
  2. Memo contains an unambiguous verdict: GO (>95% validation AND <25% latency penalty) | NO-GO (<80% validation OR >2x latency) | WRAPPER (middle ground — adopt schema + add `jsonschema` wrapper validation)
  3. If NO-GO, the negative result is documented with reasons and v1.0 path is preserved unchanged; no Phase 6 work is scheduled
  4. If GO or WRAPPER, the memo includes a rubric for Phase 6 wiring (feature-detect pattern, fallback path, error-class definition)
**Plans:** 1 plan in 1 wave

- [ ] 02-01-PLAN.md — Spike harness + v1 schema + 21-invocation measurement + verdict memo (CODX-01)

### Phase 3: Classifier Extension

**Goal:** Five new signal detectors + priority order are landed in `lib/classify.py` + `lib/signals.json` + `config.json` before any v1.1 persona sidecar can reference them; classifier precision is preserved via negative-fixture discipline
**Depends on:** Phase 1 (TD-04 hook must be safe-wired before signal detectors land; TD-06 rename must be done before signals.json keys are referenced by sidecars in Phase 4)
**Requirements:** CLS-01, CLS-02, CLS-03, CLS-04, CLS-05, CLS-06
**Success Criteria** (what must be TRUE):
  1. `scripts/test-classify.sh` passes with **negative fixtures executing first** (Helm values diff, plain Python function, CSS patch) asserting zero evidence on all 5 new signals BEFORE positive fixtures run (inverted TDD; CI step order enforces this)
  2. `lib/signals.json` contains 5 new signal entries each with `signal_strength: strong | moderate | weak`, `target_personas[]`, and `artifact_type` gates where applicable (e.g., `exec_keywords` fires only on `plan | rfc | design`, never on `code-diff`)
  3. `config.json .budget.bench_priority_order` contains an explicit 9-entry ordering with rationale in a comment/sidecar doc (recommended: security > compliance > dual-deploy > performance > finops > air-gap > test-lead > executive-sponsor > competing-team-lead)
  4. Haiku classifier whitelist (in `agents/artifact-classifier.md`) is expanded from 4 to 8 bench slugs (Junior Eng excluded from Haiku — always-invokable path, not signal-driven)
  5. `lib/classify.py` extension adds `artifact_type` parameter propagated from `bin/dc-prep.sh` MANIFEST through `classify()`; call signature backward-compatible with v1.0 detectors
**Plans:** TBD (estimated 2 — signals + detectors; priority-order + Haiku whitelist + tests)

### Phase 4: Six Personas + Atomic Conductor Wiring

**Goal:** 6 new persona files (5 bench + Junior Eng as bench always-invokable) land with voice-differentiated output that survives blinded-reader at scale; conductor wires cleanly in an atomic cardinality change
**Depends on:** Phase 1 (TD-05 Chair strictness must land before 9-bench runs hit composite-target frequency; TD-06 rename must be done or plugin-loader mis-classification grows 1 → 7), Phase 3 (validator R7 blocks sidecars referencing non-existent signal keys)
**Requirements:** BNCH2-01, BNCH2-02, BNCH2-03, BNCH2-04, BNCH2-05, CORE-EXT-01, PQUAL-01, PQUAL-02, PQUAL-03
**Success Criteria** (what must be TRUE):
  1. All 6 new persona files in `agents/` + matching sidecars in `persona-metadata/` pass `scripts/validate-personas.sh` (R1-R9 + W1-W3) with zero warnings; bench whitelist in `commands/review.md` is expanded from 4 to 9 entries as a single atomic commit
  2. Adversarial Executive Sponsor CI fixture (strategic-register plan with NO quantification) makes CI fail when persona emits any banned nominalization (`strategic considerations`, `alignment concerns`, `risk factors` without a named risk); persona correctly produces either a cited-number finding OR `findings: []` with explanatory Summary — proving discipline is tested, not just declared (P-11 prevention)
  3. Voice-distinctness validator (extension to `scripts/validate-personas.sh`) flags any persona pair with >40% banned-phrase overlap or >30% characteristic-objection overlap; passes on the 9-persona bench roster in warn-mode
  4. Blinded-reader evaluation on a 6+ persona run correctly attributes ≥80% of scorecards to the right persona (PQUAL-03; proves voice differentiation scales; tested as Phase-4-internal fixture before Phase 7 UAT)
  5. **Core cardinality stays at 4** — `grep -c "^tier: core$" persona-metadata/*.yml` returns 4 (staff-engineer, sre, product-manager, devils-advocate); Junior Engineer sidecar declares `tier: bench` with `always_invoke_on: [code-diff]`; no code path assumes core cardinality changed
  6. Chair synthesis on a 9-persona test artifact produces `## Contradictions` section with ≤ 5 entries (P-06 prevention; 10-persona Chair fixture in `scripts/test-chair-synthesis.sh`)
**Plans:** TBD (estimated 6-7 — one per persona file authoring, one atomic conductor-wiring plan, one for adversarial/distinctness fixtures; Compliance needs a control-ID research pass, Executive Sponsor ships last so it can defer to v1.1.1 if iteration slips)

### Phase 5: Scaffolder Skill

**Goal:** Users can scaffold a schema-valid persona via an interactive `AskUserQuestion`-driven flow that passes `validate-personas.sh` on first run and coaches voice-kit quality beyond schema validity
**Depends on:** Phase 4 (the 9-persona roster informs the scaffolder's calibration examples; adversarial-fixture design from Phase 4 informs voice-rubric validation heuristics)
**Requirements:** SCAF-01, SCAF-02, SCAF-03, SCAF-04, SCAF-05
**Success Criteria** (what must be TRUE):
  1. `skills/create-persona/SKILL.md` uses `AskUserQuestion` for every structured field (tier, primary_concern, characteristic_objections, banned_phrases, worked-example findings); refuses to write without at least 2 good-finding + 1 bad-finding examples, ≥3 characteristic objections, and ≥5 banned phrases
  2. Scaffolder writes to `${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/` with `agents/` and `persona-metadata/` as siblings; `scripts/validate-personas.sh` run from the workspace path exits 0 before the skill declares success (P-03 prevention)
  3. `render-persona.py` heuristic validator rejects noun-phrase `primary_concern` (must end with `?`), rejects `characteristic_objections` containing any of the persona's own `banned_phrases`, and warns when chosen banned-phrase set has >30% overlap with any shipped persona (voice-rubric coaching)
  4. `scripts/test-persona-scaffolder.sh` exercises both a scripted-input pass case (produces a schema-valid persona) and a weak-input reject case (scaffolder blocks with a specific field-level error, does not write a passing-but-useless persona)
  5. README + CHANGELOG v1.1 document the scaffolder workflow with `${CLAUDE_PLUGIN_DATA}` path + move-to-project instructions (v1.2 replaces this with `userConfig.custom_personas_dir`)
**Plans:** TBD (estimated 2 — skill + render-persona.py; test-persona-scaffolder.sh + README docs)

### Phase 6: Codex Schema Rollout *(conditional on Phase 2 outcome)*

**Goal:** If Phase 2 returned GO or WRAPPER: `--output-schema` is wired into `bin/dc-codex-delegate.sh` with feature-detect + schemaless fallback preserved, and CI captures Codex version to prevent silent degradation
**Depends on:** Phase 2 (GO/WRAPPER verdict); if NO-GO, this phase is a no-op with scope closed via negative-result doc
**Requirements:** CODX-02, CODX-03, CODX-04
**Success Criteria** (what must be TRUE):
  1. If Phase 2 = NO-GO: this phase is closed with a single documented note in Phase 6 SUMMARY.md citing the memo's negative verdict; `bin/dc-codex-delegate.sh` is unchanged; CODX-02 and CODX-03 are marked as "deferred pending future Codex release"
  2. If Phase 2 = GO or WRAPPER: `bin/dc-codex-delegate.sh` invokes `codex exec --output-schema <path>` only when the schema file exists AND `codex --version` is at or above the pinned minimum; schemaless path is the silent fallback
  3. `lib/codex-schemas/security.json` ships with the v1 Security scorecard schema from Phase 2 memo; MANIFEST.json captures `delegation.codex_schema_version` on every delegation (P-04 prevention)
  4. `codex_schema_validation_error` added to D-51 error enum; errors are logged but never silently degrade Security persona output (persona can still emit findings from schemaless path if schema path fails)
  5. `scripts/test-codex-schema-spike.sh` runs in every CI build covering both the schema-enforced path AND the fallback path (conditional on Phase 2 verdict)
**Plans:** TBD (estimated 1, conditional; no-op if Phase 2 NO-GO)

### Phase 7: Integration UAT + Release

**Goal:** v1.1.0 ships after a real-artifact review exercising the full 9-bench roster validates that cap, synthesis, and voice-distinctness all hold under load
**Depends on:** Phases 1, 3, 4, 5, and optionally 6
**Requirements:** REL-01, REL-02, REL-03, REL-04
**Success Criteria** (what must be TRUE):
  1. Real-artifact review on an `anaconda-platform-chart` or `outerbounds-data-plane` artifact runs with all 9 bench personas available, respects hard budget cap (9 → 6 selection by `bench_priority_order` with at least 3 personas skipped with `reason: budget_cap` correctly rendered), Chair synthesis produces ≤ 3 Top-3 blockers with no composite targets, and no persona produces a generic finding (08-UAT-style evidence review)
  2. Blinded-reader evaluation on the same 6+ persona run achieves ≥ 80% persona-attribution accuracy (PQUAL-03 at scale; P-01 persona dilution prevention verified empirically)
  3. 9-bench budget-cap scenario test case exists in `scripts/test-budget-cap.sh` asserting correct top-6 selection by priority_order when all 9 signals fire simultaneously; passes in CI
  4. CI preflight on v1.1.0 candidate runs the full matrix green: classifier (positive + negative fixtures) + persona validation + injection corpus + coexistence (GSD + Superpowers) + scaffolder validity + 9-bench budget cap + adversarial Executive Sponsor fixture
  5. `1.1.0` annotated git tag + GitHub Release + CHANGELOG v1.1.0 section exist and document: 6 new personas, scaffolder, Codex schema verdict (GO/NO-GO/WRAPPER), and all 7 TD closeouts
**Plans:** TBD (estimated 2 — UAT + blinded-reader measurement; version bump + tag + release + CHANGELOG)

## Phase Dependency Graph

```
  Phase 1 (TD foundation)  ──┐
                              ├──→ Phase 4 (personas; needs TD-05 + TD-06 done, bench whitelist expanded)
  Phase 3 (classifier)   ────┘
                                   │
  Phase 2 (Codex spike) ──→ Phase 6 (Codex rollout; conditional on spike verdict)
                                   │
  Phase 5 (scaffolder) ────────────┤
                                   ↓
                            Phase 7 (UAT + release)
```

**Parallelizable:**
- Phase 1 and Phase 2 (no code dependencies between them; Phase 2 is memo-only)
- Phase 1 TD-items TD-02, TD-03, TD-06, TD-07 are independent of each other within Phase 1

**Sequential constraints (dependency gates):**
- Phase 4 persona sidecars cannot commit until Phase 3 lands signals.json entries (validator R7 gate via PreToolUse hook)
- Phase 4 cannot safely edit `commands/review.md` until Phase 1 TD-04 shell-inject pre-parser is smoke-tested green (P-09 prevention)
- Phase 4 Chair-synthesis stress tests require Phase 1 TD-05 strictness landed first (P-08 prevention)
- Phase 6 scope depends entirely on Phase 2 verdict (NO-GO = no-op phase)
- Phase 7 UAT requires Phases 1, 3, 4, 5 complete (+ Phase 6 if GO/WRAPPER)

## Progress

| Phase | Milestone | Plans Complete | Status      | Completed  |
| ----- | --------- | -------------- | ----------- | ---------- |
| 1-8   | v1.0      | 48/48          | Complete    | 2026-04-24 |
| 1     | v1.1      | 1/4 | Complete    | 2026-04-25 |
| 2     | v1.1      | 0/1            | Not started | —          |
| 3     | v1.1      | 0/TBD          | Not started | —          |
| 4     | v1.1      | 0/TBD          | Not started | —          |
| 5     | v1.1      | 0/TBD          | Not started | —          |
| 6     | v1.1      | 0/TBD          | Not started | —          |
| 7     | v1.1      | 0/TBD          | Not started | —          |

## Previous Milestones

<details>
<summary>✅ v1.0 MVP (Phases 1-8) — SHIPPED 2026-04-24</summary>

- [x] Phase 1: Plugin Scaffolding + Codex Setup (5/5 plans) — completed 2026-04-22
- [x] Phase 2: Persona Format + Voice Scaffolding (4/4 plans) — completed 2026-04-22
- [x] Phase 3: One Working Persona End-to-End + Review Engine Core (5/5 plans) — completed 2026-04-22
- [x] Phase 4: Remaining Core Personas (7/7 plans) — completed 2026-04-23
- [x] Phase 5: Council Chair + Synthesis (5/5 plans) — completed 2026-04-23
- [x] Phase 6: Classifier + Bench Personas + Cost Instrumentation (8/8 plans) — completed 2026-04-23
- [x] Phase 7: Hardening + Injection Defense + Response Workflow (8/8 plans) — completed 2026-04-23
- [x] Phase 8: GSD Hook Integration + Dig-In + Docs + Release (6/6 plans) — completed 2026-04-24

Full details: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)
Requirements: [milestones/v1.0-REQUIREMENTS.md](milestones/v1.0-REQUIREMENTS.md)
Audit: [milestones/v1.0-MILESTONE-AUDIT.md](milestones/v1.0-MILESTONE-AUDIT.md)

</details>
