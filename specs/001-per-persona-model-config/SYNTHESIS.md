# Council Synthesis (rev 2) — v1.3 Per-Persona Model Configuration

**Artifact:** `specs/001-per-persona-model-config/plan.md` (rev 2) + `spec.md` (rev 2)
**Personas run:** staff-engineer, sre, devils-advocate, finops-auditor (product-manager deliberately skipped — rev-1 findings addressed by the cost table, stated Claude Code gap, decided Security tier, and scenario labeling)
**Prior synthesis:** rev 1 was the first pass on this file; its top-3 are confirmed resolved below.

Finding ids map to each persona's rev-2 scorecard bullets (e.g. SRE2-1 = sre's first finding).

## Contradictions

- **Staff Engineer** (SE2-2): «cut provider detection; make the preset selector explicit with off as default — detection can only fail silently.»
  **SRE** (SRE2-2): «provider detection falling back to `off` is a silent regression to all-Opus... Emit a visible warn line when detection resolves to off.»
  **Devil's Advocate** (DA2-2): «provider detection is the one link the spike never tested... yet it fires on fresh install... Add a detection test or make the selector required.»
  *Tension:* Staff Eng wants detection **deleted**; SRE and DA want it **kept and instrumented**. All three agree it fails silently. Bridge: SE2-2 and DA2-2 both touch "make the selector explicit/required," which removes detection from the fresh-install critical path.

- **Staff Engineer** (SE2-4): «version-pin CI check greps a version string, not the precedence behavior — a calendar reminder dressed as a gate; keep the doc + manual recipe only.»
  **Devil's Advocate** (DA2-1): «The version pin must test the merge-order invariant, not just grep frontmatter model.»
  *Tension:* Both agree the grep-a-string check is worthless. Staff Eng wants it **downgraded** to a doc; DA wants it **upgraded** to a real merge-order test (a reorder silently flips "user wins" → "plugin clobbers user"). Disagreement: is merge-order a correctness invariant worth a gate, or a maintenance note?

## Top-3 Blocking Concerns

1. **SRE** (SRE2-1): The config hook has no failure contract — it reads/parses preset+sidecar files in the user's session process on every session create; a corrupt preset or missing sidecar throws into dead session startup (no `/review` at all). *Blocker by severity.*
2. **Provider detection** — **Devil's Advocate** (DA2-2), corroborated by **SRE** (SRE2-2) and **Staff Engineer** (SE2-2): the one path the spike never exercised, fires on fresh install, and a miss fails silently to all-Opus. *Three personas, same target; resolving it settles Contradiction 1.*
3. **Per-field model/variant guard** — **SRE** (SRE2-4): the guard was proven for `model` only, but the hook injects `{model, variant}`; a user who sets `variant` without `model` trips `!a.model` and gets both injected, clobbering their variant. *Breaks the "user overrides win" guarantee the whole rev-2 design rests on.*

## Convergences worth acting on

- **YAGNI on scope:** Staff Engineer (SE2-1, SE2-3) + Devil's Advocate (DA2-4) — ship the minimum (bedrock + off), defer extra presets and the `model_tier` field-shape commitment until a real consumer exists.
- **Cost story is mis-framed:** FinOps (FIN2-1, FIN2-2, FIN2-3) + Devil's Advocate (DA2-3) — the table prices the cheapest ~2-bench review on an optimistic token mix while the Chair residual is untouched by tiering. Relabel $0.72 as the floor, add a full-fan-out row, tie "halved" to a stated profile, and wire real token counts from the gated cheap test.
- **Silent `off` is the recurring failure shape:** SRE (SRE2-2) + Devil's Advocate (DA2-2) — a detection miss is indistinguishable from a deliberate opt-out and emits no signal.

## Also raised (majors not in top-3)

- DA2-1 — version-pin should test the merge-order invariant (also Contradiction 2).
- SRE2-3 — injected model string is unvalidated; may 403 mid-review; validate against provider available-models, fall through on miss. *(Close fourth blocker.)*
- FIN2-2 — token assumptions undershoot this very plan; wire actuals before the "measured cost" criterion locks.
- SE2-3 — drop the v1.3 generator (the paste UX it served is gone).
- SE2-1 — bedrock + off only; drop anthropic/cheap presets absent a consumer.

Minors: SRE2-5 (add hook-throw + detection-miss tests), SE2-5 (drift check may guard a generated artifact — resolve Phase 0 first), FIN2-4 (name nightly cadence + assert live lane refuses non-cheap presets), FIN2-3 (quantify Chair residual vs council size).

## Open decisions for the author

1. **Provider detection: delete or instrument?** (Contradiction 1; SE2-2 vs SRE2-2/DA2-2.) Bridge both camps touch: make the selector explicit so detection isn't on the fresh-install critical path.
2. **Version pin: drop to a doc, or promote to a merge-order invariant test?** (Contradiction 2; SE2-4 vs DA2-1.)
3. **Preset scope (still open from rev 1, decision #2):** bedrock+off only (SE2-1) vs including cheap (FinOps needs it for the gated round-trip test) vs all three. Show the break-even.
4. **Phase 0 ordering:** resolve sidecar source-of-truth before deciding whether the drift check guards real drift or a generated artifact (SE2-5).

## Confirmed resolved (rev 1 → rev 2)

- **DA-02** (no active default) — resolved by the config-hook auto-inject with guarded user-override precedence (spike-proven).
- **FIN-01** (no cost math) — resolved by the cost table (arithmetic verified to the cent; remaining FIN2-* are about framing/coverage, not absence).
- **SRE-01** (silent paste mismatch) — resolved by replacing the paste UX with automatic injection against real shipped names.
- **FIN-02** (unbounded CI Opus spend) — resolved (live spawn gated to cheap preset, grep is the required gate); residual ask is naming the cadence and locking the live lane to cheap-only.

## Rev-3 closure (post-targeted SRE re-review)

Rev 3 applied the proposed resolutions; a focused SRE pass confirmed:

- **SRE2-1 (hook failure contract)** — CLOSED. FR-08 now specifies atomic assignment (build map in a local, assign once), an awaited try/catch (no escaping async rejection), and a corrupt-preset test that asserts zero personas injected on the throw path.
- **SRE2-4 (per-field guard)** — CLOSED. FR-05/06 guard `model` and `variant` independently; Test C covers the variant-only override.
- **SRE2-2 (silent off)** — CLOSED. Detection cut; explicit `bedrock|cheap|off` selector; unset emits an enable-tiering hint.
- **SRE2-3 (unvalidated model)** — CLOSED. FR-09 validates against provider available-models; if that list isn't exposed, skip injection entirely (predictable no-op) rather than try-spawn-and-catch.
- **New minor** — FR-12 merge-order check now triggers on OpenCode version/lockfile changes, not just nightly, so the invariant is checked at the moment of risk.

No new blockers. All rev-2 top-3 resolved. The forks (provider detection, version pin, preset scope) were resolved per the synthesis bridges: detection deleted in favor of an explicit selector; version pin replaced by a behavioral merge-order check; presets scoped to bedrock + cheap (+ off).
