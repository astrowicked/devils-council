# Phase 2: Codex `--output-schema` Spike - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Produce a measured GO/NO-GO/WRAPPER memo on whether Codex CLI's `--output-schema` flag is production-ready for Security persona deep scans in devils-council. Negative result is a valid outcome — the spike either unlocks Phase 6 rollout or closes it with documented reasons. No production code changes in Phase 2; the only deliverables are a memo + raw run log + schema file + any minimal spike-harness scripts.

**In scope:**
- `.planning/research/CODEX-SCHEMA-MEMO.md` with pinned `codex --version`, verdict, aggregated results
- `templates/codex-security-schema.json` v1 Security scorecard schema (mirrors v1.0 scorecard contract)
- `.planning/research/codex-schema-spike-runs.jsonl` per-delegation raw data
- Spike harness script (invokes Codex with/without `--output-schema` over the 7-item corpus)
- Rubric for Phase 6 wiring (only if verdict = GO or WRAPPER)

**Out of scope:**
- Any changes to `bin/dc-codex-delegate.sh` (Phase 6 owns that if GO/WRAPPER)
- Any changes to `agents/security-reviewer.md` (Phase 6 scope)
- Feature-detect fallback logic (Phase 6 scope)
- `codex_schema_validation_error` MANIFEST.json enum extension (Phase 6, CODX-04)

**Parallelizable with Phase 1** — no code dependencies. This phase ran in parallel or after Phase 1 at user's discretion.

</domain>

<decisions>
## Implementation Decisions

### Delegation corpus

- **D-01:** Corpus = **B-hybrid** = 7 items total:
  - 3 existing v1.0 `tests/fixtures/codex-delegation/*` fixtures (production-representative baseline)
  - 2 real artifacts from `anaconda-platform-chart` repo:
    - One auth middleware change (e.g., session token handling diff)
    - One Helm values change with secrets/credentials context
  - 2 adversarial stress cases:
    - Deeply nested JSON request (tests depth limits — STACK.md §Q1 MEDIUM-confidence area)
    - Union-type schema case: `oneOf: [string, object]` for `evidence` field (tests union handling — STACK.md flagged as undocumented)
- **D-02:** Exceeds ROADMAP success criterion floor of 5+ delegations. Gives spike statistical coverage for Phase 6 rollout confidence while catching the exact features STACK.md flagged as MEDIUM-confidence (unions, depth).

### Schema shape

- **D-03:** Schema = **mirror v1.0 scorecard contract verbatim** from `skills/scorecard-schema/SKILL.md`.
  Shape:
  ```json
  {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "properties": {
      "findings": {
        "type": "array",
        "items": {
          "type": "object",
          "required": ["target", "claim", "evidence", "ask", "severity", "category"],
          "properties": {
            "target": {"type": "string"},
            "claim": {"type": "string"},
            "evidence": {"type": "string"},
            "ask": {"type": "string"},
            "severity": {"enum": ["blocker", "major", "minor", "nit"]},
            "category": {"type": "string"}
          },
          "additionalProperties": false
        }
      }
    },
    "required": ["findings"],
    "additionalProperties": false
  }
  ```
- **D-04:** NOT extending schema with `finding_id` hash or nested `evidence_location` (Option C rejected). Finding-ID stamping is done outside the scorecard by `bin/dc-validate-scorecard.sh` in v1.0 and that contract is unchanged. Adding it to the schema prematurely bakes v1.1 scope into a spike that should measure today's production shape.
- **D-05:** Schema file lives at `templates/codex-security-schema.json` (matches plugin convention for templates).

### Baseline latency measurement

- **D-06:** Measure **both baselines** (Option C):
  - **Wrapped baseline:** `bin/dc-codex-delegate.sh` as-is (no `--output-schema`) — what users actually experience today
  - **Stripped baseline:** `codex exec --json --sandbox read-only --skip-git-repo-check` direct invocation — isolates Codex-side cost
- **D-07:** Each corpus item runs 2x without schema (both baselines) + 1x with schema = 3 invocations × 7 corpus items = **21 total Codex invocations** for the spike.
- **D-08:** Measurement unit: wall-clock ms per invocation, captured via `date +%s%3N` before/after.
- **D-09:** Latency delta = `with_schema_ms / wrapped_baseline_ms`. The verdict rubric applies to this ratio (see ROADMAP success criteria: <25% = GO, >2x = NO-GO, otherwise WRAPPER).
- **D-10:** Separating baselines means: if `schema_overhead` is acceptable but `wrapper_overhead` is dominant, the verdict is GO (not NO-GO) and the wrapper cost becomes a Phase 6 optimization ticket, not a Phase 2 blocker.

### Measurement retention

- **D-11:** Raw per-run data to `.planning/research/codex-schema-spike-runs.jsonl` — one JSON object per line, each with:
  - `run_id` (monotonic counter)
  - `corpus_item` (file path or descriptor)
  - `mode` (`wrapped_no_schema` | `stripped_no_schema` | `with_schema`)
  - `request_prompt` (truncated to 500 chars if longer)
  - `response_raw` (full Codex output, incl. non-JSON prelude if any)
  - `response_parsed` (parsed object or null if parse failed)
  - `schema_valid` (bool; only for `with_schema` mode)
  - `schema_validation_errors` (array of error messages if schema_valid = false)
  - `wall_clock_ms` (int)
  - `timestamp_iso`
  - `codex_version` (pinned `codex --version` output)
- **D-12:** JSONL not committed (it's under gitignored `.planning/` per `commit_docs: false`). Stays local source-of-truth; cited in memo by aggregation.
- **D-13:** Memo aggregates JSONL into tables: parse-rate per mode, schema-validation rate, latency percentiles (p50/p95/p99) per mode, per-item pass/fail. Verdict section is concise (3 sentences max) with rubric citation.

### Verdict rubric (from ROADMAP success criteria, not re-decided)

- **GO**: schema-validation rate >95% AND schema-vs-wrapped-baseline latency <125%
- **NO-GO**: schema-validation rate <80% OR schema-vs-wrapped-baseline latency >200%
- **WRAPPER**: between — adopt schema + add `jsonschema` post-validation in `dc-codex-delegate.sh` (Phase 6 would implement)

### Claude's Discretion

- Exact prompt wording for each corpus item (may need Security-persona-style framing to match real delegation shape)
- Exact file path for adversarial corpus items under `tests/fixtures/codex-schema-spike/` (or a `.planning/research/spike-fixtures/` sibling)
- Whether to include error-handling corpus items (e.g., Codex timeout, malformed request) — executor's call based on whether it emerges as interesting during the first 3-5 runs
- Exact spike harness script name/location — suggest `scripts/test-codex-schema-spike.sh`
- Exact JSONL schema (additional debug fields beyond the 12 in D-11 are fine if useful)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1.1 milestone context
- `.planning/REQUIREMENTS.md` §CODX — CODX-01 through CODX-04
- `.planning/ROADMAP.md` §Phase 2 — 4 success criteria, verdict rubric
- `.planning/research/STACK.md` §Q1 — **primary source** — flag presence confirmed in `codex-cli 0.122.0`, undocumented semantics around JSON Schema draft version, retry/repair, `anyOf`/`oneOf` support, max depth — these ARE the adversarial corpus targets per D-01
- `.planning/research/SUMMARY.md` §Codex Schema Spike — spike-first verdict confirmed

### v1.0 code surfaces referenced (not modified)
- `bin/dc-codex-delegate.sh` — baseline wrapper (D-06); Phase 2 invokes as-is, Phase 6 would extend
- `skills/scorecard-schema/SKILL.md` — authoritative scorecard contract (D-03 mirrors this)
- `tests/fixtures/codex-delegation/*` — source for 3 corpus items (D-01)
- `agents/security-reviewer.md` — consumer of Codex output (context only; not modified)
- `scripts/test-codex-delegation.sh` — existing Codex integration test (reference pattern for new spike harness)

### External refs
- Codex CLI docs: https://developers.openai.com/codex/noninteractive — `--output-schema`, `--json`, `--sandbox`, `--ephemeral` flags
- JSON Schema draft 2020-12 spec: https://json-schema.org/draft/2020-12/schema (D-03 schema declares conformance)
- `codex --version` (measured at spike time; pin exact version string in memo)

### Where NOT to look
- `bin/dc-validate-scorecard.sh` — not touched in Phase 2. Post-validation lives here if verdict = WRAPPER in Phase 6.
- v1.0 archive `.planning/milestones/v1.0-phases/**` — irrelevant to Phase 2 (no TD items in this phase)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`bin/dc-codex-delegate.sh`** — invokes `codex exec --json --sandbox read-only --skip-git-repo-check`. Spike runs it unchanged for wrapped baseline (D-06). Writes output to `/tmp/codex-<pid>.json`.
- **`tests/fixtures/codex-delegation/*`** — existing Codex test fixtures (v1.0 Phase 6). Three are representative enough to reuse as corpus items 1-3 (D-01).
- **`scripts/test-codex-delegation.sh`** — reference pattern for spike harness shape (Bash runner invoking `bin/dc-codex-delegate.sh` across fixtures, asserting output). Spike harness mirrors this but adds `--output-schema` variants.
- **`skills/codex-deep-scan/SKILL.md`** — documents the delegation envelope (request shape, response normalization, failure handling). Schema in D-03 mirrors what this skill already formalizes.

### Established Patterns

- **JSONL for measurement** — matches MANIFEST.json `cache_stats` discipline from v1.0 Phase 6 (measurable, appendable, grep-friendly)
- **Spike-first before rollout** — v1.0 Phase 6 did the same for cache structuring (06-CACHE-SPIKE-MEMO): spike → memo → go/no-go → rollout in subsequent plan. Phase 2 follows this pattern exactly.
- **Memos live under `.planning/research/`** — `06-CACHE-SPIKE-MEMO.md` established this location for phase-level spikes. Phase 2 uses the same dir.

### Integration Points

- Phase 2 output feeds Phase 6 directly:
  - If GO/WRAPPER: Phase 6 reads CODEX-SCHEMA-MEMO.md's Phase 6 Wiring Rubric section, ships `lib/codex-schemas/security.json`, extends `bin/dc-codex-delegate.sh`
  - If NO-GO: Phase 6 is no-op; memo's NO-GO documentation lives in CHANGELOG as "`--output-schema` evaluated in Phase 2, not adopted — see memo for reasons"
- No runtime integration with any other phase. Phase 3/4/5 operate independently of Phase 2 outcome.

</code_context>

<specifics>
## Specific Ideas

- **Adversarial items are load-bearing.** D-01 items 6-7 stress-test exactly the features STACK.md §Q1 flagged as MEDIUM-confidence (depth, unions). If these fail, the verdict is NO-GO regardless of how the other 5 items perform — because the NO-GO decision is primarily about "can we trust Codex to fill real v1.0 scorecard shapes in production?" and unions in `evidence` field WILL appear in production (sometimes evidence is a quote, sometimes a structured location reference).

- **Three-mode measurement is cheap.** 21 Codex invocations at ~3-10s each = 60-210 seconds total spike runtime. Memo-writing dominates. Don't sweat the Codex API cost; this is a one-shot measurement.

- **Write the schema first, corpus second, memo last.** Phase 2 plan order should be:
  1. Write `templates/codex-security-schema.json` per D-03
  2. Assemble 7-item corpus per D-01 (may need to pull real diffs from `~/dev/anaconda-platform-chart` if available; fall back to synthetic if not)
  3. Build spike harness script
  4. Run 21-invocation spike, populate JSONL
  5. Analyze, write memo with verdict

- **Memo verdict paragraph should be 3 sentences max.** The rubric is binary; we don't need 5 pages of analysis. The value is in the per-item JSONL + aggregated tables, not in prose.

- **If anaconda-platform-chart is not accessible** (Andy may not have it in $HOME/dev right now), substitute with synthesis from `.planning/research/FEATURES.md` Security Reviewer section for the 2 real-world items. Document substitution in memo.

</specifics>

<deferred>
## Deferred Ideas

- **`finding_id` hash in schema** (Option C from Q2): deferred to v1.2 if Phase 6 surfaces a need. v1.0 ID stamping outside scorecard contract works fine.
- **Full artifact retention** (Option C from Q4 — one file per Codex response): rejected; JSONL is sufficient fidelity for 21 runs.
- **Minimal synthetic corpus** (Option A from Q1): rejected; would produce a verdict we don't trust.
- **Feature-detect fallback wiring** (CODX-03): explicitly Phase 6 scope. Phase 2's rubric tells Phase 6 *whether* to wire it; Phase 6 does the wiring.
- **`codex_schema_validation_error` MANIFEST.json enum** (CODX-04): Phase 6 scope. Phase 2 memo notes the error class as a rubric deliverable but does not implement.
- **Schema-enforced path rollout in dc-codex-delegate.sh** (CODX-02): Phase 6 scope.

</deferred>

---

*Phase: 02-codex-output-schema-spike*
*Context gathered: 2026-04-25*
