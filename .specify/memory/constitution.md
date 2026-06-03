# Constitution: devils-council

## Project

A persona-driven adversarial review layer for plans, code, and design artifacts. Multiple personas critique work from their own perspective and produce a structured scorecard that surfaces pushback before work lands. Ships as both a Claude Code plugin and an OpenCode plugin from shared persona markdown.

## Guiding Principles

- **Pushback is the product.** Non-generic, domain-specific, evidence-backed critique. Generic "have you considered security?" output is a failure, not a feature.
- **Shared source of truth.** Persona markdown is authored once and consumed by both runtimes. Don't fork persona voice per runtime.
- **Composability.** Coexist with GSD, Superpowers, and speckit without clobbering their commands or hooks.
- **Native over custom.** Prefer the host platform's own mechanisms over bespoke config parsing or runtime rewriting when they do the job.

## Non-Negotiable Rules

- **Public OSS repo.** No secrets, no internal customer names in examples or fixtures.
- **Claude Code stays working.** OpenCode work is additive; never regress the Claude Code plugin.
- **Don't ship `model:` in OpenCode persona frontmatter.** Frontmatter beats `opencode.json` `agent.<name>.model`, so a hardcoded frontmatter model locks users out of native per-persona overrides. Tier-based model defaults are delivered as a generated, paste-able `opencode.json` `agent` block instead. (Proven: `.planning/spikes/per-persona-model-SPIKE.md`.)
- **Don't leak dev tooling into the published package.** speckit framework lives at repo root (`.specify/`, singular `.opencode/command/`); the npm `files` allowlist must not ship it.
- **Evidence or it didn't happen.** Scorecard findings cite verbatim lines; spike claims are backed by reproducible commands.
