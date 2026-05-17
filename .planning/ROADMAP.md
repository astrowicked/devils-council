# Roadmap: devils-council

## Milestones

- ✅ **v1.0 MVP** — Phases 1-8, 63/63 requirements shipped (2026-04-22 → 2026-04-24 as v1.0.0/1/2)
- ✅ **v1.1 Expansion + Hardening** — Phases 1-7, 35/35 requirements shipped (2026-04-24 → 2026-05-01 as v1.1.0)
- ✅ **v1.2 OpenCode Compatibility** — Phases 1-6, 8/8 requirements shipped (2026-05-12 → 2026-05-17 as v1.4.0–v1.6.0)

## Milestone v1.2 — OpenCode Compatibility (COMPLETE)

**Goal:** Ship devils-council as a dual-runtime plugin — pragmatic port to OpenCode with core 4 + Chair + 4 high-value bench personas, structured scorecard output, signal-driven selection via TypeScript plugin hooks, and speckit integration.

**Status:** COMPLETE. All 6 phases executed, all 8 requirements met. Shipped incrementally as v1.4.0 (full command set), v1.5.0 (self-eval), v1.5.1 (cache invalidation), v1.5.2 (OMO discovery), v1.6.0 (self-eval improvements + persona gaps closed).

**Deviation from plan:** The original plan assumed a strict phase-by-phase execution. In practice, the work was delivered iteratively across sessions — each phase's plan was executed but the roadmap checkboxes weren't updated in real-time. All summaries exist.

**Key constraint:** Claude Code plugin remains unchanged and fully functional. OpenCode support is additive. Shared persona markdown is the source of truth for both runtimes.

## v1.2 Phases

- [x] **Phase 1: OpenCode Plugin Scaffold** — npm package scaffold, plugin entry point, build script
  - Requirements: OC-SCAFFOLD-01, OC-SCAFFOLD-02
  - Plans: 01-01-PLAN.md ✓

- [x] **Phase 2: Persona Adaptation** — Core 4 + Chair as OpenCode agents, orchestration model
  - Requirements: OC-PERSONA-01, OC-PERSONA-02
  - Plans: 02-01-PLAN.md ✓

- [x] **Phase 3: Signal Detection + Persona Selection** — TypeScript signal classifier, 4 bench personas
  - Requirements: OC-SIGNAL-01, OC-BENCH-01
  - Plans: 03-01-PLAN.md ✓

- [x] **Phase 4: Review Command + Scorecard Output** — Structured scorecard, evidence enforcement
  - Requirements: OC-REVIEW-01, OC-SCORE-01
  - Plans: 04-01-PLAN.md ✓

- [x] **Phase 5: Speckit Integration Hook** — Extension config, plugin wiring
  - Requirements: OC-SPECKIT-01
  - Plans: 05-01-PLAN.md ✓

- [x] **Phase 6: Dual-Runtime CI** — OpenCode TS tests, signal parity, build validation
  - Requirements: OC-CI-01
  - Plans: 06-01-PLAN.md ✓

## v1.2 Requirements

| ID | Requirement | Phase | Status |
|----|-------------|-------|--------|
| OC-SCAFFOLD-01 | OpenCode plugin loads without errors and registers agents/commands | 1 | ✅ |
| OC-SCAFFOLD-02 | npm package publishable and installable via `opencode.json` `plugin` array | 1 | ✅ |
| OC-PERSONA-01 | Core 4 personas produce voice-differentiated critique in OpenCode | 2 | ✅ |
| OC-PERSONA-02 | Chair synthesis produces contradictions-first summary with finding IDs | 2 | ✅ |
| OC-SIGNAL-01 | Signal detection triggers correct bench personas based on artifact content | 3 | ✅ |
| OC-BENCH-01 | 4 bench personas (Security, FinOps, Air-Gap, Performance/Dual-Deploy) activated by signals | 3 | ✅ |
| OC-REVIEW-01 | `/review` command produces structured scorecard matching Claude Code output format | 4 | ✅ |
| OC-SCORE-01 | Scorecard enforces evidence (verbatim quotes), bans generic phrases, uses severity tiers | 4 | ✅ |
| OC-SPECKIT-01 | Devils-council triggers automatically as post-plan quality gate in speckit workflow | 5 | ✅ |
| OC-CI-01 | CI tests both runtimes; shared fixtures produce equivalent scorecards | 6 | ✅ |
