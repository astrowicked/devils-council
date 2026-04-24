# devils-council

> Persona-driven adversarial review for plans, code, and design artifacts. Catch weak plans, overengineered designs, and business misalignment *before* execution — by surfacing the pushback a senior engineering org would give.

**Status:** v1.0.0 — 10 personas shipped (4 core + 4 bench + Chair + classifier), Codex-backed deep scans for Security + Dual-Deploy, hard budget cap, stable finding IDs, response-workflow suppression, severity-tier render, and prompt-injection corpus in CI.

**Repo:** <https://github.com/astrowicked/devils-council> · **License:** MIT · **Claude Code:** v2.1.63+

## Core Value

Four always-on core personas (Staff Engineer, SRE, Product Manager, Devil's Advocate) critique the artifact in parallel. Four bench personas (Security, FinOps, Air-Gap, Dual-Deploy) auto-trigger on structural signals — Helm values changes wake Dual-Deploy; AWS SDK imports wake FinOps; auth/crypto code wakes Security. A Council Chair synthesizes contradictions **by name** ("PM says ship, SRE says block because...") without collapsing dissent into a scalar verdict. Every finding cites a verbatim quote from the artifact; every finding has a stable ID so dismissals persist across re-runs.

## Requirements

- **Claude Code** v2.1.63 or newer (`Agent` subagent tool)
- **jq** (macOS: `brew install jq`; Ubuntu: `apt install jq`)
- **python3** + PyYAML (`pip install pyyaml`)
- **OpenAI Codex CLI** — required for v1; used by Security + Dual-Deploy personas (see [Codex Setup](#codex-setup))
- **Node 18+** only if installing Codex via `npm` (`brew install --cask codex` avoids this)

## Install

From the GitHub marketplace (recommended):

```bash
/plugin marketplace add astrowicked/devils-council
/plugin install devils-council@devils-council
```

Verify:

```bash
claude plugin list --json | jq '.[] | select(.name=="devils-council") | .version'
# Expected: "1.0.0"
```

After upgrade (see [Troubleshooting #1](#1-plugin-cache-staleness-after-version-bump) if new commands don't appear):

```bash
/plugin uninstall devils-council@devils-council
/plugin install devils-council@devils-council
```

## Uninstall

```bash
/plugin uninstall devils-council@devils-council
/plugin marketplace remove astrowicked/devils-council
```

Runtime artifacts under `.council/<run-id>/` (review outputs) and `~/.codex/` (Codex credentials) are NOT removed by uninstall — delete manually if desired.

## Quickstart

```bash
# Review a plan (core personas + any triggered bench personas + Chair synthesis)
/devils-council:review path/to/PLAN.md

# Review code via file or stdin
/devils-council:review path/to/diff.patch --type=code-diff
git diff main...feature > /tmp/d.patch && /devils-council:review /tmp/d.patch --type=code-diff

# Dig into ONE persona's findings after a review
/devils-council:dig staff-engineer latest "Why is the ConfigLoader a blocker?"

# GSD integration: review every plan in a phase, or the phase's committed diff
/devils-council:on-plan 7
/devils-council:on-code 7                 # auto-discovers phase-start commit
/devils-council:on-code 7 --from HEAD~10  # explicit base when .planning/ is gitignored
```

Output renders synthesis-first: top-3 blockers with persona attribution, contradictions called out by name, per-persona scorecards collapsed into one-liners by default (pass `--show-nits` to expand). Raw scorecards live under `.council/<run>/<persona>.md`.

## Persona Roster

Ten personas ship in v1.0.0. Core tier always runs; bench tier auto-triggers on artifact signals.

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
| [Council Chair](agents/council-chair.md) | chair | Contradiction synthesis, top-3 blockers | always-on; runs sequentially after core + bench |
| [Artifact Classifier](agents/artifact-classifier.md) | classifier | Ambiguous artifact type routing | Haiku fallback when structural signals are zero |

Each persona has a distinct value-system anchor, characteristic-objection list, and banned-phrase list; a blinded-reader test on a sample artifact can attribute scorecards to personas without filenames (Phase 4 CORE-05 criterion; verified 2026-04-23).

## Trigger Rules

Bench personas auto-join the review when the classifier detects structural signals in the artifact. Signal detection is pure-function filename + AST + Helm-key + Chart.yaml + AWS-SDK-import matching — NOT keyword matching (per BNCH-01). Ambiguous artifacts fall back to a Haiku-classifier subagent.

<details>
<summary>16 signals (expand)</summary>

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

</details>

Override the auto-selection with flags:

```bash
/devils-council:review path/to/diff --only=security-reviewer,sre
/devils-council:review path/to/diff --exclude=devils-advocate
/devils-council:review path/to/diff --cap-usd=0.25
```

Trigger reasons appear in `MANIFEST.trigger_reasons{}` for every bench persona that joined a run.

## Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `/devils-council:review <artifact>` | Primary entry point: runs core + triggered bench + Chair synthesis on a file / stdin | `/devils-council:review plan.md` |
| `/devils-council:on-plan <phase>` | Review every `.planning/phases/<NN>-*/<NN>-*-PLAN.md` for a GSD phase | `/devils-council:on-plan 7` |
| `/devils-council:on-code <phase>` | Review the committed diff for a GSD phase; `--from <ref>` fallback for commit_docs=false projects | `/devils-council:on-code 7 --from HEAD~10` |
| `/devils-council:dig <persona> <run-id\|latest> [question]` | Ask a follow-up scoped to ONE persona's scorecard; single-turn, ephemeral | `/devils-council:dig security-reviewer latest "justify blocker severity"` |

Flags on `review`:
- `--only=<persona,persona>` — force-include (ignores triggers)
- `--exclude=<persona,persona>` — force-exclude
- `--cap-usd=<N>` — override budget cap
- `--type=code-diff|plan|rfc` — override auto-detected artifact type
- `--show-nits` — expand collapsed nits inline (default: nits hidden, one-line summary)

## Configuration

### Budget cap (config.json)

```json
{
  "budget": {
    "cap_usd": 0.50,
    "per_persona_estimate_usd": 0.05,
    "bench_priority_order": ["security-reviewer", "dual-deploy-reviewer", "finops-auditor", "air-gap-reviewer"]
  }
}
```

Default cap is $0.50 / 30s per invocation. When exceeded, further bench fan-out is halted and skipped personas appear in `MANIFEST.personas_skipped[]`. Override per-invocation with `--cap-usd=<N>`.

### GSD integration (userConfig)

Off by default. To enable PostToolUse wrapping of `gsd-plan-checker` and `gsd-code-reviewer` (appends a one-line pointer directing you to `/devils-council:review <path>` after a GSD agent runs):

```bash
/plugin config devils-council
# Toggle: gsd_integration → true
```

Or edit `~/.claude/settings.json` directly. The hook is a no-op when GSD is not installed (checks `~/.claude/agents/gsd-plan-checker.md` presence).

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

See [Troubleshooting #3](#3-dismissals-not-suppressing-on-re-run-resp-03-llm-variance) for a known limitation.

## Troubleshooting

### 1. Plugin cache staleness after version bump

**Symptom:** new commands (`on-plan`, `on-code`, `dig`) don't appear in the picker after `/plugin install` on an already-installed older version. `claude plugin list --json` still reports the old version.

**Fix:** version bumps require uninstall + reinstall — this is documented Claude Code behavior, not a devils-council bug:

```bash
/plugin uninstall devils-council@devils-council
/plugin install devils-council@devils-council
```

A v1.1 ticket tracks adding a first-class cache-invalidation mechanism upstream.

### 2. Codex unavailable

**Symptom:** Security or Dual-Deploy scorecard includes a finding with `category: delegation_failed`; `[devils-council: Codex unavailable, persona proceeded without deep scan]` in command output.

**Fix:** `codex login status` (exit non-zero = not authed); re-run `codex login`. If Codex CLI isn't installed, see [Codex Setup](#codex-setup). If delegation_failed persists with Codex healthy, run `./scripts/smoke-codex.sh` and inspect stderr.

Per D-51 the plugin is fail-loud by design — it does NOT silently degrade.

### 3. Dismissals not suppressing on re-run (RESP-03 LLM variance)

**Symptom:** you dismissed a finding in `.council/responses.md`, but it re-appears on re-run with a slightly different `claim` and a different finding ID.

**Cause:** finding IDs hash `persona + target + claim`. Personas may produce slightly different claim text across re-runs (e.g., "Deploy-time reset of the token bucket means every deploy gra..." vs "Deploy resets every token bucket, so every deploy is an inst..."). Same concern, different hash.

**Workaround for v1.0:** dismiss multiple variants proactively. Or use `--exclude=<persona>` on re-run to skip the persona while you investigate.

**v1.1 fix tracked:** normalize `claim` before hashing (lowercase + stopword-strip + whitespace-collapse). See `.planning/phases/07-hardening-injection-defense-response-workflow/07-UAT.md` finding #2 for the full rationale.

### 4. GSD hook integration not firing

**Symptom:** after `gsd-plan-checker` runs, no `[devils-council: ...]` pointer appears.

**Checks:**
1. Opt-in on? `jq '.plugins.devils-council.userConfig.gsd_integration' ~/.claude/settings.json` (expected: `true`)
2. GSD installed? `ls ~/.claude/agents/gsd-plan-checker.md ~/.claude/agents/gsd-code-reviewer.md` — at least one must exist
3. Hook registered? `jq '.hooks.PostToolUse' ~/.claude/plugins/cache/devils-council/devils-council/1.0.0/hooks/hooks.json` (should show the Agent matcher)

If all three look right and the pointer still doesn't appear, check `bin/dc-gsd-wrap.sh` extraction — the `tool_input.prompt` field might not contain an extractable PLAN.md path. Run the guard test locally: `./scripts/test-hooks-gsd-guard.sh`.

### 5. Bench persona not spawning despite artifact match

**Symptom:** reviewing a Helm values diff, but dual-deploy-reviewer didn't join.

**Checks:**
1. `cat .council/<run>/MANIFEST.json | jq '.classifier'` — did the classifier detect `helm_values_change`?
2. Does the persona's `triggers:` list in `agents/dual-deploy-reviewer.md` include the signal ID?
3. Was the budget cap reached? `jq '.personas_skipped' .council/<run>/MANIFEST.json` lists personas dropped by the cap.

### 6. Codex sandbox violation in delegation

**Symptom:** `MANIFEST.personas_run[].delegation.error_code == "codex_sandbox_violation"` — Codex rejected a delegation.

**Cause:** persona requested a write or network-access operation. Expected behavior per D-51 fail-loud; the persona emits a `category: delegation_failed` finding and the scorecard still ships.

**Fix:** v1 is read-only sandbox by design. Widening is deferred to post-v1 threat-model review.

### 7. Budget cap too low — important personas skipped

**Symptom:** `jq '.personas_skipped' .council/<run>/MANIFEST.json` shows a non-empty array and you wanted those personas to run.

**Fix:** `/devils-council:review <artifact> --cap-usd=1.00` (or edit `config.json` `budget.cap_usd` for a persistent change). Priority order is controllable via `config.json` `bench_priority_order`.

### 8. Terminal render unreadable — too much output

**Symptom:** synthesis + 4-8 scorecards fills the terminal.

**Fix:** default render collapses nits. If still too much, read raw scorecards directly:

```bash
ls -t .council/ | head -1 | xargs -I{} cat ".council/{}/staff-engineer.md"
```

Or use `--show-nits` only when you want everything inline (default: top-3 blockers + major/minor one-liners + nits-collapsed summary).

## Contributing

PRs welcome. See the phase-artifact trail under `.planning/` (in-repo, gitignored for public users — fork to see planning docs) for the design rationale behind every shipped feature. Personas are markdown files under `agents/` with YAML frontmatter; add a new one and `scripts/validate-personas.sh` will accept it if the schema holds.

Tests: `bash scripts/validate-personas.sh && claude plugin validate .` for a quick check; full suite lives in `.github/workflows/ci.yml`.

## License

MIT — see [LICENSE](./LICENSE).
