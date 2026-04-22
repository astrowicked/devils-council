# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Nothing yet. Phase 2 (persona format + voice scaffolding) begins next.

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

[Unreleased]: https://github.com/astrowicked/devils-council/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/astrowicked/devils-council/releases/tag/v0.1.0
