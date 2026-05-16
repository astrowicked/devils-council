# devils-council

**Adversarial AI review — 4 experts find what you missed before you ship.**

> Before your plan, code, or RFC goes out, a Staff Engineer, SRE, Product Manager, and Devil's Advocate independently rip it apart. In 48 seconds. Every finding cites your own words back at you.

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![npm](https://img.shields.io/npm/v/devils-council-opencode)](https://www.npmjs.com/package/devils-council-opencode)
[![version](https://img.shields.io/badge/version-1.4.0-brightgreen)](CHANGELOG.md)

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

**Status:** v1.4.0 — Dual-runtime plugin (OpenCode + Claude Code). MIT licensed.

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
# Expected: "1.4.0"
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

### Review plans on PR

```yaml
- uses: astrowicked/devils-council-action@v1
  with:
    artifact: '.planning/**/PLAN.md'
    anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
```

### Review code on PR

Post findings as inline PR review comments on every pull request:

```yaml
- uses: astrowicked/devils-council-action@v1
  with:
    artifact: ${{ github.event.pull_request.diff_url }}
    type: code-diff
    anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
    post-as: inline-review  # posts findings as inline PR review comments
```

The action fetches the PR diff, runs the full council, and posts each finding as an inline comment on the relevant file and line. Blockers appear as `REQUEST_CHANGES`; majors and minors as `COMMENT`.

See [devils-council-action](https://github.com/astrowicked/devils-council-action) for full docs and configuration options.

---

## Persona Roster

Sixteen personas ship in v1.4.0. Core tier always runs; bench tier auto-triggers on artifact signals.

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
