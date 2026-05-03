# devils-council

## What This Is

A Claude Code plugin that provides a persona-driven adversarial review layer for plans, code, and design artifacts. 16 personas (4 always-on core: Staff Engineer, SRE, PM, Devil's Advocate + 10 signal-triggered bench: Security Reviewer, FinOps Auditor, Air-Gap Reviewer, Dual-Deploy Reviewer, Compliance Reviewer, Performance Reviewer, Test Lead, Executive Sponsor, Competing Team Lead, Junior Engineer + Council Chair synthesizer + Haiku artifact-classifier) critique work from their perspective, producing structured scorecards with enforced evidence, deterministic classifier-driven selection, hard budget caps, Codex-delegated deep scans for Security + Dual-Deploy, prompt-injection defense, response-suppression workflow (dismissed findings don't re-raise), severity-tiered render, and opt-in GSD hook integration.

## Core Value

Catch weak plans, overengineered designs, and business misalignment *before* execution — by surfacing the pushback a senior engineering org would give, in a form the author can respond to.

**Still correct after v1.1:** Yes. Phase 7 UAT live run (reviewing anaconda-platform-chart fixture) produced 10 persona scorecards with voice-differentiated output, budget-cap enforcement, and Chair synthesis validation. The anti-generic property holds at 16-persona scale.

## Current State (as of v1.1.0)

**Shipped:** v1.1.0 (2026-05-01) — release chain v1.0.0 → v1.0.1 → v1.0.2 → v1.1.0, all tagged + GitHub Releases live.
**Installable:** `/plugin marketplace add astrowicked/devils-council && /plugin install devils-council@devils-council`
**CI:** 34-step pipeline green on Ubuntu + macOS (plugin validate, persona validation, injection corpus, classifier positive/negative, budget-cap, codex delegation + schema, scaffolder, coexistence, engine smoke, Chair synthesis + strictness, blinded-reader, shell-inject, severity render, responses suppression, GSD hooks, on-plan/on-code, dig-spawn, exec-sponsor adversarial).
**Personas:** 4 core + 10 bench + Chair + classifier = 16 total. 21 classifier signals. 9-entry bench priority order with hard budget cap.
**Scaffolder:** `/devils-council:create-persona` — interactive AskUserQuestion wizard with voice-kit coaching.
**Codex:** `--output-schema` WRAPPER verdict — schema-enforced delegation with feature-detect + schemaless fallback.

## Next Milestone: v1.2 (not started)

**Deferred items:**
- `userConfig.custom_personas_dir` — user-maintained persona library outside plugin cache (survives updates)
- Non-Claude-Code runtime support — Codex CLI, Gemini CLI, OpenCode as plugin hosts

## Requirements

### Validated (v1.0)

- ✓ Plugin scaffolding + installable from GitHub — v1.0
- ✓ Persona file format + voice/scorecard schemas + validator — v1.0
- ✓ `/devils-council:review` end-to-end with isolation + evidence enforcement + injection defense — v1.0
- ✓ All 4 always-on core personas in parallel — v1.0 (blinded-reader + order-swap isolation proven via downstream + Phase 8 UAT)
- ✓ Council Chair contradictions-first synthesis (no scalar verdict, deterministic finding IDs) — v1.0
- ✓ Signal-driven classifier (16 structural detectors) + 4 bench personas + Codex delegation for Security/Dual-Deploy — v1.0
- ✓ Hard budget cap + prompt-cache observability — v1.0
- ✓ Injection corpus (9 fixtures) + schema-enforced drops + coexistence matrix — v1.0
- ✓ Response workflow (accepted/dismissed/deferred) + severity-tiered render with `--show-nits` — v1.0
- ✓ `/devils-council:on-plan`, `/devils-council:on-code`, `/devils-council:dig` + opt-in GSD hook wrappers — v1.0
- ✓ README + CHANGELOG + v1.0.0 GitHub Release — v1.0

### Validated (v1.1)

- ✓ 6 new bench personas (Compliance, Junior Eng, Performance, Test Lead, Executive Sponsor, Competing Team Lead) — v1.1 Phase 4
- ✓ Interactive persona scaffolder (`/devils-council:create-persona`) — v1.1 Phase 5
- ✓ Codex `--output-schema` WRAPPER verdict + rollout — v1.1 Phases 2+6
- ✓ TD-01 through TD-07 tech debt closeouts — v1.1 Phase 1
- ✓ 5 new classifier signals + 9-bench budget-cap enforcement — v1.1 Phases 3+4
- ✓ Integration UAT + v1.1.0 release — v1.1 Phase 7

### Deferred (v1.2+)

- [ ] `userConfig.custom_personas_dir` pointing at user-maintained persona library outside plugin cache (v1.2)
- [ ] Non-Claude-Code runtimes as plugin *hosts* (Codex CLI, Gemini CLI, OpenCode) — v1.x targets Claude Code plugin only

### Out of Scope (still)

- Gemini integration — `consulting-design-skill` already covers this path

## Context

- Andy is a Principal Platform Development Engineer at Anaconda, working across self-hosted enterprise/air-gapped and SaaS deployments, plus homelab infrastructure.
- This plugin was designed for Andy's domain: bench personas weighted toward Air-Gap, Dual-Deploy, FinOps, Security (not generic roles).
- Composes with GSD plugin (spec-driven development) + Superpowers plugin (TDD, brainstorming) + consulting-design-skill (Gemini) + Claude-Mem (cross-session memory). Coexistence verified in CI.
- Codex CLI is configured on Andy's machine (Phase 1 CDEX-01/02/06); deep scans for Security + Dual-Deploy personas delegate via `codex exec --json`.
- **Known quirks (all resolved in v1.1):**
  - ~~`agents/README.md` mis-classified as subagent~~ — renamed to `AUTHORING.md` (TD-06)
  - ~~marketplace cache stale after tag push~~ — README documents `/plugin marketplace update` step (TD-07)
  - ~~shell-injection in explanatory code blocks~~ — dry-run pre-parser + allowlist in CI (TD-04)
- **Known quirk discovered in v1.1:**
  - Claude Code shell-injection timing: sequential `!`backtick blocks may not see filesystem changes from prior blocks. Workaround: conductor fallback invokes `dc-classify.sh` via Bash tool when shell-injection didn't populate MANIFEST

## Constraints

- **Tech stack:** Claude Code plugin format — markdown skills + commands + subagents with YAML frontmatter. Personas as plugin-shipped subagents (`agents/*.md`). Entrypoint via `commands/review.md`.
- **Distribution:** Public GitHub repo `astrowicked/devils-council`, single-repo marketplace. No secrets, no internal customer names.
- **Dependencies:** Codex CLI (`@openai/codex`) for Security + Dual-Deploy deep scans; `jq` + `yq` documented as prerequisites.
- **Composability:** No command/hook/MCP collisions with GSD or Superpowers — verified via `scripts/test-coexistence.sh` in CI.
- **Quality:** Non-generic critique is the failure mode to prevent. Enforced structurally: banned-phrase validator, verbatim-quote evidence requirement, per-persona voice kits with characteristic-objection lists.

## Key Decisions

Representative subset from ~81 decisions logged across phase CONTEXT files (full log in `.planning/milestones/v1.0-ROADMAP.md`):

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Separate Claude Code plugin (not skill, not inside GSD) | Installable + shareable; clean composition | ✓ Good — v1.0.2 shipped |
| Core = 4 always-on personas, rest on-call | Simplicity + operational + business + red-team lens without noise | ✓ Good — 08-UAT confirmed non-generic output |
| Signal-driven classifier (pure functions, 16 detectors) + Haiku fallback | Deterministic persona selection; no LLM dependency for routing | ✓ Good — classifier tests 17/17 green |
| Council Chair synthesis + raw scorecards both visible | User gets synthesis + ability to dig into dissent | ✓ Good — 05-05 test suite verifies |
| Codex delegation for Security + Dual-Deploy only | Targets personas that benefit most from deep scan; avoids Codex as universal dependency | ✓ Good — `--sandbox read-only` proven |
| GSD hooks wired but opt-in (userConfig flag) | Standalone command proves concept; hooks don't force adoption | ✓ Good — no matcher fires when disabled |
| Finding-ID stamping as hash(persona + target + claim) | Stable IDs across runs enable dismiss-and-persist response workflow | ✓ Good — RESP-03 working |
| Severity-tiered render with `--show-nits` | Collapses noise, inlines blockers, lets user expand on demand | ✓ Good — D-71 note discipline working |
| Shell-inject `!<cmd>` for signal detection | Deterministic pre-prompt data injection, not LLM tool-call | ⚠️ Revisit — shipped working but same pattern caused v1.0.0 P0 in an explanatory block (TD-04 tightens this) |
| Phase 7 dedup: delete HARD-03/04 as BNCH-09/10 duplicates; relocate RESP-02 → Phase 8 | Drift caught during execution; amend rather than carry duplicates | ✓ Good — D-62/63/64 |

## Evolution

Document evolves at phase transitions (`/gsd-transition`) and milestone boundaries (`/gsd-complete-milestone`). Pre-v1.0 content archived in `.planning/milestones/v1.0-ROADMAP.md`.

---
*Last updated: 2026-04-28 — Phase 4 complete (6 new personas + conductor wiring + validation suite)*
