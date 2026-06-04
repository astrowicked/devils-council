# Feature Spec: Per-Persona Model Configuration (OpenCode)

**Feature ID:** 001-per-persona-model-config
**Milestone:** v1.3
**Status:** Draft (rev 3 — post-council ×2)
**Spike:** `.planning/spikes/per-persona-model-SPIKE.md` (mechanism + zero-action default both proven 2026-06-03)
**Council reviews:** `./SYNTHESIS.md` (rev 2 — current)

## Overview

Every council persona runs on whatever model the OpenCode session is using. That's wasteful: the Devil's Advocate and the Chair want a strong reasoner, but a nit-level persona on Opus is burning the expensive model for throwaway critique. We want each persona on a right-sized model, with a reasoning `variant` where it helps.

Two spike findings shape the design:

- **Frontmatter `model:` wins over everything.** So we never put a model in shipped persona frontmatter, or we'd lock users out of their own override.
- **A plugin can inject a default via the `config` hook, and the user still overrides it.** The hook receives the resolved config with the user's `opencode.json` already merged, so a *guarded* inject (`if (!agent.model) agent.model = <default>`) applies on install with zero user action and loses cleanly to a user's own `agent.<name>.model`.

So: ship tier-based defaults through the plugin's `config` hook, keep persona frontmatter model-silent, and let users override per-persona in their own `opencode.json`. No paste step.

Model precedence, full:

1. agent frontmatter `model:` — highest; we keep it silent
2. user `opencode.json` `agent.<name>.model`
3. plugin `config`-hook injected default (our zero-action layer)
4. inherited session model

**The hook is runtime code in the user's session, so it has to fail safe.** Any error reading a preset or sidecar, or an injected model that isn't available for the user's provider, falls through to the session model — degraded but never a dead session, never a mid-review 403. Details in the requirements.

This milestone is OpenCode-only. On Claude Code the personas keep inheriting the session model; CC's override mechanism *is* frontmatter, which fights the model-silent rule, so it's its own design and we're deferring it. The named user (Andy) runs `/review` far more on OpenCode, so this covers the bulk of the spend; the CC gap is real but small and tracked.

## Why this is worth doing (cost)

Rough per-`/review` cost on Bedrock. Token counts are conservative *estimates* and get replaced by a real measurement during implementation — the gated round-trip test emits actuals (FR-12), and the success criterion locks to the measured number, not these.

Assumptions: each critic ≈ 5.5K input + 1.5K output; the Chair ≈ 12K input + 2K output (its input grows with council size). Bedrock rates: Opus ~$15/$75 per M, Sonnet ~$3/$15, Haiku ~$1/$5.

| Review profile | All-Opus (status quo) | Tiered | Savings |
|----------------|----------------------|--------|---------|
| **Floor** — 4 core + Chair + 2 bench (7 calls) | ~$1.50 | ~$0.72 (2 Opus, 5 Sonnet) | ~52% |
| **Fan-out** — 4 core + Chair + 5 bench (10 calls) | ~$2.19 | ~$1.10 (Security + DA + Chair on Opus, rest Sonnet) | ~50% |

The savings ratio holds across fan-out because Security is the only bench persona in the deep-reasoning tier; the rest are workhorse (Sonnet). The Chair stays on Opus and its input grows with council size, so it's the residual that *caps* further savings — tiering doesn't touch it (a leaner Chair is a separate, later lever). These are estimates pending the measured number.

## What we're building

- **A tier on each persona.** Every critic persona declares one `model_tier` in its `persona-metadata/*.yml` sidecar, by reasoning need. The artifact-classifier (no critic role) is **exempt** — it runs on the session model.
- **Tier→model defaults in the plugin.** A small map per preset. The `config` hook reads the persona tiers + the active preset and injects `agent.<name>.{model,variant}` for any field the user hasn't set.
- **An explicit preset selector** — a `userConfig` option: `bedrock`, `cheap`, or `off`. No silent provider detection. Unset behaves as `off` and emits a one-line hint that tiering is available. `off` injects nothing.
- **A fail-safe hook** — wraps everything in try/catch, validates injected model IDs against the provider's available models, and falls through to the session model (per persona) on any problem.
- **A model-silent guardrail** — CI fails if any shipped persona gains a frontmatter `model:`, checked against the published tarball.

## Functional requirements

- **FR-01 — Tier tagging.** Every critic persona sidecar declares exactly one `model_tier` from the fixed vocabulary. The artifact-classifier is exempt (lint skips it by name).
- **FR-02 — Tier vocabulary.** Fixed, documented: `deep-reasoning`, `workhorse`, `cheap`.
- **FR-03 — Tier lint.** Lint fails if a critic persona is missing `model_tier` or uses a value outside the vocabulary.
- **FR-04 — Single source of truth.** Resolve whether `persona-metadata/` (root) or `.opencode/persona-metadata/` is authored vs generated *before* tagging; add the field at the source. A CI check fails if the two copies disagree on `model_tier` (or, if one is generated from the other, assert the build output instead — decided in Phase 0).
- **FR-05 — Zero-action default injection (per-field guarded).** The `config` hook injects `agent.<name>.model` only when the user hasn't set `model`, and `agent.<name>.variant` only when the user hasn't set `variant` — independently — using the active preset and the persona's actual shipped agent name.
- **FR-06 — Override wins (per field).** A user's `opencode.json` `agent.<name>.model` and `.variant` each beat the injected default for that field. Verified by spawning and reading the session DB, including the case where the user sets `variant` only and the hook must preserve it.
- **FR-07 — Explicit preset selector.** A `userConfig` option selects `bedrock | cheap | off`. There is **no** silent provider detection. Unset resolves to `off` and emits one visible line that tiering is available and how to enable it. `off` injects nothing (every persona inherits the session model).
- **FR-08 — Fail-safe hook (atomic).** The inject builds the full agent-map in a local and assigns it to config in one step at the end, so a throw partway through can never leave some personas injected and others not. The whole path is `await`ed inside try/catch (no unawaited internal call can escape as an async rejection); on any error (corrupt preset, unparseable sidecar, partial install) it logs one line and returns with config unmutated — every persona falls through to the session model. The corrupt-preset test confirms session creation succeeds **and** that zero personas were injected on the throw path.
- **FR-09 — Injected-model validation.** Before injecting, validate each preset model ID against the provider's available-models list. On a miss, skip injection for that persona (it falls through to the session model) and log which model was unavailable. If the available-models list is not exposed to the plugin, skip injection **entirely** (inject nothing, every persona on the session model, one log line) — degraded but predictable. Do not inject an unvalidated string and rely on catching a mid-review spawn failure.
- **FR-10 — Model-silent guarantee.** No shipped OpenCode persona declares a frontmatter `model:`; `build.sh` never injects one.
- **FR-11 — Guardrail gate (on what ships).** CI fails if a frontmatter `model:` appears in the `npm pack` tarball, not merely the working tree. A post-pack smoke test installs the tarball and exercises the hook.
- **FR-12 — Override-precedence behavioral check.** Instead of a version-string grep, the gated round-trip test (cheap preset) asserts the user-override-wins invariant (the merge-order behavior the design depends on) by spawning with a user override set and confirming via the session DB. It runs nightly **and** on any change to the pinned OpenCode version (lockfile / documented version range), so the invariant is checked at the moment of risk, not up to a day later. Docs state the tested OpenCode version range.
- **FR-13 — Docs.** README documents the tiers, the `bedrock|cheap|off` selector, the precedence table, the fail-safe behavior, and a worked single-persona override (model + variant) shown as a *merge into an existing `agent` block*.

## User scenarios

**End-user (cost-bearing):**

1. **Install, set one option.** Andy installs the plugin and sets the preset to `bedrock`. The next `/review` runs the Devil's Advocate, Security, and Chair on Opus, everyone else on Sonnet. He pasted no model strings.
2. **Override one persona.** He wants Security with `variant: max`. He adds one `agent.security-reviewer` entry to his `opencode.json`. The per-field guard sees it and skips that field; everything else keeps the defaults — including a `variant`-only override, which is preserved.
3. **Off.** A user sets the preset to `off` (or leaves it unset and ignores the hint); every persona inherits the session model.
4. **Bad model, no outage.** A preset model isn't enabled in the user's Bedrock region. Validation catches it, that persona falls through to the session model with a logged line, and the review still runs.

**Contributor / maintainer:**

1. **Add a persona.** A contributor adds a bench persona, sets its `model_tier`, lint passes, and the hook picks it up automatically — no model strings touched.

## Success criteria

- On a fresh install with `bedrock`, a persona spawned during `/review` runs on its tier's model with no per-persona user config, confirmed by the session DB.
- A user override beats the injected default per field — including `variant` set without `model` — confirmed by DB readback.
- Preset `off` (and unset) results in every persona on the session model; unset also emits the enable-tiering hint.
- A corrupt preset file does not prevent session creation or `/review`; an unavailable model falls through to the session model with a log, never a mid-review failure.
- Measured per-review cost on `bedrock` is materially below the all-Opus baseline (target ~halved on a typical review; the real figure from FR-12's test replaces the estimate).
- CI is red if a frontmatter `model:` reaches the published tarball.

## Out of scope

- Claude Code per-persona models (frontmatter-based; conflicts with the model-silent rule). Tracked for a later milestone; `model_tier` is OpenCode-consumed for now. *(If the future CC path also maps tier→model but writes the result into frontmatter at build time, the field is runtime-neutral and there's no real conflict — that's the likely shape; confirm before v1.4.)*
- Silent provider detection (cut — it could only fail silently).
- The standalone generator script (cut — the paste UX it served is gone; the tier→model map is inspectable plugin data).
- `anthropic` preset (deferred until a user needs it; a new preset is one data object).
- Auto-rewriting the user's `opencode.json`.

## Informed defaults

- **Tiers:** `deep-reasoning` = Devil's Advocate, Council Chair, Security; `workhorse` = Staff Engineer, SRE, PM, most bench; `cheap` = Executive Sponsor, Competing Team Lead.
- **Security is deep-reasoning.** Criterion: "pushback is the product." Security's value is the line-cited attack path, which is reasoning-heavy; a weaker model dulls those findings, so a cheaper Security tier is a quality regression. Revisit if a measurement shows a workhorse model holds up.
- **Presets shipped:** `bedrock` (Andy's setup) and `cheap` (real consumer: the gated round-trip test runs on it). `off` is the escape hatch and the unset default.
- **Field:** `model_tier`. **Generator language:** n/a (cut).
