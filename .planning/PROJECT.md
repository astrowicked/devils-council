# devils-council

## What This Is

A Claude Code plugin that provides a persona-driven adversarial review layer for plans, code, and design artifacts. Multiple personas (Staff Engineer, SRE, PM, Devil's Advocate, plus context-triggered specialists like Security, FinOps, Air-Gap Reviewer) critique work from their perspective, producing a structured scorecard that surfaces pushback, anti-overengineering signals, operational gaps, and business misalignment before work lands.

## Core Value

Catch weak plans, overengineered designs, and business misalignment *before* execution — by surfacing the pushback a senior engineering org would give, in a form the author can respond to.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Plugin scaffolding + installable from GitHub
- [ ] Persona file format (markdown + frontmatter) loaded dynamically
- [ ] Four always-on core personas: Staff Engineer (pragmatist), SRE/On-call, Product Manager, Devil's Advocate
- [ ] Bench personas for v1: Security Reviewer, FinOps Auditor, Air-Gap Reviewer, Dual-Deploy Reviewer
- [ ] Auto-trigger logic: bench personas join based on artifact signals (auth code → Security, new AWS resources → FinOps, Helm values → Dual-Deploy, etc.)
- [ ] `/devils-council review <artifact>` standalone command
- [ ] Council Chair persona that synthesizes scorecards and flags contradictions
- [ ] Output: structured scorecard (raw per-persona) + Chair synthesis, both visible, with option to dig into any persona
- [ ] Supports reviewing plans, code diffs, and design/RFC documents
- [ ] Codex CLI integration: personas (especially Security) can delegate deep code scans to Codex
- [ ] GSD hook points wired but opt-in (extend `gsd-plan-checker` and `gsd-code-reviewer`)
- [ ] Personas critique both Claude and the user, per artifact

### Out of Scope (v1)

- Gemini integration — deferred; `consulting-design-skill` already covers this path
- Remaining bench personas (Compliance, Junior Eng, Performance, Test Lead, Executive Sponsor, Competing Team Lead, etc.) — v1.1
- Custom persona authoring UX — v1.1
- Non-Claude-Code runtimes (Codex CLI, Gemini CLI, OpenCode as *hosts*) — v1 targets Claude Code plugin only

## Context

- Andy is a Principal Platform Development Engineer working across self-hosted enterprise and SaaS deployments at Anaconda, plus homelab infrastructure.
- Existing tooling in Andy's environment that this must compose with:
  - **GSD plugin** — spec-driven development workflow with plan-checker, code-reviewer, verifier agents
  - **Superpowers plugin** — brainstorming, TDD, verification skills
  - **consulting-design-skill** — Gemini AI for design alternatives (already installed)
  - **reviewing-code-skill** — Codex AI for code review (present as skill, but Codex CLI itself is NOT yet configured on this machine — setup is in scope for this project)
  - **Claude-Mem** — persistent cross-session memory
- Andy's domain constraints frequently include: air-gapped/self-hosted deployments, dual SaaS+self-hosted support, Helm chart portability, AWS CDK + Terraform, Kubernetes on both EKS and OpenShift, zero-trust networking.
- The persona set reflects real stakeholders and failure modes Andy has encountered; bench personas are weighted toward his domain (Air-Gap, Dual-Deploy) rather than generic roles.

## Constraints

- **Tech stack**: Claude Code plugin format (markdown skills + commands + optional subagents). Personas implemented as subagents or skill-invoked prompts, loaded dynamically from markdown files with YAML frontmatter.
- **Distribution**: Public GitHub repo at `~/dev/devils-council`, installable as a Claude Code plugin. No secrets, no internal customer names in examples.
- **Dependencies**: Codex CLI must be set up as part of v1 (auth, config, smoke test). Gemini CLI deferred.
- **Composability**: Must coexist with GSD and Superpowers without conflicting command names or overriding their hooks unless opted in.
- **Quality**: Personas should produce *non-generic* critique — domain-specific, actionable, with evidence. Generic "have you considered security?" output is a failure mode to actively prevent.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Separate Claude Code plugin (not skill, not inside GSD) | Installable + shareable; clean composition with existing tools | — Pending |
| Always-on core = 4 personas (Staff Eng, SRE, PM, Devil's Advocate), rest on-call | Covers simplicity, operational, business, red-team categories without noise | — Pending |
| Auto-trigger bench personas from artifact signals | Selective per artifact; avoids full-panel fatigue | — Pending |
| Council Chair synthesis + raw scorecards both visible | Andy wants synthesis *and* ability to dig into dissent | — Pending |
| Personas critique both Claude and user | Pre-filter weak objections before user sees, but don't hide pushback directed at user | — Pending |
| Codex CLI integration in v1; Gemini deferred | Codex covers critical code-review delegation; Gemini duplicates existing consulting-design-skill | — Pending |
| Name: `devils-council` | User preference from shortlist (council, agora, roundtable, devils-council, panel) | — Pending |
| GSD hook points wired but opt-in in v1 | Standalone command proves concept; hooks don't force adoption | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-22 after initialization*
