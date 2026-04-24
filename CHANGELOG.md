# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2026-04-24

### Fixed

- Incomplete v1.0.1 hotfix: the cautionary note added in v1.0.1 contained a backticked `` !`<cmd>` `` example that Claude Code's shell-inject parser interpreted as a live directive, reproducing the same parse error the note was warning against. Removed the explanatory anti-example; the Bash-tool-based instruction that follows already conveys the correct pattern without the meta-warning.
  - Symptom post-1.0.1: `(eval):1: parse error near \`>'` still fires on `/devils-council:review`.
  - Root cause: shell-inject runs regardless of surrounding markdown context (inline-code spans do not escape it for Claude Code's pre-parse).
  - Fix scope: 4-line deletion in `commands/review.md`.

## [1.0.1] - 2026-04-24

### Fixed

- `/devils-council:review` parse error on every invocation in v1.0.0 (`commands/review.md:546`) — the suppression hook used `` !`${CLAUDE_PLUGIN_ROOT}/bin/dc-apply-responses.sh <RUN_DIR>` `` shell-inject where `<RUN_DIR>` was a runtime-resolved placeholder. Shell-inject runs at parse time before the model sees the prompt, so `<RUN_DIR>` reached zsh as a literal and the shell interpreted `<` as input redirection with no filename. Fixed by using the Bash tool with runtime substitution (same pattern the Chair spawn section already uses).
  - Error seen: `(eval):1: parse error near \`>'`
  - Caught by UAT against a real PLAN.md artifact.
  - All 15 automated test suites remain green; the bug was only observable through the `!` shell-inject expansion path, which the Bash-tool-based scripts do not exercise.

## [1.0.0] - 2026-04-24

Full persona council ships. Aggregation release — every core behavior validated across 7 prior phases rolls into one installable v1.0.0 plugin.

### Added

- `/devils-council:on-plan <phase>` — GSD phase-plan auto-discovery wrapper: globs `.planning/phases/<NN>-*/<NN>-*-PLAN.md` and routes each sequentially through `/devils-council:review`. Zero GSD core-code awareness beyond the filesystem convention (GSDI-01, Plan 01-02).
- `/devils-council:on-code <phase>` — GSD phase-diff wrapper: resolves phase-start commit via `git log --diff-filter=A` against the phase's first PLAN file, diffs anchor..HEAD, routes as code-diff. Optional `--from <ref>` fallback for projects with `.planning/` gitignored (commit_docs=false) (GSDI-02, Plan 01-02).
- `/devils-council:dig <persona> <run-id> [question]` — interactive follow-up scoped to one persona's scorecard; single Agent() spawn with `<previous-scorecard>` context block; ephemeral (no MANIFEST writes, no new run dir, no Chair spawn). `<run-id>` accepts full directory name or sentinel `latest` (RESP-02, Plan 01-03).
- `userConfig.gsd_integration` in `.claude-plugin/plugin.json` — boolean opt-in (default false) for PostToolUse wrapping of `gsd-plan-checker` and `gsd-code-reviewer` Agent output. Hook appends a one-line `[devils-council: ...]` pointer; additive, never mutates GSD output. Hook silently no-ops when GSD is absent (GSDI-03 + GSDI-04, Plan 01-01).
- `hooks/hooks.json` PostToolUse matcher on `Agent` tool with `if: "Agent(gsd-plan-checker)"` / `if: "Agent(gsd-code-reviewer)"` filters gated by env-var `$CLAUDE_PLUGIN_OPTION_GSD_INTEGRATION` (Plan 01-01).
- `bin/dc-gsd-wrap.sh` — PostToolUse helper implementing the two-layer gate (userConfig opt-in + filesystem presence check) + path extraction for delegation pointer (Plan 01-01).
- `scripts/test-hooks-gsd-guard.sh`, `scripts/test-on-plan-on-code.sh`, `scripts/test-dig-spawn.sh` — three new CI-wired integration tests covering all Phase 8 shell logic (Plan 01-01/02/03).
- README.md full rewrite to v1.0.0 state: install, uninstall, quickstart, 10-persona roster, 16-signal trigger table, command reference, configuration, Codex setup, responses workflow, 8-item troubleshooting (DOCS-01, Plan 01-04).

### Changed

- `.claude-plugin/plugin.json` version bumped 0.6.0 → 1.0.0 (Plan 01-06).
- `.claude-plugin/marketplace.json` version bumped 0.6.0 → 1.0.0 (Plan 01-06).
- `.github/workflows/ci.yml` gains 3 Phase 8 test steps following the Phase 7 existence-gate skip-graceful pattern.

### Breaking changes

None. v1.0.0 is an aggregation release, not a redesign. All v0.6.0 behavior is preserved byte-identical (commands/review.md untouched by Phase 8; responses.md schema unchanged; finding ID format unchanged; synthesis contract unchanged).

### Migration

If upgrading from a pre-v1.0.0 install:

```bash
/plugin uninstall devils-council@devils-council
/plugin install devils-council@devils-council
```

The uninstall step is required — Claude Code's plugin cache does not invalidate on in-place version bumps, so the new commands (`on-plan`, `on-code`, `dig`) and the `userConfig.gsd_integration` key will not appear without a fresh install. This is documented Claude Code behavior; a v1.1 ticket tracks adding an upstream first-class cache-invalidation mechanism.

### Full feature set at v1.0.0

- **Personas:** 4 always-on core (Staff Engineer, SRE, Product Manager, Devil's Advocate) + 4 auto-triggered bench (Security Reviewer, FinOps Auditor, Air-Gap Reviewer, Dual-Deploy Reviewer) + Council Chair synthesis + Haiku artifact classifier fallback.
- **Classification:** 16 structural signals (filename patterns, AST signatures, Helm values keys, Chart.yaml presence, AWS SDK imports, etc.) in `lib/signals.json`; Haiku fallback for zero-signal artifacts.
- **Review engine:** parallel fan-out, per-run isolated `.council/<ts>-<slug>/` directories, evidence-validated scorecards (no vague verbs, verbatim quotes required), XML-nonce injection defense, single-pass architecture (no refinement loops).
- **Synthesis:** contradictions-first Chair output; top-3 blockers with persona attribution; no scalar verdict; stable finding IDs (sha256 of persona + target + claim, evidence excluded).
- **Cost:** Codex-backed deep scans for Security + Dual-Deploy; hard budget cap (default $0.50 / 30s, configurable); prompt caching with observable reduction measured per-run.
- **Response workflow:** `.council/responses.md` with `accepted | dismissed | deferred` enum; dismissals suppress from Chair on re-run; severity-tier render collapses nits by default; `--show-nits` expands.
- **Safety:** ASVS L1 threat-secured across all 7 prior phases + Phase 8 (7 new threats closed); 9-fixture prompt-injection corpus in CI; coexistence verified with GSD + Superpowers; dropped-scorecard path for malformed persona output.
- **GSD integration:** three new commands (`on-plan`, `on-code`, `dig`) + opt-in PostToolUse wrapping; zero collision surface with `/gsd:*` or `/superpowers:*`.

### Requirements closed

Phase 8: GSDI-01, GSDI-02, GSDI-03, GSDI-04, DOCS-01, DOCS-02, DOCS-03, DOCS-04, DOCS-05, DOCS-06, RESP-02.
Running total: 63/63 v1 requirements delivered across 8 phases.

## [0.6.0] - 2026-04-24

### Added

- 9-fixture prompt-injection corpus under `tests/fixtures/injection-corpus/` covering three payload classes (`inject-ignore/`, `role-confusion/`, `tool-hijack/`) across three artifact types (plan, rfc, code-diff). CI asserts the never-obeyed negative invariant per-fixture (HARD-01, Phase 7 Plan 04+05).
- `.council/responses.md` annotation workflow — users mark findings as `accepted | dismissed | deferred` via YAML frontmatter; dismissed IDs suppress from Chair synthesis on re-run (RESP-01, RESP-03, Phase 7 Plan 06). File format: version + responses[] list with finding_id, status, reason, date.
- Severity-tier render transform (`commands/review.md`): top-3 blockers inline with persona attribution, major/minor one-liners, nits collapsed to a one-line summary by default. Flag `--show-nits` expands everything inline (RESP-04, Phase 7 Plan 07).
- `bin/dc-apply-responses.sh` — reads responses.md pre-Chair, writes `MANIFEST.suppressed_findings[]` with dismissed IDs per D-71, filters Chair candidate set (Phase 7 Plan 06).
- `scripts/test-coexistence.sh` — static collision check across devils-council + (optional) GSD + Superpowers; zero command/hook/MCP conflicts asserted (HARD-05, Phase 7 Plan 03).
- `scripts/test-injection-corpus.sh` — fixture runner with D-68 static grep (no `$ARTIFACT`-pattern shell interpolation in conductor) + D-67 per-fixture negative assertions + tool-hijack no-side-effect audit (Phase 7 Plan 05).
- `scripts/test-responses-suppression.sh` — two-run integration test verifying dismissal persists on re-run (RESP-01 + RESP-03).
- `scripts/test-severity-render.sh` — render-transform spec test (Phase 7 Plan 07).
- `scripts/test-dropped-scorecard.sh` — HARD-02 zero-kept-findings scorecard drop path (Phase 7 Plan 02).

### Changed

- `bin/dc-validate-scorecard.sh` drops whole-persona scorecards from synthesis when `kept_findings == 0` (HARD-02): writes stub `.md` + `MANIFEST.validation[persona].dropped_from_synthesis: true`. Chair's Missing Perspectives logic picks these up unchanged.
- `commands/review.md` output defaults to severity-tier collapse; add `--show-nits` to the existing `--only` / `--exclude` / `--cap-usd` flag family (D-72, D-73).

### Fixed

- CI skip-graceful pattern hardened across Phase 3-7 existence-gated steps so in-flight phases don't break ubuntu-latest + macos-latest matrix.

### Notes

- ASVS L1 threat-secured: 36/36 threats closed across Phase 3-7 security registers.
- REQUIREMENTS.md amendments (D-62/D-63/D-64): HARD-03 + HARD-04 deleted as duplicates of BNCH-10/BNCH-09; RESP-02 moved from Phase 7 to Phase 8.
- Plan 07-08 bumps `.claude-plugin/plugin.json` version 0.5.0 → 0.6.0.

## [0.5.0] - 2026-04-23

### Added

- `agents/council-chair.md` subagent — runs sequentially after all personas complete; reads every scorecard; writes `.council/<run>/SYNTHESIS.md` (CHAIR-01, Phase 5 Plan 02).
- `Contradictions` section in synthesis names personas by name ("PM says X, SRE says Y") — never collapses or averages dissent (CHAIR-02).
- Top-3 blocking concerns with persona attribution in synthesis (CHAIR-03).
- Stable deterministic finding IDs: `<persona-slug>-<sha256(persona + target_lc + claim_lc)[:8]>` — evidence excluded from hash so IDs survive evidence-quote reselection across re-runs (CHAIR-06, D-37, D-38).
- `bin/dc-validate-synthesis.sh` — schema validator for Chair output (required sections, ID anchor resolution, CHAIR-04 banned-token scan).
- `scripts/test-chair-synthesis.sh` — end-to-end test: required sections present, contradictions cite resolvable IDs, no APPROVE/REJECT tokens, ID stability across two runs of the same fixture.
- `persona-metadata/council-chair.yml` sidecar with synthesis config (section order, min-contradiction-anchor count).

### Changed

- `bin/dc-validate-scorecard.sh` stamps deterministic IDs during existing validation pass (no separate synth binary; D-32 hybrid split).
- `scripts/validate-personas.sh` routes by `tier:` enum (core/bench → voice_kit schema; chair → synthesizer schema) — zero new frontmatter field (D-42).
- `commands/review.md` conductor spawns Chair after the validator loop; renders synthesis-first + raw per-persona scorecards (CHAIR-05).
- `MANIFEST.json` gains a `synthesis` block (Chair status, validation outcome, missing-perspective note).

### Notes

- No scalar verdict / no APPROVE-REJECT score — explicit anti-feature per CHAIR-04 (enforced by banned-token scan).

## [0.4.0] - 2026-04-23

### Added

- Four always-on core persona agent files: `agents/staff-engineer.md` (simplicity / YAGNI), `agents/sre.md` (operational reality), `agents/product-manager.md` (business alignment), `agents/devils-advocate.md` (red-team / premise attack) — each with distinct value-system anchor, characteristic-objection list, and banned-phrase list (CORE-01 through CORE-04).
- Parallel fan-out conductor in `commands/review.md` — four personas spawn in a single turn via multiple `Task()`/`Agent()` calls; no persona sees another persona's draft (ENGN-03 extended to 4-persona).
- `persona-metadata/*.yml` voice-kit sidecars for each core persona (Phase 2 persona-voice SKILL pattern).
- `scripts/test-order-swap.sh` — CORE-06 verification that swapping persona spawn order produces no change in any scorecard output (parallel isolation is a property of the system, not a convention).
- `scripts/test-persona-voice.sh` — blinded-reader harness for CORE-05 voice differentiation.
- `tests/fixtures/bench-personas/` — fixtures for voice-differentiation check.

### Changed

- `scripts/validate-personas.sh` extended to cover all four core personas' frontmatter (tier + triggers + primary_concern + banned_phrases + characteristic_objections fields).

### Notes

- Blinded-reader test on a sample artifact: Andy correctly attributes 8/8 scorecards to personas without filenames — CORE-05 verified 2026-04-23.
- Live-runtime verification pending in 04-HUMAN-UAT.md at Phase 4 close; static + order-swap verification complete.

## [0.3.0] - 2026-04-22

### Added

- `bin/dc-prep.sh` — deterministic artifact classifier + INPUT.md snapshot + MANIFEST.json init with per-run nonce (Phase 3 Plan 01)
- `bin/dc-validate-scorecard.sh` — evidence + banned-phrase validator, sole writer of final scorecard, additive MANIFEST validation summary (Phase 3 Plan 02)
- `agents/staff-engineer.md` — first core persona (CORE-01): YAGNI-forward pragmatist with worked examples and banned-phrase list (Phase 3 Plan 03)
- `commands/review.md` — `/devils-council:review` slash command conductor threading prep → persona → validator → render (Phase 3 Plan 04)
- `tests/fixtures/injection-basic.md` — injection canary fixture for runtime defense verification
- `scripts/test-engine-smoke.sh` — CI-grade integration test of shell engine with mocked subagent output (Phase 3 Plan 05)
- Engine smoke test wired into CI matrix (ubuntu-latest + macos-latest)

### Phase 2 + Phase 3 Deliverables (v0.3.0 scope)

- Phase 2 requirements closed: PLUG-06 (persona format), PERS-01, PERS-02
- Phase 3 requirements closed: ENGN-01, ENGN-02, ENGN-03, ENGN-04, ENGN-05, ENGN-06, ENGN-07, ENGN-08, CORE-01
- Single-persona end-to-end review pipeline with evidence grounding, injection defense (XML nonce framing + system_directive), and structural single-pass architecture

## [0.1.0] - 2026-04-22

### Added

- Plugin manifest (`.claude-plugin/plugin.json`) and single-repo marketplace catalog (`.claude-plugin/marketplace.json`)
- Empty component directory skeleton (`agents/`, `commands/`, `skills/`, `scripts/`, `bin/`, `hooks/`) for Phase 2+ to populate
- `skills/codex-deep-scan/SKILL.md` — full delegation envelope (request schema, response schema, 6-class error taxonomy) consumed unchanged by Phase 6
- `scripts/smoke-codex.sh` — non-interactive Codex CLI end-to-end verifier (`codex exec --json --sandbox read-only`)
- `tests/fixtures/smoke-prompt.txt` — deterministic smoke-test fixture
- GitHub Actions CI (`.github/workflows/ci.yml`) — plugin validate + markdown lint, matrix of Linux + macOS
- Markdown lint config (`.markdownlint.jsonc` + `.markdownlint-cli2.jsonc`)
- MIT LICENSE
- `.gitignore` excluding `.council/` runtime dir and `~/.codex/` credentials
- README with install, uninstall, quickstart, Codex setup (OAuth + API key), troubleshooting
- Local dev-loop symlink pattern documented: `~/.claude/plugins/devils-council` -> `~/dev/devils-council`

### Phase 1 Deliverables (v0.1.0 scope)

- Requirements closed: PLUG-01, PLUG-02, PLUG-03, PLUG-04, PLUG-05, CDEX-01, CDEX-02, CDEX-06
- No personas, no review command, no review engine — those ship in Phases 2-3

### Notes

- RESP-01 path reconciled from `.devils-council/responses.md` to `.council/responses.md` (unified with ENGN-04 run-directory convention)
- MCP delegation deferred to v1.1; v1 is shell-primary per plan decision D-12

[Unreleased]: https://github.com/astrowicked/devils-council/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/astrowicked/devils-council/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/astrowicked/devils-council/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/astrowicked/devils-council/compare/v0.6.0...v1.0.0
[0.6.0]: https://github.com/astrowicked/devils-council/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/astrowicked/devils-council/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/astrowicked/devils-council/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/astrowicked/devils-council/compare/v0.1.0...v0.3.0
[0.1.0]: https://github.com/astrowicked/devils-council/releases/tag/v0.1.0
