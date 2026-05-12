---
gsd_state_version: 1.0
milestone: v1.2
milestone_name: — OpenCode Compatibility
status: verifying
last_updated: "2026-05-12T18:20:55.790Z"
last_activity: 2026-05-12
progress:
  total_phases: 4
  completed_phases: 4
  total_plans: 4
  completed_plans: 4
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-12 — v1.2 milestone added)

**Core value:** Catch weak plans, overengineered designs, and business misalignment before execution — by surfacing the pushback a senior engineering org would give, in a form the author can respond to.
**Current focus:** v1.2 — OpenCode Compatibility (in progress)

## Current Position

Phase: 01 (OpenCode Plugin Scaffold)
Plan: 01 complete (1/1 plans in phase)
Status: Phase 1 plan executed, all verifications pass
Last activity: 2026-05-12

## Accumulated Context

### Open Blockers (none)

### Phase Structure (6 phases)

1. **Phase 1: OpenCode Plugin Scaffold** — `.opencode/` directory, plugin entry point, shared persona markdown sourcing strategy
2. **Phase 2: Persona Adaptation** — Port core 4 + Chair as OpenCode agents; multi-persona-in-one-agent pattern (OpenCode doesn't support nested subagent spawning from commands)
3. **Phase 3: Signal Detection + Selection** — `tool.execute.before` plugin hook (TypeScript); deterministic signal→persona mapping without shell injection
4. **Phase 4: Review Command + Scorecard** — `/review` command, structured scorecard output matching Claude Code format
5. **Phase 5: Speckit Integration Hook** — Wire as `/speckit.analyze` extension; auto-trigger after `/speckit.plan`
6. **Phase 6: Dual-Runtime CI** — Extend CI to test both Claude Code plugin and OpenCode plugin paths; shared persona fixtures

### Key Decisions Already Made (v1.2 definition)

- Pragmatic port, not full parity — 9 personas (4 core + Chair + 4 high-value bench), not all 16
- No Codex CLI integration in OpenCode (defer to v1.3)
- Shared persona markdown is the source of truth — both runtimes consume same files
- npm-publishable OpenCode plugin (not just local `.opencode/plugins/` files)
- Response suppression workflow deferred (no cross-session persistence in OpenCode v1.2)
- Scorecard output format must be identical between runtimes (downstream consumers don't care which tool generated it)

### v1.1 → v1.2 Context

v1.1 shipped as v1.1.0 on 2026-05-01. Full 16-persona suite working in Claude Code. OpenCode port is additive — Claude Code plugin continues to work unchanged. Key architecture question for Phase 1: symlinks vs build step vs monorepo workspace for sharing persona markdown between `.claude-plugin/agents/` and `.opencode/agents/`.

### OpenCode Plugin System Capabilities (researched 2026-05-12)

- **Agents:** Markdown files in `~/.config/opencode/agents/` or `.opencode/agents/` with YAML frontmatter
- **Commands:** Markdown files in `~/.config/opencode/commands/` or `.opencode/commands/`
- **Plugins:** TypeScript/JS in `.opencode/plugins/` or npm packages; hooks: `tool.execute.before`, `tool.execute.after`, `session.idle`, `session.created`, etc.
- **Distribution:** npm packages in `plugin` array in `opencode.json`
- **Limitations vs Claude Code:** No `!`shell-injection, no `${CLAUDE_PLUGIN_ROOT}`, no nested subagent spawning, no `context: fork`, no plugin-level hooks.json. TypeScript plugin system provides event hooks instead.

## Session Continuity

Last session: 2026-05-12T18:20:55.786Z

### Performance Metrics

| Phase | Plan | Duration | Tasks | Files |
|-------|------|----------|-------|-------|
| 01 | 01 | ~3m | 2 | 10 |
| Phase 02 P01 | 9m | 3 tasks | 7 files |
| Phase 03 P01 | 591 | 2 tasks | 8 files |
| Phase 04 P01 | 377 | 2 tasks | 4 files |

### Decisions

- Heredoc pattern: `python3 -` (stdin) with positional args before the heredoc delimiter for combined heredoc+args
- [Phase 02]: Hand-written persona bodies are canonical; build.sh provides automated starting point
- [Phase 02]: council-review.md is experimental convenience tool; standalone persona agents are primary workflow
- [Phase 03]: Post-build cleanup in build.sh for Codex/sidecar stripping — ensures idempotent builds
- [Phase 03]: Signal detection as LLM-driven natural language rules (not regex) — matches soft detection strategy
- [Phase 04]: Performance Reviewer uses split N+1 detection (loop+db and SQL-in-loop) counting as 2 signals
- [Phase 04]: Scorecard validation gate added to Chair synthesis with 4 enforcement rules
