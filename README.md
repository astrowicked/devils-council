# devils-council

A Claude Code plugin that runs a panel of role-scoped persona subagents (Staff Engineer, SRE, PM, Devil's Advocate + context-triggered
Security, FinOps, Air-Gap, Dual-Deploy reviewers) against a plan, diff, or RFC in parallel. A Council Chair synthesizes contradictions
by name without collapsing dissent into a scalar verdict.

**Status:** Phase 1 scaffold (v0.1.0). No personas yet — those land in Phase 2+. This commit is the installable skeleton.

## Core Value

Catch weak plans, overengineered designs, and business misalignment *before* execution — by surfacing the pushback a senior engineering org would give, in a form the author can respond to.

## Requirements

- Claude Code v2.1.63 or newer (for the `Agent` subagent tool)
- `jq` (standard; on macOS via `brew install jq`)
- OpenAI Codex CLI (see "Codex Setup" below — required for v1; deep scans used by Security + Dual-Deploy personas in Phase 6)
- Node 18+ (only if installing Codex via `npm`; `brew install --cask codex` avoids this)

## Install

From a public GitHub marketplace:

```bash
# Inside an active Claude Code session
/plugin marketplace add astrowicked/devils-council
/plugin install devils-council@devils-council
```

Verify:

```bash
claude plugin list --json | jq '.[] | select(.name=="devils-council")'
```

## Uninstall

```bash
/plugin uninstall devils-council
/plugin marketplace remove astrowicked/devils-council
```

Runtime artifacts under `.council/<ts>-<slug>/` (review scratch dirs) and `~/.codex/` (Codex credentials, if installed for this plugin) are NOT removed by uninstall — delete manually if desired.

## Quickstart

> Phase 1 ships only the plugin skeleton. `/devils-council:review` lands in Phase 3. Once it does, the flow will be:

```bash
# Review a plan file (Phase 3 — not yet available)
/devils-council:review path/to/PLAN.md

# Review code via stdin (Phase 3 — not yet available)
git diff main...feature | /devils-council:review -

# Dig into one persona's scorecard after a run (Phase 8 — not yet available)
/devils-council:dig staff-engineer 2026-04-22-142301-my-plan
```

Today (Phase 1) you can:

```bash
# Confirm the plugin is loaded
claude plugin list --json | jq '.[] | select(.name=="devils-council")'

# Verify your Codex setup (required for v1 personas in future phases)
./scripts/smoke-codex.sh
```

## Local Development

To edit the plugin and see changes without re-install:

```bash
# Clone
git clone https://github.com/astrowicked/devils-council.git ~/dev/devils-council
cd ~/dev/devils-council

# Symlink into Claude Code's plugin dir (D-08 dev loop)
mkdir -p ~/.claude/plugins
ln -sfn ~/dev/devils-council ~/.claude/plugins/devils-council

# Inside a Claude Code session, after edits:
/reload-plugins
```

The symlink must point at the REPO ROOT (not `.claude-plugin/`). Verify with `readlink ~/.claude/plugins/devils-council`.

## Codex Setup

devils-council uses OpenAI Codex CLI for deep code scans in the Security and Dual-Deploy Reviewer personas (wired in Phase 6;
envelope defined in `skills/codex-deep-scan/SKILL.md` in this Phase 1 scaffold).

### 1. Install Codex CLI

On macOS (recommended — no Node dependency):

```bash
brew install --cask codex
```

On Linux or as a fallback:

```bash
npm install -g @openai/codex
```

Verify:

```bash
codex --version
# Expected: codex-cli 0.122.0 or newer
```

### 2. Authenticate (OAuth — recommended)

This is the path tested end-to-end in Phase 1 Plan 02.

```bash
codex login
```

A browser window opens for ChatGPT OAuth. Sign in. Credentials are written to `~/.codex/` — this directory is gitignored by the repo's `.gitignore`.

Verify:

```bash
codex login status
# exit 0 = authenticated
```

### 3. Authenticate (API key — for CI or headless environments)

If you prefer not to use OAuth (e.g., for CI runners, or on a headless machine):

```bash
export OPENAI_API_KEY="sk-..."
echo "$OPENAI_API_KEY" | codex login --with-api-key
codex login status
```

Either auth path produces the same `~/.codex/` credential material and the plugin invokes Codex identically.

### 4. Smoke test

```bash
cd ~/dev/devils-council
./scripts/smoke-codex.sh
# Expected: "smoke-codex: OK" and exit 0
# First run takes ~7s on a fast network; subsequent runs comparable.
```

If the smoke test fails, see Troubleshooting below.

### Sandbox default

The plugin invokes Codex with `--sandbox read-only` by default (no writes, no network beyond Codex's own API call). This is fixed
in v1; widening is a post-v1 decision requiring a dedicated threat-model review.

## Troubleshooting

### `codex: command not found`

The CLI isn't on your PATH. Reinstall:

- macOS: `brew install --cask codex` (brew cask path is added automatically)
- All platforms: `npm install -g @openai/codex` (then verify `npm bin -g` is on your PATH)

### `codex login status` exits non-zero after `codex login`

- OAuth: the browser flow may not have completed. Re-run `codex login` and watch for any error output.
- API key: confirm `$OPENAI_API_KEY` is non-empty: `[ -n "$OPENAI_API_KEY" ] && echo set`. Re-run the API-key flow.

### `./scripts/smoke-codex.sh` hangs or times out

- First invocation after auth can take 10-30s (model warmup). Give it up to 60 seconds.
- If it hangs past 60s, `Ctrl-C` and try: `codex exec --json --sandbox read-only --skip-git-repo-check "hello"` directly to isolate whether the issue is Codex or the script.
- If Codex itself hangs, check `~/.codex/config.toml` for a non-default model or profile that may be unavailable.

### `/plugin install` fails with "plugin not found"

The marketplace name is `astrowicked/devils-council` (not `devils-council` alone). The full install is:

```bash
/plugin marketplace add astrowicked/devils-council
/plugin install devils-council@devils-council
```

The `@devils-council` suffix is the marketplace scope, not optional.

### `/reload-plugins` doesn't pick up my edits

- Confirm your symlink is correct: `readlink ~/.claude/plugins/devils-council` should output `/Users/<you>/dev/devils-council` (or wherever your clone lives).
- Confirm the symlink points at the REPO ROOT, not at `.claude-plugin/`.
- If the symlink looks right, try restarting Claude Code entirely.

### Command collision with GSD or Superpowers

devils-council uses the `/devils-council:*` namespace (e.g., `/devils-council:review`). This does not collide with `/gsd:*`,
`/gsd-*`, or `/superpowers:*`. If you see a collision, report it — it's a bug on our side. Phase 1 Plan 03 verified 0 collisions
across all installed plugins on the reference machine.

### Codex token/cost concerns

Codex is only invoked by Security and Dual-Deploy Reviewer personas (Phase 6+), and only when their auto-trigger conditions match.
v1 ships a hard budget cap (default `$0.50` / `30s` per review invocation) that halts further bench-persona fan-out when exceeded.

## Plugin Namespace

- Commands: `/devils-council:review`, `/devils-council:dig`, `/devils-council:on-plan`, `/devils-council:on-code` (Phase 3-8)
- Agents: `agents/<persona>.md` (Phase 2+)
- Skills: `skills/codex-deep-scan`, `skills/persona-voice`, `skills/scorecard-schema`, `skills/signal-detector` (Phase 1-6)

This plugin does NOT ship a `settings.json` with a top-level `agent` key (which would hijack the main thread). Coexistence with GSD and Superpowers is verified on every push by CI.

## Status, Roadmap, and Requirements

This is Phase 1 of 8. The `.planning/` directory in this repo is gitignored by design (phase plans, research, and roadmap are
author-local GSD artifacts). Public users see only the installable plugin surface.

## License

MIT — see [LICENSE](./LICENSE).
