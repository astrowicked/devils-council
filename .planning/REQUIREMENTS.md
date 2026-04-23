# Requirements: devils-council

**Defined:** 2026-04-22
**Core Value:** Catch weak plans, overengineered designs, and business misalignment *before* execution — by surfacing the pushback a senior engineering org would give, in a form the author can respond to.

## v1 Requirements

### Plugin (PLUG)

- [ ] **PLUG-01**: Plugin installs via `/plugin marketplace add <user>/devils-council && /plugin install devils-council@devils-council` from a public GitHub repo
- [ ] **PLUG-02**: Plugin uses namespaced commands (`/devils-council:review`, `/devils-council:dig`, `/devils-council:on-plan`, `/devils-council:on-code`) that do not collide with GSD or Superpowers
- [ ] **PLUG-03**: `claude plugin validate` passes on every commit
- [ ] **PLUG-04**: Plugin ships `.claude-plugin/plugin.json` manifest and `.claude-plugin/marketplace.json` single-repo marketplace descriptor
- [ ] **PLUG-05**: Plugin ships no `settings.json` top-level `agent` override and installs cleanly alongside GSD + Superpowers with no hook-matcher conflicts

### Persona Format (PFMT)

- [ ] **PFMT-01**: Personas are markdown files under `agents/` with YAML frontmatter (`name`, `description`, `tools`, `model`, `skills`, plus custom fields: `tier`, `triggers`, `primary_concern`, `blind_spots`, `characteristic_objections`, `banned_phrases`)
- [ ] **PFMT-02**: `skills/persona-voice/SKILL.md` defines tone rubric, value-system anchors, and worked examples used by every persona
- [ ] **PFMT-03**: `skills/scorecard-schema/SKILL.md` defines the canonical scorecard contract with required fields `target`, `claim`, `evidence` (verbatim artifact quote), `ask`, plus severity (`blocker | major | minor | nit`) and category
- [ ] **PFMT-04**: Per-persona banned-phrase list rejects vague verbs ("consider", "think about", "be aware of") structurally, not advisorily
- [ ] **PFMT-05**: Template `templates/SCORECARD.md` mirrors the schema and is used by every persona

### Core Personas (CORE)

- [ ] **CORE-01**: Staff Engineer (pragmatist) persona — simplicity/YAGNI primary concern, always-on tier
- [ ] **CORE-02**: SRE / On-call persona — operational reality primary concern, always-on tier
- [ ] **CORE-03**: Product Manager persona — business alignment primary concern, always-on tier
- [ ] **CORE-04**: Devil's Advocate persona — red-team / premise attack primary concern, always-on tier
- [ ] **CORE-05**: All four core personas have distinct value-system anchors, characteristic-objection lists, and banned-phrase lists; blinded-reader test confirms voice differentiation
- [ ] **CORE-06**: Order-swap test (swap the subagent spawn order) produces no change in persona output — verifies parallel isolation

### Review Engine (ENGN)

- [ ] **ENGN-01**: `/devils-council:review <artifact>` command accepts a file path, a plan reference, or stdin and produces a review run
- [ ] **ENGN-02**: Artifact type detector classifies input as `code-diff | plan | rfc` and snapshots it to `.council/<ts>-<slug>/INPUT.md`
- [ ] **ENGN-03**: Personas fan out in parallel via multiple `Task()` calls in a single turn; no persona sees another persona's draft
- [ ] **ENGN-04**: Each persona writes its scorecard to `.council/<ts>-<slug>/<persona>.md`; the directory is durable (not deleted after run)
- [ ] **ENGN-05**: Evidence validator rejects any finding lacking a verbatim quote from the artifact; rejected findings are reported with a structural error, not silently dropped
- [ ] **ENGN-06**: Artifact content is delivered inside explicit XML framing with a system directive marking it as data, not instructions (prompt-injection defense)
- [ ] **ENGN-07**: No refinement-loop code path exists — personas produce one scorecard each, no revision rounds
- [ ] **ENGN-08**: `.council/<ts>-<slug>/MANIFEST.json` records run metadata (artifact path, detected type, triggered personas + trigger reasons, budget usage)

### Council Chair (CHAIR)

- [ ] **CHAIR-01**: Council Chair subagent runs sequentially after all personas complete; reads all scorecards; writes `.council/<ts>-<slug>/SYNTHESIS.md`
- [ ] **CHAIR-02**: Chair output includes a mandatory `Contradictions` section that names personas by name ("PM says X, Security says Y") — never collapses or averages dissent
- [ ] **CHAIR-03**: Chair surfaces top-3 blocking concerns with persona attribution
- [ ] **CHAIR-04**: Chair emits no scalar verdict / no APPROVE-REJECT score (explicit anti-feature)
- [ ] **CHAIR-05**: Raw per-persona scorecards are always rendered alongside synthesis in command output
- [ ] **CHAIR-06**: Findings carry stable deterministic IDs (hash of persona + target + claim) so responses can reference them across runs

### Classifier + Bench Personas (BNCH)

- [ ] **BNCH-01**: `lib/classify.py` implements testable signal rules (structural: filename patterns, Python AST signatures for imports, Helm values keys, Chart.yaml presence, AWS SDK imports — not keyword matching). Phase 6 D-52 amendment.
- [ ] **BNCH-02**: Haiku-based classifier subagent handles ambiguous cases the deterministic rules cannot; classifier output is cached per run
- [ ] **BNCH-03**: Security Reviewer persona — triggers on auth code, crypto, secrets, input handling, dependency updates. MAY emit `delegation_request` for deep Codex scans; conductor fulfills via `codex exec --json --sandbox read-only` shell (skills/codex-deep-scan/SKILL.md). Phase 6 D-50 amendment.
- [ ] **BNCH-04**: FinOps Auditor persona — triggers on new cloud resources, autoscaling changes, storage class changes, batch-job patterns
- [ ] **BNCH-05**: Air-Gap Reviewer persona — triggers on network egress, external image pulls, license-phone-home, non-pinned dependencies
- [ ] **BNCH-06**: Dual-Deploy Reviewer persona — triggers on Helm values surface changes, KOTS config, SaaS-only assumptions, shared-infra coupling
- [ ] **BNCH-07**: `--only=<personas>` and `--exclude=<personas>` flags override auto-trigger selection
- [ ] **BNCH-08**: Trigger reasons surface in `MANIFEST.json` so users can see why a persona joined
- [ ] **BNCH-09**: Hard budget cap (default `$0.50` / `30s`, configurable) enforced pre-spawn — halts further bench fan-out when exceeded and reports which personas didn't run in `MANIFEST.personas_skipped[]`
- [ ] **BNCH-10**: Prompt caching on the artifact block produces observable token-usage reduction across the fan-out, measured in `MANIFEST.cache_summary.observable_reduction_pct`

### Codex Integration (CDEX)

- [ ] **CDEX-01**: Codex CLI installed, authenticated, and smoke-tested as part of Phase 1 delivery (non-interactive `codex exec --json --sandbox read-only` works end-to-end)
- [ ] **CDEX-02**: `skills/codex-deep-scan/SKILL.md` defines the delegation envelope: request shape, response normalization, failure handling
- [ ] **CDEX-03**: Personas (primarily Security, Dual-Deploy) can emit a `delegation_request` that the conductor fulfills by invoking Codex; result is reconciled into the persona's scorecard
- [ ] **CDEX-04**: Shell-primary via `codex exec --json --sandbox read-only`; MCP (`mcp__codex__spawn_agent`) deferred to v1.1. Phase 6 D-50 reaffirms Phase 1 D-12.
- [ ] **CDEX-05**: Codex delegation failures are fail-loud — the plugin surfaces "Codex unavailable, Security persona proceeded without deep scan" rather than silently degrading
- [ ] **CDEX-06**: README documents one-time `codex login` (OAuth) and `OPENAI_API_KEY` alternatives with troubleshooting

### Hardening (HARD)

- [ ] **HARD-01**: Prompt-injection test corpus covers `<!-- Ignore previous instructions -->`, role-confusion, tool-hijack payloads in each artifact type; CI runs the corpus
- [ ] **HARD-02**: Persona output that fails schema validation is dropped from synthesis with a structural error logged, not silently included
- [ ] **HARD-03**: Prompt caching on the artifact block is verified via observable token-usage reduction across fan-out
- [ ] **HARD-04**: Hard budget cap (default `$0.50` / `30s` per invocation, configurable) halts further bench-persona fan-out when exceeded and reports which personas didn't run
- [ ] **HARD-05**: Coexistence test matrix installs devils-council + GSD + Superpowers and verifies no command, hook, or MCP conflicts

### Response Workflow + Dig-In (RESP)

- [ ] **RESP-01**: `.council/responses.md` lets the user annotate findings as `accepted`, `dismissed` (with reason), or `deferred`; subsequent runs suppress dismissed findings unless the evidence changes
- [ ] **RESP-02**: `/devils-council:dig <persona> <run-id>` spawns an interactive follow-up session scoped to one persona's scorecard — enables drilling into rationale or asking for elaboration
- [ ] **RESP-03**: Finding IDs remain stable across re-runs of the same artifact so responses persist
- [ ] **RESP-04**: Severity-tiered output collapses nits by default; top-3 blockers surfaced inline

### GSD Integration (GSDI)

- [ ] **GSDI-01**: `/devils-council:on-plan <phase>` wrapper reads a GSD phase PLAN.md and routes it through `/devils-council:review`
- [ ] **GSDI-02**: `/devils-council:on-code <phase>` wrapper reads a GSD phase's committed diffs and routes them through `/devils-council:review`
- [ ] **GSDI-03**: `hooks/hooks.json` ships with GSD hook integration **disabled by default**; a single flag enables wrapping `gsd-plan-checker` and `gsd-code-reviewer` outputs
- [ ] **GSDI-04**: Plugin never installs hook matchers that fire when GSD is not present

### Docs + Release (DOCS)

- [ ] **DOCS-01**: README documents install, uninstall, quickstart, persona list, trigger rules, Codex setup, troubleshooting
- [ ] **DOCS-02**: CHANGELOG tracks v1.0.0 release notes
- [ ] **DOCS-03**: `scripts/validate-personas.sh` runs locally and in CI — validates persona frontmatter schema
- [ ] **DOCS-04**: CI runs `claude plugin validate` + persona validator + injection corpus + fixture-based quality tests on every push
- [ ] **DOCS-05**: v1.0.0 GitHub release tagged; marketplace install documented
- [ ] **DOCS-06**: Validation gate: Andy runs the plugin against 3-5 real artifacts from `anaconda-platform-chart` or `outerbounds-data-plane` and confirms output is non-generic and per-persona distinguishable before release

## v2 Requirements

### Extended Personas (XPER)

- **XPER-01**: Compliance / Legal persona — audit, licenses, air-gap, SOC2
- **XPER-02**: Junior Engineer / Newcomer persona — onboarding cost proxy
- **XPER-03**: Performance Engineer persona — latency, throughput, resource ceilings
- **XPER-04**: Test Lead persona — testability, flake risk, coverage adequacy
- **XPER-05**: Sales Engineer persona — demo-ability, deal-unblocking signal
- **XPER-06**: Executive Sponsor persona — strategic fit, opportunity cost
- **XPER-07**: Customer Success Engineer persona — real-customer failure modes
- **XPER-08**: Competing Team Lead persona — internal platform politics

### Memory + Learning (MEM)

- **MEM-01**: Chair remembers prior review rounds of the same artifact; surfaces "this was already raised in run X" context
- **MEM-02**: Persona-level learning from dismissed findings — the `dismissed` + reason signal tunes future triggers

### Custom Personas (CUST)

- **CUST-01**: `userConfig` supports a `custom_personas_dir` pointing outside the read-only plugin cache so users can author personas without forking
- **CUST-02**: Persona authoring guide + scaffolding command (`/devils-council:scaffold-persona`)

### Tool Integrations (TOOL)

- **TOOL-01**: Gemini CLI integration as an alternative deep-scan delegate
- **TOOL-02**: GSD hooks default-on after v1 proves out

## Out of Scope

| Feature | Reason |
|---------|--------|
| Single scalar verdict / APPROVE-REJECT score | Collapses dissent, defeats the product's core differentiator |
| Auto-merge / write access to PR state | Personas force thinking, not gate merges |
| Persona personality gimmicks (catchphrases, emojis, roasting) | Undermines credibility; caricature is a documented pitfall |
| ML-based persona selection | Opaque, unpredictable, unoverridable — explicit signal registry wins |
| Inter-persona debate / refinement rounds | Reintroduces consensus collapse; kills the differentiator |
| Running as a non-Claude-Code host (Codex CLI, Gemini CLI, OpenCode) | v1 targets Claude Code plugin only |
| Gemini CLI integration | Deferred to v2; `consulting-design-skill` already covers this path |
| GSD hooks default-on | Respect user opt-in until devils-council proves its value |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PLUG-01..05 | Phase 1 | Pending |
| CDEX-01, CDEX-02, CDEX-06 | Phase 1 | Pending |
| PFMT-01..05 | Phase 2 | Pending |
| ENGN-01..08 | Phase 3 | Pending |
| CORE-01 | Phase 3 | Pending |
| CORE-02..06 | Phase 4 | Pending |
| CHAIR-01..06 | Phase 5 | Pending |
| BNCH-01..08 | Phase 6 | Pending |
| BNCH-09..10 | Phase 6 | Pending |
| CDEX-03..05 | Phase 6 | Pending |
| HARD-01..05 | Phase 7 | Pending |
| RESP-01..04 | Phase 7 | Pending |
| GSDI-01..04 | Phase 8 | Pending |
| DOCS-01..06 | Phase 8 | Pending |

**Coverage:**
- v1 requirements: 67 total
- Mapped to phases: 67
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-22*
*Last updated: 2026-04-22 — RESP-01 path reconciled to .council/responses.md per Phase 1 D-07*
*Last updated: 2026-04-23 — Phase 6 amendments: BNCH-01 (py), BNCH-03 (shell-primary), CDEX-04 (shell-primary; MCP deferred to v1.1); BNCH-09 (budget cap) and BNCH-10 (prompt cache observable reduction) added.*
