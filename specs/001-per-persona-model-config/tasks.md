# Tasks: Per-Persona Model Configuration (OpenCode)

**Feature:** 001-per-persona-model-config
**Milestone:** v1.3
**Spec:** `./spec.md` (rev 3) · **Plan:** `./plan.md` (rev 3) · **Review:** `./SYNTHESIS.md`

Dependency-ordered, by plan phase. `[P]` = can run in parallel with its siblings. Each task names the file(s) it touches.

## Phase 0 — Resolve sidecar source of truth *(gates Phase 1)*

- [ ] T001 Read `.opencode/build.sh` and determine whether `.opencode/persona-metadata/*.yml` is generated from root `persona-metadata/*.yml` or both are hand-maintained. Record the answer (which copy is authored, which is generated) in `plan.md` Technical Context. Decides T005's shape. (FR-04)

## Phase 1 — Tier taxonomy + sidecar tagging *(depends on T001)*

- [ ] T002 Add `model_tier` to each **critic** persona sidecar at the authored source-of-truth copy: `staff-engineer`, `sre`, `product-manager`, `devils-advocate`, `council-chair` (deep-reasoning for DA + Chair), `security-reviewer` (deep-reasoning), `finops-auditor`, `air-gap-reviewer`, `performance-reviewer`, plus the other bench personas in `persona-metadata/*.yml`. Leave `artifact-classifier` untagged (exempt). (FR-01)
- [ ] T003 Extend the persona lint (`scripts/validate-personas.sh` or the build's sidecar check) to require a valid `model_tier` (`deep-reasoning|workhorse|cheap`) on every critic and to skip `artifact-classifier` by name. Fail on missing/invalid. (FR-02, FR-03)
- [ ] T004 Add the source-of-truth guard per T001: if both copies are authored, a CI check fails when root and `.opencode` sidecars disagree on `model_tier`; if one is generated, assert the build output instead. (FR-04)

## Phase 2 — Config-hook injection *(depends on Phase 1)*

- [ ] T005 [P] Create the tier→model preset data `.opencode/lib/model-presets.json` with `bedrock` and `cheap` maps (`tier → {model, variant?}`). `bedrock` sets `variant: max` only where it sharpens critique. No `anthropic`. (FR-07)
- [ ] T006 [P] Add the `userConfig` schema entry for the preset selector (`bedrock | cheap | off`) in the plugin manifest/config. (FR-07)
- [ ] T007 In `.opencode/plugins/devils-council.ts`, add the `config` hook skeleton: resolve the active preset from the selector; unset → `off` + emit one enable-tiering hint line; `off` short-circuits (no inject). (FR-07)
- [ ] T008 Implement available-models validation in the hook: check each preset model ID against the provider's available-models list; on a miss, skip that persona (fall through) and log. If the list isn't exposed to the plugin, skip injection entirely (one log, all personas on session model). Confirm the API surface (`PluginInput.client`/provider hooks). (FR-09)
- [ ] T009 Implement the per-field guarded inject: build the full agent-map in a local, inject `model` only if `!agent.model` and `variant` only if `!agent.variant` (independently), then assign the map to config in one step (atomic). Wrap the whole awaited path in try/catch; on any error log one line and return unmutated. (FR-05, FR-08)
- [ ] T010 Add Phase-2 tests (cheap preset, session-DB readback): (A) inject-when-absent, (B) skip-when-user-set-model, (C) variant-only override preserved, (D) `off` injects nothing, (E) corrupt preset → session still creates AND zero personas injected, (F) unavailable model → that persona falls through with a log. (FR-05, FR-06, FR-08, FR-09)

## Phase 3 — Guardrail + precedence check *(depends on Phase 2)*

- [ ] T011 [P] Add a `build.sh` assertion that generated `.opencode/agents/*.md` contain no frontmatter `model:`. (FR-10)
- [ ] T012 [P] Add the CI guardrail gate: grep the `npm pack` tarball for a frontmatter `model:` and fail if found. Wire into `.github/` workflow. (FR-11)
- [ ] T013 Add a post-pack smoke test: install the tarball into a temp dir and exercise the `config` hook against the installed layout (asserts presets/sidecars resolve post-install). (FR-11)
- [ ] T014 Add the override-precedence behavioral check: a cheap-preset round-trip that sets a user override, spawns, and confirms via the session DB that the user value wins. Runs nightly **and** on any change to the pinned OpenCode version (lockfile / documented range). Guard refuses to run on any non-cheap preset. Document the tested OpenCode version range. (FR-12)

## Phase 4 — Docs + cost truth-up *(depends on Phases 2–3)*

- [ ] T015 Add the README "Configure per-persona models" section: tier table, `bedrock|cheap|off` selector, the precedence table, the fail-safe behavior, and a worked single-persona override (model + variant) shown as a **merge into an existing `agent` block**. (FR-13)
- [ ] T016 Wire the measured token counts from the T010/T014 cheap-preset spawns into `spec.md`'s cost table, and update the cost success criterion with the real per-review figure (replacing the estimate). (spec "Why this is worth doing" + Success criteria)

## Notes

- **No JIRA/Confluence:** devils-council is a public OSS plugin (no `CORE` JIRA or IN-space Confluence tie-in), so no `TICKETS.md` / ticket lifecycle applies.
- **Post-plan gate:** already satisfied — two council rounds + a targeted SRE pass; all blockers closed (`SYNTHESIS.md`).
- **Suggested commit boundaries:** one commit per task; Phase 0 and Phase 1 land before any hook code.
