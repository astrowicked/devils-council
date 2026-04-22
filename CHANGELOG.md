# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/astrowicked/devils-council/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/astrowicked/devils-council/compare/v0.1.0...v0.3.0
[0.1.0]: https://github.com/astrowicked/devils-council/releases/tag/v0.1.0
