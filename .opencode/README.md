# devils-council-opencode

Persona-driven adversarial review for plans, code, and design artifacts — as an [OpenCode](https://opencode.ai) plugin.

Catch weak plans, overengineered designs, and business misalignment *before* execution — by surfacing the pushback a senior engineering org would give.

## Install

Add to your project's `opencode.json`:

```json
{
  "plugin": ["devils-council-opencode"]
}
```

OpenCode auto-installs npm plugins at startup.

## Agents

| Agent | Role |
|-------|------|
| `@staff-engineer` | Pragmatist — asks what we can delete or not build |
| `@sre` | Operational reality — asks what breaks at 3am |
| `@product-manager` | Business alignment — asks who filed the ticket |
| `@devils-advocate` | Premise attack — names the unquestioned assumption |
| `@council-chair` | Synthesizes contradictions across all persona scorecards |
| `@council-review` | Full council in one invocation (4 core + bench + Chair) |
| `@security-reviewer` | Bench — triggers on auth/crypto/secrets code |
| `@finops-auditor` | Bench — triggers on cloud resources/SDK imports |
| `@air-gap-reviewer` | Bench — triggers on external dependencies/egress |
| `@performance-reviewer` | Bench — triggers on hot-path/N+1 patterns |

## Usage

Invoke any persona directly:

```
@staff-engineer review this plan: <paste artifact>
```

Or run the full council:

```
@council-review <paste artifact or file path>
```

## How It Works

Core personas (Staff Engineer, SRE, PM, Devil's Advocate) always run. Bench personas auto-activate when structural signals are detected in the artifact (e.g., AWS imports trigger FinOps, crypto code triggers Security).

Each persona produces a structured scorecard with findings that cite verbatim evidence from the artifact. The Council Chair synthesizes contradictions by name without collapsing dissent into a scalar verdict.

## Also Available

Claude Code plugin (16 personas, Codex CLI integration): see [github.com/astrowicked/devils-council](https://github.com/astrowicked/devils-council)

## License

MIT
