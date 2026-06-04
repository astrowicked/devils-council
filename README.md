# devils-council

**Get a staff-level LGTM on every plan, PR, and RFC — in 48 seconds.**

> A Staff Engineer, SRE, Product Manager, and Devil's Advocate independently review your work before anyone else sees it. Every finding cites your own words back at you. Ship with confidence.

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![npm](https://img.shields.io/npm/v/devils-council-opencode)](https://www.npmjs.com/package/devils-council-opencode)
[![version](https://img.shields.io/badge/version-1.6.0-brightgreen)](CHANGELOG.md)

---

## See it in action (30 seconds, no setup)

```bash
# Install
echo '{"plugin":["devils-council-opencode"]}' > .opencode/opencode.json

# Run the built-in demo against a deliberately flawed plan
/devils-council-demo
```

The demo reviews a notification service plan with over-engineering, circular risk mitigations, and missing operational details. Watch each persona catch different issues.

---

## What it catches (real examples)

| Catch | Personas | Impact |
|-------|----------|--------|
| [Credential migration with no verification gate](examples/01-173-workspace-outage.md) | SRE + Devil's Advocate | Prevented 173-workspace CI/CD outage |
| [CI trigger premise disproven from both directions](examples/02-signal-invalidated-both-directions.md) | Devil's Advocate + SRE | Killed a design with simultaneous false positives AND false negatives |
| [4 plans build tooling, none prove it works](examples/03-plumbing-without-water.md) | Product Manager | Caught "plumbing without water" before 2 weeks of wasted effort |
| [Threat model claims control exists, code doesn't](examples/04-threat-model-said-it-was-there.md) | Devil's Advocate + SRE | Avoided false SOC2 attestation |
| [3,291 lines for a problem standard tooling solves](examples/05-3291-lines-solved-problem.md) | All three (convergent) | Deleted 3,291 lines, replaced with 40 |

See all [case studies →](examples/)

---

## How it works

Four always-on **core personas** critique your artifact in parallel. Additional **bench personas** auto-trigger on structural signals — Helm values changes wake Dual-Deploy; AWS SDK imports wake FinOps; auth/crypto code wakes Security; code diffs wake Junior Engineer.

A **Council Chair** synthesizes contradictions **by name** ("PM says ship, SRE says block because...") without collapsing dissent into a scalar verdict. Every finding cites a verbatim quote from the artifact; every finding has a stable ID so dismissals persist across re-runs.

**Status:** v1.6.0 — Dual-runtime plugin (OpenCode + Claude Code). MIT licensed.

---

## Requirements

- **OpenCode** v1.14+ (primary runtime — npm plugin, no extra install)
- **Claude Code** v2.1.63+ (secondary runtime — marketplace plugin)
- **jq** (macOS: `brew install jq`; Ubuntu: `apt install jq`)
- **python3** + PyYAML (`pip install pyyaml`) — required for HTML report generation
- **OpenAI Codex CLI** — required for Security + Dual-Deploy deep scans (see [Codex Setup](#codex-setup))
- **Node 18+** only if installing Codex via `npm` (`brew install --cask codex` avoids this)

---

## Install

### OpenCode (recommended)

Add to your project's `opencode.json`:

```json
{
  "plugin": ["devils-council-opencode"]
}
```

OpenCode auto-installs npm plugins at startup — no `npm install` needed. The plugin ships 10 agents:

- `@staff-engineer`, `@sre`, `@product-manager`, `@devils-advocate` — standalone persona reviews
- `@council-chair` — synthesizes findings from multiple persona scorecards
- `@council-review` — full council (4 core + dynamic bench activation + Chair synthesis) in one invocation
- `@security-reviewer`, `@finops-auditor`, `@air-gap-reviewer`, `@performance-reviewer` — bench personas activated by signal detection

### Claude Code

From the GitHub marketplace:

```bash
/plugin marketplace add astrowicked/devils-council
/plugin install devils-council@devils-council
```

Verify:

```bash
claude plugin list --json | jq '.[] | select(.name=="devils-council") | .version'
# Expected: "1.6.0"
```

After upgrade (see [Troubleshooting #1](#1-plugin-cache-staleness-after-version-bump) if new commands don't appear):

```bash
/plugin uninstall devils-council@devils-council
/plugin install devils-council@devils-council
```

---

## Quickstart

### Review a plan

```bash
# Full council review (core personas + triggered bench + Chair synthesis)
/devils-council:review path/to/PLAN.md

# GSD integration: review every plan in a phase
/devils-council:on-plan 7
```

### Review code

```bash
# Review a diff file
/devils-council:review path/to/diff.patch --type=code-diff

# Review your current branch against main
git diff main...HEAD > /tmp/d.patch && /devils-council:review /tmp/d.patch --type=code-diff

# GSD integration: review the committed diff for a phase
/devils-council:on-code 7                 # auto-discovers phase-start commit
/devils-council:on-code 7 --from HEAD~10  # explicit base when .planning/ is gitignored
```

Code diffs auto-trigger the Junior Engineer persona (D-12) in addition to the four core personas. Security signals in the diff wake the Security Reviewer; Helm changes wake Dual-Deploy.

### Dig into a finding

```bash
# Ask a follow-up scoped to ONE persona's scorecard
/devils-council:dig staff-engineer latest "Why is the ConfigLoader a blocker?"
/devils-council:dig security-reviewer latest "justify blocker severity"
```

Output renders synthesis-first: top-3 blockers with persona attribution, contradictions called out by name, per-persona scorecards collapsed into one-liners by default (pass `--show-nits` to expand). Raw scorecards live under `.council/<run>/<persona>.md`.

---

## Per-persona models (OpenCode)

By default every persona runs on your session model. That's wasteful — the Devil's Advocate and the Chair want a strong reasoner, but a nit-level persona on a top-tier model is just burning tokens. v1.3 lets you put each persona on a right-sized model with one setting, and you can still override any persona yourself.

Set a preset with an env var:

```bash
# bedrock | budget | cheap | off  (unset behaves as off, with a one-line hint)
export DEVILS_COUNCIL_MODEL_PRESET=bedrock
```

That's it — the next `/devils-council:review` runs each persona on its tier's model. No file to paste, nothing to wire up.

### Tiers (the categories)

Every persona is tagged with a `model_tier` in its `persona-metadata/<name>.yml` sidecar, picked by how much reasoning the role actually needs. A preset then maps each tier to a model, so you set the model in one place per tier instead of per persona.

| Tier | Personas | Why |
|------|----------|-----|
| `deep-reasoning` | Devil's Advocate, Council Chair, Security | premise attacks, cross-persona synthesis, and line-cited attack paths are reasoning-heavy |
| `workhorse` | Staff Engineer, SRE, PM, most bench | solid mid-tier critique |
| `cheap` | Executive Sponsor, Competing Team Lead | weak-signal personas |

The classifier persona is intentionally untagged — it's not a critic, so the hook leaves it on your session model.

### Presets

Three ship in `lib/model-presets.json`:

| Preset | deep-reasoning | workhorse | cheap | When to use |
|--------|----------------|-----------|-------|-------------|
| `bedrock` | opus-4-8 (`variant: max`) | sonnet-4-6 | haiku-4-5 | You're on AWS Bedrock and want the strongest reasoners where it counts. |
| `budget` | big-pickle | big-pickle | big-pickle | Near-zero cost. `big-pickle` is opencode-hosted, so no marginal Bedrock spend. |
| `cheap` | minimax-m3-free | deepseek-v4-flash-free | deepseek-v4-flash-free | Dogfooding on free opencode models. |
| `off` (or unset) | — | — | — | Everything stays on your session model. |

A note on the model picks, since they're not arbitrary: I ran every persona against a fixed benchmark on opus, sonnet, haiku, and six non-Anthropic models, then blind-judged the reasoning quality. Two things fell out. Recall (did the persona catch the seeded issue) barely moved across models. Reasoning quality did move, and the thing that separated models was **fabrication** — haiku invented an impossible concurrency bug on the deep-reasoning cells, and so did sonnet on one. `big-pickle` scored 7.5/9 on those same cells with zero fabrication, which is why `budget` leans on it rather than haiku. So `bedrock` spends on opus where the reasoning is hardest, and `budget` is a genuinely usable free council, not a toy. (Full writeup lives in the project's planning notes.)

### Define your own preset or change a tier's model

The presets are just JSON. To point a tier at a different model, edit `lib/model-presets.json` and add a preset (or tweak an existing one):

```jsonc
{
  "myteam": {
    "deep-reasoning": { "model": "amazon-bedrock/us.anthropic.claude-opus-4-8", "variant": "max" },
    "workhorse":      { "model": "opencode/big-pickle" },
    "cheap":          { "model": "opencode/big-pickle" }
  }
}
```

Then `export DEVILS_COUNCIL_MODEL_PRESET=myteam`. The selector validates against the preset names actually in the file, so a new preset just works — no code change. Each tier takes a `model` (the `provider/model` string from `opencode models`) and an optional `variant` (e.g. `max`, `high`).

To move a *persona* to a different tier, edit its `model_tier` in `persona-metadata/<name>.yml`. The lint (`scripts/validate-personas.sh`) checks every critic has a valid tier, and the build copies the sidecars into the plugin.

### Override a single persona

The preset is just a default — your own `opencode.json` always wins, per field. To put Security on a bigger model with max reasoning, **merge** this into your existing `agent` block (don't replace it):

```jsonc
{
  "agent": {
    "security-reviewer": {
      "model": "amazon-bedrock/us.anthropic.claude-opus-4-8",
      "variant": "max"
    }
  }
}
```

Everything else keeps the preset defaults; only `security-reviewer` changes.

### Precedence

For a spawned persona, model resolution is:

1. your `opencode.json` `agent.<name>.model` — always wins
2. the plugin's preset default (the tier mapping above)
3. your session model — when neither is set

Note: shipped personas are deliberately **model-silent** (no `model:` in their frontmatter), because frontmatter would beat your `opencode.json` and lock you out of overriding. A CI guardrail enforces this.

### Fail-safe

The injection runs in a `config` hook wrapped so it can never break your session: a missing/corrupt preset, a parse error, anything — it logs one line and every persona falls through to the session model. A model that isn't enabled for your provider only affects that one persona's spawn; the rest of the review still runs.

> **Heads-up:** model-availability isn't pre-validated (the OpenCode `config` hook can't call back into the server without deadlocking startup). The shipped presets use real model IDs, but if you point a preset at a model your account can't reach, that persona will fail to spawn — fix the preset or override that persona.

---

## HTML Reports

After every review, if `python3` is available, devils-council automatically generates a self-contained HTML report:

```
.council/<run-id>/REPORT.html
```

Open it in any browser — no server needed. The report includes the synthesis, all persona scorecards, finding IDs, and severity badges. Useful for sharing with teammates who don't have the plugin installed.

Generate or regenerate a report manually:

```bash
# Latest run
bin/dc-render-html.py latest

# Specific run directory
bin/dc-render-html.py .council/2026-05-16T14-32-00/
```

The HTML is fully self-contained (inline CSS, no external dependencies) so it survives being attached to a ticket or emailed.

---

## GitHub Action (CI integration)

Teammates see findings on every PR. No local install required for reviewers.

### Zero-config (free, no API key)

```yaml
name: Code Review
on: [pull_request]

jobs:
  council-review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      models: read
    steps:
      - uses: actions/checkout@v4
      - uses: astrowicked/devils-council-action@v2
```

That's it. No secrets, no signup. Uses GitHub Models (`gpt-4.1-mini`) for a quick scan from Staff Engineer + SRE personas.

### Full review (add API key)

```yaml
      - uses: astrowicked/devils-council-action@v2
        with:
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
```

Unlocks all 4 core personas + signal-triggered bench (Security, FinOps, Air-Gap, Performance) + Council Chair synthesis + inline line-level comments.

### Review plans on PR

```yaml
      - uses: astrowicked/devils-council-action@v2
        with:
          artifact: '.planning/**/PLAN.md'
          type: plan
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
```

The action fetches the PR diff (or specified artifact), runs the council, and posts findings. Blockers appear as `REQUEST_CHANGES`; majors and minors as `COMMENT`.

See [devils-council-action](https://github.com/astrowicked/devils-council-action) for full docs and configuration options.

---

## Telemetry (optional)

Devils Council can emit anonymous, opt-in usage events so the maintainer
can answer adoption + quality questions like: which personas actually fire,
where reviews fail, which prompts produce false positives, which personas
can be retired. **Default: OFF.** No event is sent unless you explicitly
opt in AND `DO_NOT_TRACK` is not set on the runner environment.

> **Note on "contract":** Throughout this section, "contract" means an
> **API contract** — a wire-format commitment about field names, types,
> and additive evolution. It is NOT a legal contract, license, or
> warranty. Devils Council makes no legal promises to operators or users
> beyond what the open-source license already grants.

**What is NEVER sent — by deliberate design.** No source code. No file
paths. No line numbers. No finding text. No model output. No
`SYNTHESIS.md` content. No persona reasoning. No PR titles, branch names,
or comment bodies. No review verdicts in determinative form. No repository
names (only the opaque server-side HMAC of `owner/repo`). The fields
enumerated below are the complete v1 surface; adding any field that could
carry intellectual property, source content, or model-generated text
would be a privacy regression and is rejected on principle.

### Why opt in

Devils Council is a small project. The only way we know which personas
actually fire, which prompts produce noise, and where reviews fail is the
events you send. With a handful of opted-in operators we can retire
personas no one ever invokes, tune prompts that produce false positives,
and fix error classes that cluster. With zero opted-in operators we're
guessing. We send no code, no finding text, no repo names — just counts,
persona names, and error classes (full schema below).

### Opt in — GitHub Action

```yaml
- uses: astrowicked/devils-council-action@v2
  with:
    anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
    telemetry: true
```

See the [action's Telemetry docs](https://github.com/astrowicked/devils-council-action#telemetry-optional)
for the full input list, fire-and-forget guarantees, and the workflow
`feedback-targets` artifact.

### Opt in — OpenCode / Claude Code plugins

Both plugin runtimes (OpenCode and Claude Code) emit a single
`review.completed` event per `/devils-council:review` run when opted in.
Emission is **env-var only**: set `DC_TELEMETRY=true` in the shell that
runs OpenCode or Claude Code, and the next slash-command invocation will
fire the POST after rendering completes.

```bash
export DC_TELEMETRY=true
# then run OpenCode or Claude Code as normal; /devils-council:review will emit
```

| Env var                   | Purpose                                                              | Default                                                 |
| ------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------- |
| `DC_TELEMETRY`            | Set to literal string `true` to enable emission.                     | unset (off)                                             |
| `DC_TELEMETRY_ENDPOINT`   | Override the default endpoint (must be `https://`).                  | `https://dc-telemetry.pub.andyjwoodard.net/v1/events`   |
| `DO_NOT_TRACK`            | Set to `1` to hard-disable telemetry regardless of any other signal. | unset                                                   |

`DC_TELEMETRY` requires the exact string `"true"` — `1`, `yes`, `on` are
NOT accepted. This is a deliberate "explicit-only" gate to avoid drift
across the runtimes' env-handling quirks.

The plugins only emit from **github repos** — `bin/dc-telemetry.sh`
inspects `git remote get-url origin`; non-github remotes (gitlab,
bitbucket, self-hosted Gitea, no remote at all) silently skip the POST
without erroring. Reason: the dc-telemetry wire schema requires
`owner_repo` in `owner/repo` form; non-github URLs cannot be parsed
unambiguously.

In v1 only `review.completed` is emitted from the plugins. `review.failed`
emission is deferred — see PLUG-05 in the [dc-telemetry
backlog](https://github.com/astrowicked/dc-telemetry/blob/main/.planning/REQUIREMENTS.md).

### Manual invocation

Telemetry fires automatically at the end of `/devils-council:review`. To
manually emit for a prior council run (or to inspect the payload
without POSTing), invoke the script directly:

```bash
# preview only — no POST
DC_TELEMETRY=true bin/dc-telemetry.sh .council/<run-dir> --runtime=claude-code --dry-run
# or --runtime=opencode

# real emit
DC_TELEMETRY=true bin/dc-telemetry.sh .council/<run-dir> --runtime=claude-code
```

`<run-dir>` is the timestamped directory produced by a prior
`/devils-council:review` invocation (look under `.council/`).

### `DO_NOT_TRACK` precedence (hard override)

Precedence chain, highest wins:

1. `DO_NOT_TRACK=1` environment variable on the runner / dev shell — HARD OFF.
2. Client config flag (action input `telemetry: false`, or plugin `DC_TELEMETRY` not equal to `"true"`).
3. Opt-in input (`telemetry: true` on the action; `DC_TELEMETRY=true` for plugins).

If `DO_NOT_TRACK=1` is set, NO event is sent regardless of any other
config — even if `telemetry: true` is also set on the action or
`DC_TELEMETRY=true` is set in the plugin shell. The action logs
`::notice::telemetry: DO_NOT_TRACK honored, no event sent`; the plugins
exit silently (no logging surface — fire-and-forget by design).

### Event envelope

Every event uses the v1 envelope:

| Field        | Type               | Required | Notes                                                              |
| ------------ | ------------------ | -------- | ------------------------------------------------------------------ |
| `event_type` | string enum        | yes      | One of `review.completed` \| `review.failed`.                      |
| `owner_repo` | string `owner/repo`| yes      | Server HMACs this into `repo_hash` and drops the plaintext. Clients never send a hash. |
| `payload`    | JSON object        | yes      | Per-event shape; see tables below.                                 |

Every payload also carries `schema_version: 1` so future additions are
additive without breaking existing consumers.

### `review.completed` payload fields

| Field              | Type          | Required | Example                                  | Notes                                                                                          |
| ------------------ | ------------- | -------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `schema_version`   | integer       | yes      | `1`                                      | Always `1` in v1; additive-only API contract going forward.                                    |
| `ts`               | string (ISO)  | yes      | `2026-05-19T19:03:56.060Z`               | Client-set UTC ISO8601.                                                                        |
| `source`           | enum string   | yes      | `"action"`                               | One of `"action"` \| `"plugin"`.                                                               |
| `runtime`          | enum string   | yes      | `"action-shell"`                         | One of `"action-shell"` \| `"opencode"` \| `"claude-code"`.                                    |
| `client_version`   | string        | yes      | `"v2.3.0"`                               | The action version (or plugin version) emitting the event.                                     |
| `provider`         | enum string   | no       | `"anthropic"`                            | One of `"anthropic"` \| `"bedrock"` \| `"github-models"`. Nullable.                            |
| `model`            | string        | no       | `"claude-sonnet-4-20250514"`             | The model ID used. Nullable.                                                                   |
| `blocker_count`    | integer       | yes      | `0`                                      | Count of BLOCKER-severity findings.                                                            |
| `major_count`      | integer       | yes      | `2`                                      | Count of MAJOR-severity findings.                                                              |
| `minor_count`      | integer       | yes      | `1`                                      | Count of MINOR-severity findings.                                                              |
| `nit_count`        | integer       | yes      | `4`                                      | Count of NIT-severity findings.                                                                |
| `findings_total`   | integer       | yes      | `7`                                      | Total findings produced (pre-threshold filter).                                                |
| `findings_dropped` | integer       | yes      | `0`                                      | Findings filtered by `severity-threshold` or `max-findings`.                                   |
| `triggered_bench`  | array<string> | yes      | `["staff-engineer", "security-reviewer"]`| Persona names whose scorecards had non-empty findings for this run.                            |
| `duration_s`       | number        | yes      | `48`                                     | End-to-end wall-clock for the council review, in seconds.                                      |

No `verdict` field is sent. Downstream dashboards derive a verdict-like
signal from the counts (`blocker_count > 0` → BLOCK, `major_count > 0` →
WARN, else PASS). Keeping the determination out of the wire payload
removes a future leak vector for the underlying reasoning.

### `review.failed` payload fields

| Field            | Type         | Required | Example                       | Notes                                                                                          |
| ---------------- | ------------ | -------- | ----------------------------- | ---------------------------------------------------------------------------------------------- |
| `schema_version` | integer      | yes      | `1`                           | Same as above.                                                                                 |
| `ts`             | string (ISO) | yes      | `2026-05-19T19:03:56.060Z`    | Client-set UTC ISO8601.                                                                        |
| `source`         | enum string  | yes      | `"action"`                    | One of `"action"` \| `"plugin"`.                                                               |
| `runtime`        | enum string  | yes      | `"action-shell"`              | Same enum as `review.completed`.                                                               |
| `client_version` | string       | yes      | `"v2.3.0"`                    | Same as `review.completed`.                                                                    |
| `error_class`    | enum string  | yes      | `"synthesis-failed"`          | Failure classification. Full v1 enum: `synthesis-failed`, `prep-failed`, `no-api-key`, `timeout`, `model-error`, `validation-failed`. Different client versions emit different subsets — `devils-council-action@v2.3.0` emits `synthesis-failed` + `prep-failed`; the rest are reserved for future clients with finer classification. |
| `stage`          | enum string  | yes      | `"synthesis"`                 | One of `"prep"` \| `"persona-run"` \| `"validation"` \| `"synthesis"`.                         |

Consumers MUST treat any unknown `error_class` value as the catch-all
"failure of an unspecified subclass" rather than rejecting the event.

No error message strings, no stack traces, no log lines are sent. Only
the classified `error_class` + `stage` enums.

### Fire-and-forget guarantees

- 3-second total time budget on the POST (`curl --max-time 3 --connect-timeout 2`).
- POST failure NEVER blocks the action or the plugin — the emitter always
  exits 0 / continues normally.
- Successful POSTs log nothing; failures log a single `::notice::` (action)
  or equivalent (plugin) annotation.

### Self-host

The reference endpoint is one collector, not a required dependency. Run
your own (see [dc-telemetry](https://github.com/astrowicked/dc-telemetry#privacy--telemetry))
and point clients at it.

For the GitHub Action, set `telemetry-endpoint:`:

```yaml
- uses: astrowicked/devils-council-action@v2
  with:
    anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
    telemetry: true
    telemetry-endpoint: https://telemetry.yourcompany.example/v1/events
```

For the OpenCode / Claude Code plugins, export `DC_TELEMETRY_ENDPOINT`
in the same shell:

```bash
export DC_TELEMETRY=true
export DC_TELEMETRY_ENDPOINT=https://telemetry.yourcompany.example/v1/events
```

The endpoint must be `https://` — `bin/dc-telemetry.sh` silently rejects
any other scheme (SSRF mitigation). The collector requires an HMAC secret
to boot; without it the service refuses to start.

---

## Persona Roster

Sixteen personas ship in v1.6.0. Core tier always runs; bench tier auto-triggers on artifact signals.

| Persona | Tier | Primary Concern | Trigger / always-on |
|---------|------|-----------------|---------------------|
| [Staff Engineer](agents/staff-engineer.md) | core | Simplicity, YAGNI, right-sized design | always-on |
| [SRE / On-call](agents/sre.md) | core | Operational reality, failure modes | always-on |
| [Product Manager](agents/product-manager.md) | core | Business alignment, user value | always-on |
| [Devil's Advocate](agents/devils-advocate.md) | core | Red-team, premise attack | always-on |
| [Security Reviewer](agents/security-reviewer.md) | bench | Authn/z, crypto, input handling, dependencies | auth/crypto code, secret handling, dep update |
| [FinOps Auditor](agents/finops-auditor.md) | bench | Cloud cost, storage/compute efficiency | AWS SDK, new cloud resource, autoscaling, storage class |
| [Air-Gap Reviewer](agents/air-gap-reviewer.md) | bench | Self-hosted, no-egress, pinned deps | network egress, external image pull, unpinned dep, license phone-home |
| [Dual-Deploy Reviewer](agents/dual-deploy-reviewer.md) | bench | SaaS + self-hosted parity, Helm/KOTS surface | Helm values change, Chart.yaml, KOTS config, SaaS-only assumption |
| [Compliance Reviewer](agents/compliance-reviewer.md) | bench | Regulatory control citations (GDPR, HIPAA, SOC2, PCI) | compliance_marker signal |
| [Performance Reviewer](agents/performance-reviewer.md) | bench | Hot-path characterization, worst-case latency | perf_sensitive signal |
| [Test Lead](agents/test-lead.md) | bench | Circular tests, flaky patterns, coverage gaps | test_imbalance signal |
| [Executive Sponsor](agents/executive-sponsor.md) | bench | Quantified business impact (dollars, weeks, customers) | exec_keyword signal (plan/rfc only) |
| [Competing Team Lead](agents/competing-team-lead.md) | bench | Shared-infra consumer impact | shared_infra_change signal |
| [Junior Engineer](agents/junior-engineer.md) | bench | First-person comprehension failure | always-invokable on code-diff (D-12) |
| [Council Chair](agents/council-chair.md) | chair | Contradiction synthesis, top-3 blockers | always-on; runs sequentially after core + bench |
| [Artifact Classifier](agents/artifact-classifier.md) | classifier | Ambiguous artifact type routing | Haiku fallback when structural signals are zero |

Each persona has a distinct value-system anchor, characteristic-objection list, and banned-phrase list; a blinded-reader test on a sample artifact can attribute scorecards to personas without filenames (Phase 4 CORE-05 criterion; verified 2026-04-23).

---

## Trigger Rules

Bench personas auto-join the review when the classifier detects structural signals in the artifact. Signal detection is pure-function filename + AST + Helm-key + Chart.yaml + AWS-SDK-import matching — NOT keyword matching (per BNCH-01). Ambiguous artifacts fall back to a Haiku-classifier subagent.

<details>
<summary>21 signals (expand)</summary>

Source of truth: [`lib/signals.json`](lib/signals.json).

| Signal ID | Description | Target personas |
|-----------|-------------|-----------------|
| `auth_code_change` | Auth/session/token code (auth\*, session\*, jwt\*, bcrypt/jose imports, /login endpoints) | security-reviewer |
| `crypto_import` | Imports of cryptographic primitives or RNG | security-reviewer |
| `secret_handling` | Env-var reads, secret-manager fetches, KMS calls | security-reviewer |
| `dependency_update` | Lockfile / package.json / requirements.txt / go.sum / Cargo.lock diffs | security-reviewer, air-gap-reviewer |
| `aws_sdk_import` | New use of AWS SDK client (`@aws-sdk/client-*`, `aws-sdk`, `boto3`) | finops-auditor |
| `new_cloud_resource` | New Terraform / CDK / CloudFormation / Pulumi resource | finops-auditor, dual-deploy-reviewer |
| `autoscaling_change` | HPA, ASG, replica count, batch concurrency | finops-auditor |
| `storage_class_change` | S3 StorageClass, GCS storageClass, PV storageClassName, lifecycle policies | finops-auditor |
| `network_egress` | Outbound calls to non-loopback hostnames, NetworkPolicy egress | air-gap-reviewer |
| `external_image_pull` | Dockerfile FROM / Pod image / values image.repository outside org registry | air-gap-reviewer, dual-deploy-reviewer |
| `unpinned_dependency` | Ranges instead of pins, `:latest` tags, unversioned deps | air-gap-reviewer |
| `license_phone_home` | Sentry/Datadog/Mixpanel/Amplitude/license-server SDKs | air-gap-reviewer |
| `helm_values_change` | `values.yaml` / `values.schema.json` / templates referencing `.Values.*` | dual-deploy-reviewer |
| `chart_yaml_present` | Artifact contains or modifies `Chart.yaml` | dual-deploy-reviewer |
| `kots_config_change` | `kots-*.yaml` / `kind: Config` (kots.io) | dual-deploy-reviewer |
| `saas_only_assumption` | Single-tenant, cloud-only architectural assumptions | dual-deploy-reviewer |
| `compliance_marker` | GDPR/HIPAA/SOC2/PCI references, data-residency requirements | compliance-reviewer |
| `perf_sensitive` | Hot-path annotations, latency SLOs, throughput targets | performance-reviewer |
| `test_imbalance` | Test-to-implementation ratio anomalies, mock-heavy patterns | test-lead |
| `exec_keyword` | Business-impact language, OKR references, revenue/cost framing | executive-sponsor |
| `shared_infra_change` | Shared platform components, cross-team API surface changes | competing-team-lead |

</details>

Override the auto-selection with flags:

```bash
/devils-council:review path/to/diff --only=security-reviewer,sre
/devils-council:review path/to/diff --exclude=devils-advocate
/devils-council:review path/to/diff --cap-usd=0.25
```

Trigger reasons appear in `MANIFEST.trigger_reasons{}` for every bench persona that joined a run.

---

## Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `/devils-council:review <artifact>` | Primary entry point: runs core + triggered bench + Chair synthesis on a file / stdin | `/devils-council:review plan.md` |
| `/devils-council:on-plan <phase>` | Review every `.planning/phases/<NN>-*/<NN>-*-PLAN.md` for a GSD phase | `/devils-council:on-plan 7` |
| `/devils-council:on-code <phase>` | Review the committed diff for a GSD phase; `--from <ref>` fallback for commit_docs=false projects | `/devils-council:on-code 7 --from HEAD~10` |
| `/devils-council:dig <persona> <run-id\|latest> [question]` | Ask a follow-up scoped to ONE persona's scorecard; single-turn, ephemeral | `/devils-council:dig security-reviewer latest "justify blocker severity"` |
| `/devils-council:create-persona [slug]` | Interactive wizard to scaffold a custom persona with voice-kit coaching | `/devils-council:create-persona cost-hawk` |

Flags on `review`:
- `--only=<persona,persona>` — force-include (ignores triggers)
- `--exclude=<persona,persona>` — force-exclude
- `--cap-usd=<N>` — override budget cap
- `--type=code-diff|plan|rfc` — override auto-detected artifact type
- `--show-nits` — expand collapsed nits inline (default: nits hidden, one-line summary)

---

## Configuration

### Budget cap (config.json)

```json
{
  "budget": {
    "cap_usd": 0.50,
    "per_persona_estimate_usd": 0.05,
    "bench_priority_order": ["security-reviewer", "compliance-reviewer", "dual-deploy-reviewer", "performance-reviewer", "finops-auditor", "air-gap-reviewer", "test-lead", "executive-sponsor", "competing-team-lead"]
  }
}
```

Default cap is $0.50 / 30s per invocation. When exceeded, further bench fan-out is halted and skipped personas appear in `MANIFEST.personas_skipped[]`. Override per-invocation with `--cap-usd=<N>`.

### GSD integration

Off by default. When enabled, a one-line pointer appears after `gsd-plan-checker` or `gsd-code-reviewer` runs, directing you to `/devils-council:review <path>`.

For OpenCode, set in your project's `opencode.json`:

```json
{
  "plugin": ["devils-council-opencode"],
  "devils-council": {
    "gsd_integration": true
  }
}
```

For Claude Code, toggle via:

```bash
/plugin config devils-council
# Toggle: gsd_integration → true
```

The hook is a no-op when GSD is not installed.

---

## Custom Personas

Create a custom persona interactively:

```
/devils-council:create-persona
```

Or provide a slug directly:

```
/devils-council:create-persona cost-hawk
```

The scaffolder walks you through every voice-kit field:

1. **Name** (kebab-case slug)
2. **Tier** (core = always-on, bench = signal-triggered)
3. **Primary concern** (one-sentence value-system anchor ending with `?`)
4. **Blind spots** (what this persona does NOT care about)
5. **Characteristic objections** (3+ verbatim phrases)
6. **Banned phrases** (5+ phrases the persona must never use)
7. **Worked examples** (2 good findings + 1 bad finding)

The scaffolder:
- Suggests available signal IDs for bench triggers
- Warns if your banned phrases overlap >30% with a shipped persona
- Flags objections that contain your own banned phrases
- Previews the full file before writing
- Validates against `scripts/validate-personas.sh` before declaring success

Output lands in:

```
${DC_ROOT}/create-persona-workspace/<slug>/
  agents/<slug>.md
  persona-metadata/<slug>.yml
```

To install into your plugin:

```bash
cp "${DC_ROOT}/create-persona-workspace/<slug>/agents/<slug>.md" agents/
cp "${DC_ROOT}/create-persona-workspace/<slug>/persona-metadata/<slug>.yml" persona-metadata/
./scripts/validate-personas.sh
```

---

## Codex Setup

Security + Dual-Deploy personas delegate deep code scans to Codex via `codex exec --json --sandbox read-only`.

### 1. Install

macOS:

```bash
brew install --cask codex
```

Linux / as fallback:

```bash
npm install -g @openai/codex
```

Verify: `codex --version` (expected: 0.122.0 or newer).

### 2. Authenticate (OAuth — recommended)

```bash
codex login
```

Browser opens for ChatGPT OAuth. Credentials land in `~/.codex/` (gitignored).

Verify: `codex login status` exits 0.

### 3. Authenticate (API key — CI / headless)

```bash
export OPENAI_API_KEY="sk-..."
echo "$OPENAI_API_KEY" | codex login --with-api-key
codex login status
```

### 4. Smoke test

```bash
./scripts/smoke-codex.sh
# Expected: "smoke-codex: OK" and exit 0
# First run ~7s on a fast network.
```

### Sandbox

`--sandbox read-only` is fixed in v1 (no writes, no network beyond Codex's own API). Widening is a post-v1 decision requiring a dedicated threat-model review.

---

## Responses Workflow

After a review, annotate findings by editing `.council/responses.md`:

```yaml
---
version: 1
responses:
  - finding_id: security-reviewer-a3f2c1d8
    status: dismissed
    reason: legacy migration path, tracked in adr-014
    date: 2026-04-24
  - finding_id: sre-b9e401f2
    status: accepted
    reason: will fix in follow-up PR
    date: 2026-04-24
---
# Notes (free-form body)
```

`status` enum: `accepted | dismissed | deferred`. `finding_id` format is `<persona-slug>-<8hex>` (stable across re-runs of the same artifact with the same persona and target+claim per Phase 5 D-38).

On re-run: dismissed findings are suppressed from Chair synthesis; a one-line `Suppressed N findings per .council/responses.md (dismissed: N1, deferred: N2)` note renders above top-3.

See [Troubleshooting #4](#4-dismissals-not-suppressing-on-re-run-resp-03-llm-variance) for a known limitation.

---

## Troubleshooting

### 1. Plugin cache staleness after version bump

**Symptom:** new commands (`on-plan`, `on-code`, `dig`) don't appear in the picker after `/plugin install` on an already-installed older version. `claude plugin list --json` still reports the old version.

**Fix:** version bumps require uninstall + reinstall — this is documented Claude Code behavior, not a devils-council bug:

```bash
/plugin uninstall devils-council@devils-council
/plugin install devils-council@devils-council
```

### 2. Install picks up old version after tag bump

**Symptom:** After a new tag ships, `/plugin install devils-council@devils-council` still installs the old version because the marketplace descriptor is cached locally.

**Fix:** refresh the marketplace descriptor first, THEN reinstall:

```bash
/plugin marketplace update devils-council
/plugin uninstall devils-council@devils-council
/plugin install devils-council@devils-council
```

Confirm the new version is loaded:

```bash
claude plugin list --json | jq '.[] | select(.name=="devils-council") | .version'
```

This is Claude Code marketplace-caching behavior, not a devils-council bug.

### 3. Codex unavailable

**Symptom:** Security or Dual-Deploy scorecard includes a finding with `category: delegation_failed`; `[devils-council: Codex unavailable, persona proceeded without deep scan]` in command output.

**Fix:** `codex login status` (exit non-zero = not authed); re-run `codex login`. If Codex CLI isn't installed, see [Codex Setup](#codex-setup). If delegation_failed persists with Codex healthy, run `./scripts/smoke-codex.sh` and inspect stderr.

Per D-51 the plugin is fail-loud by design — it does NOT silently degrade.

### 4. Dismissals not suppressing on re-run (RESP-03 LLM variance)

**Symptom:** you dismissed a finding in `.council/responses.md`, but it re-appears on re-run with a slightly different `claim` and a different finding ID.

**Cause:** finding IDs hash `persona + target + claim`. Personas may produce slightly different claim text across re-runs. Same concern, different hash.

**Workaround:** dismiss multiple variants proactively. Or use `--exclude=<persona>` on re-run to skip the persona while you investigate.

**Fix tracked:** normalize `claim` before hashing (lowercase + stopword-strip + whitespace-collapse).

### 5. GSD hook integration not firing

**Symptom:** after `gsd-plan-checker` runs, no `[devils-council: ...]` pointer appears.

**Checks:**
1. Opt-in on? For OpenCode: `gsd_integration: true` in `opencode.json`. For Claude Code: `jq '.plugins.devils-council.userConfig.gsd_integration' ~/.claude/settings.json` (expected: `true`)
2. GSD installed? `ls ~/.claude/agents/gsd-plan-checker.md ~/.claude/agents/gsd-code-reviewer.md` — at least one must exist
3. Hook registered? Check `bin/dc-gsd-wrap.sh` extraction — the `tool_input.prompt` field might not contain an extractable PLAN.md path. Run the guard test locally: `./scripts/test-hooks-gsd-guard.sh`.

### 6. Bench persona not spawning despite artifact match

**Symptom:** reviewing a Helm values diff, but dual-deploy-reviewer didn't join.

**Checks:**
1. `cat .council/<run>/MANIFEST.json | jq '.classifier'` — did the classifier detect `helm_values_change`?
2. Does the persona's `triggers:` list in `agents/dual-deploy-reviewer.md` include the signal ID?
3. Was the budget cap reached? `jq '.personas_skipped' .council/<run>/MANIFEST.json` lists personas dropped by the cap.

### 7. Codex sandbox violation in delegation

**Symptom:** `MANIFEST.personas_run[].delegation.error_code == "codex_sandbox_violation"` — Codex rejected a delegation.

**Cause:** persona requested a write or network-access operation. Expected behavior per D-51 fail-loud; the persona emits a `category: delegation_failed` finding and the scorecard still ships.

**Fix:** v1 is read-only sandbox by design. Widening is deferred to post-v1 threat-model review.

### 8. Budget cap too low — important personas skipped

**Symptom:** `jq '.personas_skipped' .council/<run>/MANIFEST.json` shows a non-empty array and you wanted those personas to run.

**Fix:** `/devils-council:review <artifact> --cap-usd=1.00` (or edit `config.json` `budget.cap_usd` for a persistent change). Priority order is controllable via `config.json` `bench_priority_order`.

### 9. Terminal render unreadable — too much output

**Symptom:** synthesis + 4-8 scorecards fills the terminal.

**Fix:** default render collapses nits. If still too much, read raw scorecards directly:

```bash
ls -t .council/ | head -1 | xargs -I{} cat ".council/{}/staff-engineer.md"
```

Or open the HTML report instead:

```bash
open .council/$(ls -t .council/ | head -1)/REPORT.html
```

Or use `--show-nits` only when you want everything inline (default: top-3 blockers + major/minor one-liners + nits-collapsed summary).

---

## Uninstall

**OpenCode:** remove `"devils-council-opencode"` from your `opencode.json` plugin array.

**Claude Code:**

```bash
/plugin uninstall devils-council@devils-council
/plugin marketplace remove astrowicked/devils-council
```

Runtime artifacts under `.council/<run-id>/` (review outputs) and `~/.codex/` (Codex credentials) are NOT removed by uninstall — delete manually if desired.

---

## Contributing

PRs welcome. See the phase-artifact trail under `.planning/` (in-repo, gitignored for public users — fork to see planning docs) for the design rationale behind every shipped feature. Personas are markdown files under `agents/` with YAML frontmatter; add a new one and `scripts/validate-personas.sh` will accept it if the schema holds.

Tests: `bash scripts/validate-personas.sh` for a quick check; full suite lives in `.github/workflows/ci.yml`.

---

## Publishing (OpenCode npm package)

The OpenCode plugin is published to npm as `devils-council-opencode` via GitHub Actions on tag push.

**Release workflow:**

```bash
# 1. Bump version in both manifests
#    .claude-plugin/plugin.json → "version": "X.Y.Z"
#    .opencode/package.json    → "version": "X.Y.Z"
# 2. Update CHANGELOG.md
# 3. Commit & tag
git add -A && git commit -m "chore: bump version to X.Y.Z"
git tag vX.Y.Z
git push origin main --tags
```

The `publish-opencode.yml` workflow automatically builds and publishes to npm when a `v*` tag is pushed.

**Setup (one-time):**

1. Create an npm access token at <https://www.npmjs.com/settings/tokens> (type: Automation)
2. Add it as a repository secret: Settings → Secrets → Actions → `NPM_TOKEN`
3. First publish requires the npm account to own the `devils-council-opencode` package name

**Local build/test:**

```bash
cd .opencode
npm install --legacy-peer-deps
bash build.sh          # transforms agents + compiles TypeScript
npm test               # runs signal + speckit-hook tests
npm pack --dry-run     # verify tarball contents
```

---

## License

MIT — see [LICENSE](./LICENSE).
