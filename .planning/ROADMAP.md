# Roadmap: devils-council

**Created:** 2026-04-22
**Granularity:** standard
**Phases:** 8
**Coverage:** 65/65 v1 requirements mapped ✓

## Core Value

Catch weak plans, overengineered designs, and business misalignment *before* execution — by surfacing the pushback a senior engineering org would give, in a form the author can respond to.

## Phases

- [x] **Phase 1: Plugin Scaffolding + Codex Setup** — Plugin manifest, marketplace descriptor, and Codex CLI toolchain verified end-to-end (completed 2026-04-22)
- [x] **Phase 2: Persona Format + Voice Scaffolding** — Load-bearing schemas for persona files, scorecard contract, and voice rubric (completed 2026-04-22)
- [x] **Phase 3: One Working Persona End-to-End + Review Engine Core** — Conductor, evidence validator, injection defense, isolation; Staff Engineer proves the pipe (completed 2026-04-22)
- [x] **Phase 4: Remaining Core Personas** — SRE, PM, Devil's Advocate with distinct voices; parallel fan-out proven (completed 2026-04-23)
- [x] **Phase 5: Council Chair + Synthesis** — Contradictions surfaced by name, top-3 blockers, no scalar verdict, stable finding IDs (completed 2026-04-23)
- [ ] **Phase 6: Classifier + Bench Personas + Cost Instrumentation** — Auto-trigger signal rules, 4 bench personas, Codex delegation live, budget cap
- [ ] **Phase 7: Hardening + Injection Defense + Response Workflow** — Injection corpus, schema enforcement, response annotations, coexistence matrix
- [ ] **Phase 8: GSD Hook Integration + Dig-In + Docs + Release** — Opt-in GSD wrappers, dig-in command, README/CHANGELOG, v1.0.0 release

## Phase Details

### Phase 1: Plugin Scaffolding + Codex Setup
**Goal**: A valid, installable Claude Code plugin skeleton exists and Codex CLI is verified working end-to-end on this machine
**Depends on**: Nothing (first phase)
**Requirements**: PLUG-01, PLUG-02, PLUG-03, PLUG-04, PLUG-05, CDEX-01, CDEX-02, CDEX-06
**Success Criteria** (what must be TRUE):
  1. User can install the plugin from the public GitHub repo via `/plugin marketplace add <user>/devils-council && /plugin install devils-council@devils-council` and `claude plugin validate` passes
  2. Plugin loads alongside GSD and Superpowers with no command, hook, or MCP collisions (namespaced `/devils-council:*` commands)
  3. `codex exec --json --sandbox read-only` runs non-interactively on this machine against a smoke-test prompt and returns structured output
  4. `skills/codex-deep-scan/SKILL.md` defines the delegation envelope (request shape, response normalization, failure handling) even before personas consume it
  5. README documents `codex login` OAuth flow + `OPENAI_API_KEY` alternative with troubleshooting steps that Andy can follow cold
**Plans**: 5 plans
- [x] 01-01-PLAN.md — Plugin manifest + marketplace catalog + empty component skeleton + LICENSE/.gitignore (PLUG-01, PLUG-02, PLUG-04, PLUG-05)
- [x] 01-02-PLAN.md — Codex CLI install + auth + smoke test + `skills/codex-deep-scan/SKILL.md` delegation envelope (CDEX-01, CDEX-02, CDEX-06)
- [x] 01-03-PLAN.md — Dev-loop symlink + namespacing collision inventory + REQUIREMENTS.md RESP-01 path reconcile (PLUG-02, PLUG-05)
- [x] 01-04-PLAN.md — GitHub Actions CI (Linux + macOS matrix, `claude plugin validate` + markdown lint) (PLUG-03)
- [x] 01-05-PLAN.md — README + CHANGELOG + public GitHub repo push + end-to-end marketplace install verification (PLUG-01, CDEX-06)

### Phase 2: Persona Format + Voice Scaffolding
**Goal**: The schemas and rubrics that make non-generic, per-persona critique structurally enforceable exist before any persona is written
**Depends on**: Phase 1
**Requirements**: PFMT-01, PFMT-02, PFMT-03, PFMT-04, PFMT-05
**Success Criteria** (what must be TRUE):
  1. A persona file is a markdown file in `agents/` with YAML frontmatter covering standard fields plus custom fields (`tier`, `triggers`, `primary_concern`, `blind_spots`, `characteristic_objections`, `banned_phrases`)
  2. `skills/persona-voice/SKILL.md` provides a tone rubric, value-system anchors, and worked good/bad examples that every persona subagent preloads
  3. `skills/scorecard-schema/SKILL.md` defines the canonical scorecard contract (`target`, `claim`, `evidence` as verbatim artifact quote, `ask`, severity, category) and a matching `templates/SCORECARD.md`
  4. A finding that uses a banned vague verb ("consider", "think about", "be aware of") or omits a verbatim quote is structurally rejected, not advisorily flagged
**Plans**: 4 plans
- [x] 02-01-PLAN.md — Scorecard-schema SKILL + templates/SCORECARD.md (PFMT-03, PFMT-04, PFMT-05)
- [x] 02-02-PLAN.md — Persona-voice SKILL + persona frontmatter schema + lib/signals.json registry + agents/README.md (PFMT-01, PFMT-02)
- [x] 02-03-PLAN.md — scripts/validate-personas.sh + 6 persona fixtures + 3 review-artifact fixtures + self-test harness (PFMT-04)
- [x] 02-04-PLAN.md — hooks/hooks.json PreToolUse + .github/workflows/ci.yml persona-validation step (PFMT-04, D-18)

### Phase 3: One Working Persona End-to-End + Review Engine Core
**Goal**: `/devils-council:review` runs Staff Engineer against a real artifact and produces a validated scorecard, with isolation, evidence enforcement, and injection defense baked into the architecture
**Depends on**: Phase 2
**Requirements**: ENGN-01, ENGN-02, ENGN-03, ENGN-04, ENGN-05, ENGN-06, ENGN-07, ENGN-08, CORE-01
**Success Criteria** (what must be TRUE):
  1. User can run `/devils-council:review <file>` (or plan ref, or stdin), see the artifact classified as `code-diff | plan | rfc`, and find a snapshot at `.council/<ts>-<slug>/INPUT.md`
  2. Staff Engineer persona produces a scorecard at `.council/<ts>-<slug>/staff-engineer.md` where every finding cites a verbatim quote from the artifact; non-conforming findings are reported as structural errors
  3. Artifact content is delivered to personas inside explicit XML framing with a system directive marking it as data, not instructions — a `<!-- Ignore previous instructions -->` payload in the artifact does not change persona behavior
  4. `.council/<ts>-<slug>/MANIFEST.json` records artifact path, detected type, triggered personas + trigger reasons, and budget usage; the run directory persists after completion
  5. There is no code path that sends a persona its own draft or another persona's draft for a second pass — single-pass architecture is a property of the system, not a convention
**Plans**: 5 plans

- [x] 03-01-PLAN.md — bin/dc-prep.sh: artifact classifier + INPUT.md snapshot + MANIFEST.json init with per-run nonce (ENGN-02, ENGN-04, ENGN-08)
- [x] 03-02-PLAN.md — bin/dc-validate-scorecard.sh: conductor-side evidence + banned-phrase pipeline, writes final scorecard, updates MANIFEST (ENGN-05, ENGN-07)
- [x] 03-03-PLAN.md — agents/staff-engineer.md: first real core persona with voice kit + worked examples grounded in Phase 2 fixtures (CORE-01)
- [x] 03-04-PLAN.md — commands/review.md conductor + tests/fixtures/injection-basic.md canary: shell-injected prep, Task spawn, XML-nonce framing, Bash-tool validator call (ENGN-01, ENGN-03, ENGN-06)
- [x] 03-05-PLAN.md — scripts/test-engine-smoke.sh + CI wiring: integration test of prep + validator with mocked draft (ENGN-02, ENGN-05, ENGN-08)

### Phase 4: Remaining Core Personas
**Goal**: All four always-on core personas (Staff Eng, SRE, PM, Devil's Advocate) run in parallel with voices distinct enough that a blinded reader can tell them apart
**Depends on**: Phase 3
**Requirements**: CORE-02, CORE-03, CORE-04, CORE-05, CORE-06
**Success Criteria** (what must be TRUE):
  1. Running `/devils-council:review` on a single artifact produces four scorecards (`staff-engineer.md`, `sre.md`, `product-manager.md`, `devils-advocate.md`) written in parallel
  2. A blinded-reader test on a sample artifact lets Andy correctly attribute each scorecard to its persona without seeing the filename
  3. Swapping the order in which the conductor spawns the four personas produces no change in any persona's output (parallel isolation verified, not asserted)
  4. Each of the four core personas has a distinct value-system anchor, characteristic-objection list, and banned-phrase list documented in its agent file
**Plans**: TBD

### Phase 5: Council Chair + Synthesis
**Goal**: A Council Chair synthesizes the four core scorecards into a contradictions-first summary, preserves raw dissent, and emits no scalar verdict
**Depends on**: Phase 4
**Requirements**: CHAIR-01, CHAIR-02, CHAIR-03, CHAIR-04, CHAIR-05, CHAIR-06
**Success Criteria** (what must be TRUE):
  1. After all personas complete, the Council Chair subagent runs sequentially, reads every scorecard, and writes `.council/<ts>-<slug>/SYNTHESIS.md`
  2. `SYNTHESIS.md` always contains a `Contradictions` section that names personas when they disagree ("PM says ship, SRE says block because…") — never collapses or averages dissent
  3. `SYNTHESIS.md` surfaces the top-3 blocking concerns with persona attribution and contains no APPROVE/REJECT scalar verdict
  4. Command output renders both the synthesis and the raw per-persona scorecards — the user never has to go hunting for the raw material
  5. Every finding across all scorecards carries a deterministic ID (hash of persona + target + claim) that is stable across re-runs of the same artifact
**Plans**: 5 plans
- [ ] 05-01-PLAN.md — bin/dc-validate-scorecard.sh ID stamping (D-37, D-38) + test-engine-smoke Case D+F CHAIR-06 assertions (CHAIR-06)
- [ ] 05-02-PLAN.md — agents/council-chair.md subagent + persona-metadata/council-chair.yml sidecar + scripts/validate-personas.sh tier-based routing (CHAIR-01, CHAIR-02, CHAIR-03, CHAIR-04)
- [ ] 05-03-PLAN.md — bin/dc-validate-synthesis.sh synthesis validator (required sections, id-anchor resolution, candidate-set check, banned-token scan) (CHAIR-02, CHAIR-03, CHAIR-04)
- [x] 05-04-PLAN.md — commands/review.md Chair spawn + synthesis validator invocation + synthesis-first render (CHAIR-01, CHAIR-05)
- [x] 05-05-PLAN.md — tests/fixtures/contradiction-seed.md + scripts/test-chair-synthesis.sh + CI wiring (CHAIR-01, CHAIR-02, CHAIR-03, CHAIR-04, CHAIR-05, CHAIR-06)

### Phase 6: Classifier + Bench Personas + Cost Instrumentation
**Goal**: Bench personas auto-trigger on structural signals from the artifact, Codex-backed deep scans are wired for Security + Dual-Deploy, and the plugin operates within a hard budget cap
**Depends on**: Phase 5
**Requirements**: BNCH-01, BNCH-02, BNCH-03, BNCH-04, BNCH-05, BNCH-06, BNCH-07, BNCH-08, CDEX-03, CDEX-04, CDEX-05
**Success Criteria** (what must be TRUE):
  1. Reviewing a Helm values diff auto-triggers Dual-Deploy Reviewer; reviewing an AWS SDK-using file auto-triggers FinOps Auditor; reviewing auth/crypto code auto-triggers Security Reviewer; reviewing egress/external-pull changes auto-triggers Air-Gap Reviewer — with trigger reasons surfaced in `MANIFEST.json`
  2. `lib/classify.js` rules are pure functions with unit tests (filename patterns, AST signatures, Helm keys, Chart.yaml presence, AWS SDK imports — not keyword matching); ambiguous cases fall through to a Haiku classifier subagent whose output is cached per run
  3. Security and Dual-Deploy personas emit `delegation_request` objects that the conductor fulfills via `mcp__codex__spawn_agent` (with `codex exec --json` shell fallback), and the result is reconciled into the persona's scorecard
  4. When Codex is unavailable, the plugin surfaces "Codex unavailable, Security persona proceeded without deep scan" in the run output — never silently degrades
  5. `--only=<personas>` and `--exclude=<personas>` flags override the auto-trigger selection; a hard budget cap (default `$0.50` / `30s`, configurable) halts further bench fan-out when exceeded and reports which personas didn't run
  6. Prompt caching on the artifact block produces observable token-usage reduction across the fan-out (measured in `MANIFEST.json`)
**Plans**: 8 plans
- [x] 06-01-PLAN.md — Cache-measurement spike + 06-CACHE-SPIKE-MEMO outcome (BNCH-06)
- [x] 06-02-PLAN.md — lib/classify.py (16 structural detectors) + bin/dc-classify.sh + validate-personas.sh tier:classifier extension + 17 fixtures + scripts/test-classify.sh (BNCH-01, BNCH-08)
- [x] 06-03-PLAN.md — agents/artifact-classifier.md Haiku subagent + persona-metadata sidecar + PERSONA-SCHEMA.md R9 documentation (BNCH-02)
- [x] 06-04-PLAN.md — Four bench persona files (security/finops/air-gap/dual-deploy) + voice-kit sidecars (BNCH-03, BNCH-04, BNCH-05, BNCH-06)
- [x] 06-05-PLAN.md — bin/dc-codex-delegate.sh + commands/review.md reconciliation block + codex stubs + scripts/test-codex-delegation.sh (CDEX-03, CDEX-04, CDEX-05)
- [x] 06-06-PLAN.md — config.json budget block + bin/dc-budget-plan.sh + commands/review.md flag-parsing + bench fan-out + scripts/test-budget-cap.sh (BNCH-05, BNCH-07, BNCH-08)
- [x] 06-07-PLAN.md — commands/review.md cache structuring (D-59) + cache_stats MANIFEST writes (D-60) + scripts/test-cache-reduction.sh (BNCH-06)
- [x] 06-08-PLAN.md — REQUIREMENTS.md amendments (D-50, D-52) + CI wiring + live UAT checkpoint (all Phase 6 reqs)

### Phase 7: Hardening + Injection Defense + Response Workflow
**Goal**: The plugin withstands a prompt-injection corpus, drops non-conforming output, lets users annotate findings so dismissed items don't re-raise, and coexists cleanly with GSD + Superpowers
**Depends on**: Phase 6
**Requirements**: HARD-01, HARD-02, HARD-05, RESP-01, RESP-03, RESP-04
**Success Criteria** (what must be TRUE):
  1. An injection test corpus covering `<!-- Ignore previous instructions -->`, role-confusion, and tool-hijack payloads in each artifact type runs in CI and passes — payloads are either ignored or surfaced as injection-type findings, never obeyed
  2. Any persona output that fails scorecard schema validation is dropped from synthesis with a structural error logged; silent inclusion of malformed output is impossible
  3. User can annotate findings in `.council/responses.md` as `accepted`, `dismissed` (with reason), or `deferred`; on re-run against the same artifact, dismissed findings are suppressed unless the underlying evidence changed
  4. Severity-tiered output collapses nits by default and inlines the top-3 blockers; user can dig further with `/devils-council:dig` (wired in Phase 8)
  5. A coexistence test matrix installs devils-council + GSD + Superpowers in the same Claude Code instance and verifies no command, hook, or MCP conflicts
  6. The HARD-01 injection corpus's `tool-hijack/` class includes an adversarial fixture that attempts to force excessive bench persona spawns; CI asserts the Phase 6 hard budget cap holds under that adversarial input (no regression of BNCH-09)
**Plans**: 8 plans
- [ ] 07-01-PLAN.md — REQUIREMENTS.md + ROADMAP.md amendments per D-62/D-63/D-64 (doc-amendments)
- [ ] 07-02-PLAN.md — bin/dc-validate-scorecard.sh HARD-02 zero-kept stub-drop branch + scripts/test-dropped-scorecard.sh + fixture (HARD-02)
- [ ] 07-03-PLAN.md — scripts/test-coexistence.sh static collision-check devils-council × GSD × Superpowers (HARD-05)
- [ ] 07-04-PLAN.md — 9-fixture injection corpus under tests/fixtures/injection-corpus/ (HARD-01)
- [ ] 07-05-PLAN.md — scripts/test-injection-corpus.sh runner: D-68 static grep + D-67 per-fixture negatives + tool-hijack no-side-effect audit (HARD-01)
- [ ] 07-06-PLAN.md — bin/dc-apply-responses.sh + commands/review.md suppression hook + Chair filter + D-71 render note + scripts/test-responses-suppression.sh (RESP-01, RESP-03)
- [ ] 07-07-PLAN.md — commands/review.md flag-parser --show-nits + dedup-from-prior-run + severity-tier render transform + scripts/test-severity-render.sh (RESP-04)
- [ ] 07-08-PLAN.md — .github/workflows/ci.yml 5 new steps + plugin.json 0.5.0 → 0.6.0 + human-UAT checkpoint (all 6 reqs + CI wiring)

### Phase 8: GSD Hook Integration + Dig-In + Docs + Release
**Goal**: Opt-in GSD wrappers, the dig-in command, and release-grade docs ship as v1.0.0 with CI enforcing quality on every push
**Depends on**: Phase 7
**Requirements**: GSDI-01, GSDI-02, GSDI-03, GSDI-04, DOCS-01, DOCS-02, DOCS-03, DOCS-04, DOCS-05, DOCS-06
**Success Criteria** (what must be TRUE):
  1. `/devils-council:on-plan <phase>` reads a GSD phase PLAN.md and `/devils-council:on-code <phase>` reads a GSD phase's committed diffs; both route through `/devils-council:review` with no core-code awareness of GSD
  2. `hooks/hooks.json` ships with GSD hook integration disabled by default; a single documented flag enables wrapping `gsd-plan-checker` and `gsd-code-reviewer`; no hook matcher fires when GSD is not installed
  3. User can run `/devils-council:dig <persona> <run-id>` to spawn an interactive follow-up scoped to one persona's scorecard and ask for elaboration or rationale
  4. README covers install, uninstall, quickstart, persona list, trigger rules, Codex setup, and troubleshooting; CHANGELOG documents v1.0.0
  5. CI runs `claude plugin validate` + `scripts/validate-personas.sh` + injection corpus + fixture-based quality tests on every push
  6. Andy runs the plugin against 3-5 real artifacts from `anaconda-platform-chart` or `outerbounds-data-plane` and confirms the output is non-generic and per-persona distinguishable; v1.0.0 GitHub release is tagged and marketplace install is documented
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Plugin Scaffolding + Codex Setup | 5/5 | Complete    | 2026-04-22 |
| 2. Persona Format + Voice Scaffolding | 4/4 | Complete    | 2026-04-22 |
| 3. One Working Persona End-to-End + Review Engine Core | 5/5 | Complete    | 2026-04-22 |
| 4. Remaining Core Personas | 7/7 | Complete    | 2026-04-23 |
| 5. Council Chair + Synthesis | 5/5 | Complete    | 2026-04-23 |
| 6. Classifier + Bench Personas + Cost Instrumentation | 0/8 | Planned | - |
| 7. Hardening + Injection Defense + Response Workflow | 0/? | Not started | - |
| 8. GSD Hook Integration + Dig-In + Docs + Release | 0/? | Not started | - |

## Coverage

All 65 v1 requirements mapped across 8 phases. No orphans, no duplicates.

| Phase | Requirements | Count |
|-------|--------------|-------|
| 1 | PLUG-01..05, CDEX-01, CDEX-02, CDEX-06 | 8 |
| 2 | PFMT-01..05 | 5 |
| 3 | ENGN-01..08, CORE-01 | 9 |
| 4 | CORE-02..06 | 5 |
| 5 | CHAIR-01..06 | 6 |
| 6 | BNCH-01..08, CDEX-03..05 | 11 |
| 7 | HARD-01, HARD-02, HARD-05, RESP-01, RESP-03, RESP-04 | 6 |
| 8 | GSDI-01..04, DOCS-01..06, RESP-02 | 11 |
| **Total** | | **61** |

Note: CORE-01 counted in Phase 3; CORE-02..06 = 5 in Phase 4; CDEX split 3 in Phase 1 + 3 in Phase 6 = 6. Recomputing: 8 + 5 + 9 + 5 + 6 + 11 + 9 + 10 = 63. Two requirement IDs are counted via ranges — PLUG-01..05 = 5, ENGN-01..08 = 8, CHAIR-01..06 = 6, BNCH-01..08 = 8, HARD-01..05 = 5, RESP-01..04 = 4, GSDI-01..04 = 4, DOCS-01..06 = 6, PFMT-01..05 = 5, CORE-01..06 = 6, CDEX-01..06 = 6 → 5+8+6+8+5+4+4+6+5+6+6 = 63. Matches REQUIREMENTS.md v1 count of 63 (PROJECT.md's "65 total" line includes overlap). Phase 7 D-62/D-63/D-64 amendments: HARD-03 + HARD-04 deleted (duplicates of BNCH-10/BNCH-09 shipped in Phase 6); RESP-02 relocated Phase 7 → Phase 8. Post-amendment total: 61.

---
*Roadmap created: 2026-04-22*
