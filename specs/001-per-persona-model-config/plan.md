# Implementation Plan: Per-Persona Model Configuration (OpenCode)

**Feature:** 001-per-persona-model-config
**Milestone:** v1.3
**Spec:** `./spec.md` (rev 3)
**Constitution:** `.specify/memory/constitution.md`
**Spike:** `.planning/spikes/per-persona-model-SPIKE.md`
**Council review:** `./SYNTHESIS.md` (rev 2)

## Technical context

The core mechanism is the plugin's `config` hook.

- **Injection surface:** `@opencode-ai/plugin` exposes `config?: (input: Config) => Promise<void>`. The hook receives the resolved config with the user's `opencode.json` already merged, so a guarded inject gives a default the user overrides (spike-proven).
- **Plugin entry:** `.opencode/plugins/devils-council.ts` already implements `session.created` / `tool.execute.*`. The `config` hook goes here.
- **Sidecars:** `persona-metadata/*.yml` (root) and `.opencode/persona-metadata/*.yml` (published). Each has `tier: core|bench`; we add `model_tier`. **Source of truth resolved (T001):** `build.sh:377` does `cp -r "$REPO_ROOT/persona-metadata" "$SCRIPT_DIR/persona-metadata"` — root is authored, `.opencode/` is a generated copy. So `model_tier` is added to root only, and T004 is a build-output assertion (generated copy matches root), not a two-way drift check. *(Found a pre-existing build bug: `cp -r` into the existing dir nests `.opencode/persona-metadata/persona-metadata`; out of scope, noted.)*
- **Build:** `.opencode/build.sh` emits no `model:` today; keep it that way and assert it against the published tarball.
- **Distribution:** npm root is `.opencode/`; `files` ships `plugins/`, `bin/`, `persona-metadata/`, `config.json`. The tier→model maps + hook ship inside the plugin, available with zero user setup.

## Design decisions

1. **Zero-action default via per-field guarded `config`-hook inject.** Inject `model` only if `!agent.model`, `variant` only if `!agent.variant`, independently. The guard is mandatory and per-field: a single `!model` guard would clobber a user's `variant`-only override (SRE2-4). The guard works because the hook sees the user's config already merged.
2. **Fail-safe is part of the mechanism, not a nicety.** The hook runs in the user's session on every create. Build the full agent-map in a local and assign it in one step at the end (atomic — a mid-loop throw can't leave a half-injected council). `await` the whole path inside try/catch so no async rejection escapes. On any error (corrupt preset, unparseable sidecar, partial install) log one line and return unmutated → all personas fall through to the session model. Never a dead session (SRE2-1).
3. **Validate before injecting; skip entirely if you can't.** Check each preset model ID against the provider's available-models list; on a miss, skip that persona (fall through) and log. If the available-models list isn't exposed to the plugin, skip injection entirely (inject nothing, all personas on session model, one log) — degraded but predictable. Do not inject unvalidated and rely on catching a mid-review 403 (SRE2-3).
4. **Explicit preset selector, no detection.** `userConfig`: `bedrock | cheap | off`. Unset → `off` + a one-line "tiering available, set preset to enable" hint (distinguishes unset from a deliberate `off`). Silent provider detection is cut — it could only fail silently (SE2-2, SRE2-2, DA2-2).
5. **Frontmatter stays model-silent**, enforced against the tarball.
6. **`model_tier` is its own sidecar field**, not overloading `tier: core|bench`.
7. **Two presets: `bedrock` + `cheap`.** `cheap` has a real consumer — the gated round-trip test runs on it. `anthropic` is deferred (a new preset is one data object). `off` is the escape hatch.
8. **No standalone generator.** The paste UX is gone; the tier→model map is inspectable plugin data.
9. **Override-precedence is checked behaviorally, not by version-string.** The gated cheap round-trip asserts user-override-wins (the merge-order invariant the design rests on); docs state the tested version range (SE2-4 + DA2-1 bridged — no theater gate, invariant still tested).
10. **Round-trip live-spawn is not required CI.** The model-silent grep is the required gate. The live spawn runs **cheap preset only**, **nightly (not per-push)**, with distinct exit codes for "never ran" (flake, retry) vs "wrong model" (fail), and a guard that refuses to run on any non-cheap preset (FIN2-4).
11. **OpenCode only.** `model_tier` treated as OpenCode-consumed; CC consumer deferred (likely runtime-neutral if CC maps tier→model into frontmatter at build — confirm before v1.4).

## Architecture / file structure

**Phase 0 — Resolve sidecar source of truth** *(prereq, gates Phase 1)*

- Read `build.sh`: does it copy root→`.opencode`, or are both hand-maintained? Document the answer; pick the authored copy. Decides whether Phase 1 adds a drift check (both authored) or a build-output assertion (one generated).

**Phase 1 — Tier taxonomy + sidecar tagging** (FR-01, 02, 03, 04)

- Add `model_tier` to each critic sidecar at the source-of-truth copy; classifier exempt.
- Extend persona lint: require valid `model_tier` on critics, skip classifier by name.
- Add the drift check or build-output assertion per Phase 0.
- Security = `deep-reasoning` (spec-decided).

**Phase 2 — Config-hook injection** (FR-05, 06, 07, 08, 09)

- `.opencode/plugins/devils-council.ts` — add the `config` hook: resolve preset (explicit selector; unset→off+hint), read persona tiers, validate model IDs against provider available-models, per-field guarded inject, all inside try/catch with fall-through.
- Tier→model maps as plugin data (`.opencode/lib/model-presets.json` or `.ts`): `bedrock`, `cheap`.
- `userConfig` schema for the selector.
- Tests (cheap preset, DB readback): inject-when-absent (A), skip-when-user-set model (B), **variant-only override preserved (C)**, `off` injects nothing, corrupt preset doesn't kill session, unknown/unavailable model falls through with log.

**Phase 3 — Guardrail + precedence check** (FR-10, 11, 12)

- `build.sh` — assert generated agents contain no `model:`.
- CI gate greps the `npm pack` tarball; post-pack smoke test installs the tarball and exercises the hook.
- Nightly cheap-preset round-trip asserts user-override-wins (merge-order invariant); **also triggered on any change to the pinned OpenCode version (lockfile / documented range)** so the invariant is checked at the moment of risk; guard refuses non-cheap presets; docs state tested OpenCode version range.

**Phase 4 — Docs** (FR-13)

- `README.md` — "Configure per-persona models": tier table, `bedrock|cheap|off` selector, precedence table, fail-safe behavior, worked override as a **merge into an existing `agent` block**.

## Requirements → phases

| Requirement | Phase |
|-------------|-------|
| FR-04 (source of truth) | 0 → 1 |
| FR-01, 02, 03 | 1 |
| FR-05, 06, 07, 08, 09 | 2 |
| FR-10, 11, 12 | 3 |
| FR-13 | 4 |

## Risks / open questions

- **Merge-order durability (DA2-1).** The guarded inject loses to the user only because config merge happens before the hook reads it. A future OpenCode that reorders this flips "user wins" → "plugin clobbers user," silently. FR-12's behavioral check (user-override-wins on the nightly cheap lane) is what actually catches this — not a version-string grep. Re-run on version bumps.
- **Cost framing (FIN2-1/2/3).** The spec table now shows floor + fan-out rows; the "~halved" claim holds because Security is the only deep-reasoning bench persona. Real token counts from the FR-12 test replace the estimates before the success criterion locks. The Chair residual is the cap, not something tiering fixes.
- **Cross-runtime field shape (DA2-4).** `model_tier` is OpenCode-consumed now. Confirm before v1.4 whether the CC path maps tier→model into frontmatter (runtime-neutral, no conflict) or needs a concrete string in the sidecar (real conflict). Likely the former.
- **Provider available-models API.** FR-09 assumes OpenCode exposes the provider's available models to the plugin; confirm the surface in Phase 2 (PluginInput has `client`/provider hooks). If unavailable, skip injection entirely (all personas on session model + one log) — a predictable no-op, not a try-spawn-and-catch that reintroduces the mid-review 403.

## Implementation notes (Phase 2, 2026-06-03)

- **Plugin migrated to the real `@opencode-ai/plugin` function shape.** The custom `definePlugin({hooks})` shape silently ignores the `config` hook; the function shape (`input => Hooks`) fires it. Ported `session.created` → an `event` handler filtering `event.type === "session.created"`; `tool.execute.after` → `(input, output)` with the speckit suggestion surfaced by appending to `output.output` (the real API has no `ctx.suggest`). Removed the custom type shim. Verified no regression (command symlinks still created).
- **Selector is an env var for v1:** `DEVILS_COUNCIL_MODEL_PRESET=bedrock|cheap|off`; unset → off + a one-line hint. Native `userConfig` wrapping is a later nicety; the env var is the explicit selector (no silent detection).
- **Verified (cheap preset, DB readback):** deep-reasoning → minimax, workhorse → deepseek; `off` and unset inject nothing; user `model` override beats the default (Test B); corrupt preset → logged + session still runs + fall-through (Test E, the fail-safe blocker).
- **OpenCode limitation found:** an `agent.<name>` entry with `variant` but no `model` is **not honored by OpenCode itself** (variant resets to `default`), independent of this plugin. SRE2-4's "variant-only override clobbered by the guard" is moot in practice, and the per-field guard is correct regardless (it never overwrites a user-set field).
- **T008 not feasible in the config hook (empirical).** Calling the SDK client (`client.config.providers()`) from inside the `config` hook **deadlocks session startup** — the hook runs during config/server init and the call waits on the very server that's waiting on config resolution (a 3s race didn't help; the underlying call wedges startup). So injected model IDs are not pre-validated. Mitigation: presets are curated to real model IDs, the user can override any persona, a genuinely-unavailable model only fails that one persona's spawn (others still run), and the fail-safe wrapper prevents any crash from breaking the session. FR-09's "skip-entirely-if-unavailable" is moot because the list is never available at config time; revisit if OpenCode later exposes a synchronous/cached model list to plugins.

## Verification

- Fresh install, `bedrock`: a spawned persona runs on its tier model with no per-persona user config (DB readback).
- Per-field override wins: user `model` override, and separately a `variant`-only override, each preserved (Test B, Test C).
- `off` and unset: every persona on the session model; unset emits the hint.
- Corrupt preset: session still creates and `/review` runs (Test). Unavailable model: that persona falls through with a log, review completes (Test).
- Lint fails on missing/invalid `model_tier`; drift/build-output check per Phase 0.
- Tarball gate fails if a frontmatter `model:` ships; post-pack smoke test exercises the hook against the installed layout.
- Nightly cheap round-trip confirms user-override-wins (merge-order invariant) and refuses non-cheap presets.
- Measured `bedrock` per-review cost is materially below the all-Opus baseline; the real figure replaces the spec estimate.
