# devils-council

## What This Is

A Claude Code plugin that provides a persona-driven adversarial review layer for plans, code, and design artifacts. 16 personas (4 always-on core: Staff Engineer, SRE, PM, Devil's Advocate + 10 signal-triggered bench: Security Reviewer, FinOps Auditor, Air-Gap Reviewer, Dual-Deploy Reviewer, Compliance Reviewer, Performance Reviewer, Test Lead, Executive Sponsor, Competing Team Lead, Junior Engineer + Council Chair synthesizer + Haiku artifact-classifier) critique work from their perspective, producing structured scorecards with enforced evidence, deterministic classifier-driven selection, hard budget caps, Codex-delegated deep scans for Security + Dual-Deploy, prompt-injection defense, response-suppression workflow (dismissed findings don't re-raise), severity-tiered render, and opt-in GSD hook integration.

## Core Value

Catch weak plans, overengineered designs, and business misalignment *before* execution — by surfacing the pushback a senior engineering org would give, in a form the author can respond to.

**Still correct after v1.0:** Yes. 08-UAT.md real-artifact run (reviewing Phase 3 03-00-PLAN.md) produced 13 findings across 4 personas with voice-differentiated output — the anti-generic property holds.

## Current Milestone: v1.1 Expansion + Hardening

**Goal:** Expand persona coverage to 10 bench personas (6 new), give users a path to author their own via a scaffolder skill, tighten the injection-defense class that slipped v1.0.0, and spike Codex `--output-schema` enforcement for Security deep scans.

**Target features:**

- 6 new bench personas: Compliance, Junior Eng, Performance, Test Lead, Executive Sponsor, Competing Team Lead (5 with new classifier signals; Junior Eng always-invokable)
- `skills/create-persona/SKILL.md` — interactive scaffolder that writes schema-valid `agents/*.md` passing `validate-personas.sh` on first run
- Codex `--output-schema` spike for Security persona (go/no-go memo in Phase 1; rollout or document negative result)
- Tech debt bundle from v1.0 audit: TD-02, TD-03, TD-04, TD-05, TD-06, TD-07 (folded in; no separate v1.0.3 line)

## Current State (as of Phase 5 completion)

**Shipped:** v1.0.2 (2026-04-24) — release chain v1.0.0 → v1.0.1 → v1.0.2, all tagged + GitHub Releases live.
**Installable:** `/plugin marketplace add astrowicked/devils-council && /plugin install devils-council@devils-council`
**CI:** 7-step pipeline green on every push (plugin validate, persona validation, injection corpus, fixture-based quality tests, coexistence matrix, exec-sponsor adversarial, blinded-reader readiness).
**Personas:** 4 core + 10 bench (6 new in Phase 4: Compliance, Performance, Test Lead, Executive Sponsor, Competing Team Lead, Junior Engineer). Conductor wired 4→9 bench whitelist + always_invoke_on for Junior Engineer.
**Scaffolder:** `skills/create-persona/SKILL.md` — 475-line interactive AskUserQuestion wizard with voice-kit coaching, >30% overlap detection, validate-personas.sh integration. Test harness (3 groups: pass/reject/overlap) all green.
**Phase 5 complete:** 2026-04-28 — scaffolder skill + test harness + README/CHANGELOG docs.

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

### Active (v1.1 — in scope)

**New bench personas (6):**
- [x] Compliance Reviewer — policy/audit/regulation signals (GDPR/HIPAA/SOC2, data retention/residency) — Validated in Phase 4
- [x] Junior Engineer — always-invokable (no signal); readability, naming, "I don't understand this" flags — Validated in Phase 4
- [x] Performance Reviewer — N+1 patterns, hot-path allocation, loops-over-collections signals — Validated in Phase 4
- [x] Test Lead — src-without-test + test-without-src imbalance, flaky patterns, coverage gaps — Validated in Phase 4
- [x] Executive Sponsor — cost/budget/timeline/roadmap keywords; ROI, opportunity cost, strategic alignment — Validated in Phase 4
- [x] Competing Team Lead — shared-infra + API-contract change signals; blast radius, coordination cost — Validated in Phase 4

**Authoring UX:**
- [x] `skills/create-persona/SKILL.md` — interactive scaffolder writing schema-valid `agents/*.md` passing `validate-personas.sh` on first run — Validated in Phase 5

**Codex hardening:**
- [ ] Codex `--output-schema` spike for Security (Phase 1 deliverable: go/no-go memo; if green, rollout + CI fixture)

**Tech debt bundle (all folded into v1.1):**
- [ ] TD-02: Phase 1 + Phase 4 VERIFICATION.md formal flip (cite v1.0.x release chain + 08-UAT evidence)
- [ ] TD-03: Phase 5 Nyquist retroactive validation
- [ ] TD-04: Slash-command shell-inject dry-run pre-parser (the v1.0.0 P0 class)
- [ ] TD-05: Chair Top-3 target-field strictness (dc-validate-synthesis.sh composite-target fix)
- [ ] TD-06: Rename `agents/README.md` → `agents/AUTHORING.md`
- [ ] TD-07: README troubleshooting — `/plugin marketplace update` refresh step

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
- **Known quirks discovered in v1.0:**
  - Claude Code's plugin loader treats any `agents/*.md` as a subagent — `agents/README.md` is mis-classified (TD-06)
  - `/plugin marketplace add` caches the marketplace descriptor; users need `/plugin marketplace update` before reinstall picks up new tags (TD-07)
  - `!<cmd>` explanatory backtick blocks in `commands/*.md` are parsed as shell-injection (caused v1.0.0 → v1.0.1 hotfix; TD-04 targets a dry-run pre-parser)

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
