# Phase 3: Classifier Extension - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend `lib/classify.py` + `lib/signals.json` + `config.json` + `agents/artifact-classifier.md` to support 5 new signal detectors with `signal_strength` tiering, `artifact_type` pipeline propagation, and bench priority order — before Phase 4 commits persona sidecars that reference these signals (PreToolUse validator R7 blocks sidecars referencing undefined signals).

**In scope:** CLS-01..CLS-06 (5 new detectors + signal_strength + artifact_type + priority_order + negative fixtures + Haiku whitelist expansion).

**Out of scope:**
- Writing the 6 new persona sidecars (Phase 4)
- Writing adversarial Executive Sponsor CI fixture (Phase 4 PQUAL-02)
- Voice-distinctness validator (Phase 4 PQUAL-01)
- Scaffolder skill (Phase 5)
- Any Codex schema wiring (Phase 6, WRAPPER verdict from Phase 2)

**Depends on:** Phase 1 — specifically TD-04 (shell-inject hook must be safe-wired before new fixture files land in the repo) and TD-06 (agents/AUTHORING.md rename must be done before Phase 4 sidecars reference signals.json keys, which they will do via Phase 3's new entries). Phase 1 complete at commit `57ed4fd`.

</domain>

<decisions>
## Implementation Decisions

### Haiku classifier whitelist scope (CLS-06)

- **D-01:** Whitelist = **8 bench slugs** (matches ROADMAP SC-4 verbatim). Executive Sponsor excluded from Haiku whitelist.
  - Included (8): `security-reviewer, finops-auditor, air-gap-reviewer, dual-deploy-reviewer, compliance-reviewer, performance-reviewer, test-lead, competing-team-lead`
  - Excluded: `executive-sponsor` (its `artifact_type` gate already limits it to `plan|rfc|design`; Haiku whitelist fires on zero-structural-match artifacts, so exec-sponsor would never be validly triggered by Haiku on a code-diff anyway). Also mitigates P-11 Executive Sponsor register-drift risk by keeping it signal-driven-only.
  - Excluded: `junior-engineer` (bench always-invokable on code-diff; not signal-driven, not routed through Haiku fallback path)

### Signal strength mechanics (CLS-02)

- **D-02:** `signal_strength` enum values: `strong | moderate | weak`. Added as a new top-level field per signal entry in `lib/signals.json`.
- **D-03:** Weak-signal gating = **`min_evidence` field per signal** (not a cross-detector hit-count rule).
  - Each signal entry in `lib/signals.json` gets a new `min_evidence: <int>` field.
  - Strong signals default to `min_evidence: 1`.
  - Moderate signals use `min_evidence: 2` by default (configurable per signal).
  - Weak signals require `min_evidence: 2` or higher.
  - Classifier logic: a signal triggers if and only if `len(evidence_list) >= min_evidence`.
  - v1.0 signals (which have no `signal_strength` or `min_evidence` fields) default to `strong` + `min_evidence: 1` for backward compatibility.

### Signal strength assignments (CLS-01 scope)

- **D-04:** Default strength + min_evidence per new signal (planner starting point; executor may tune during negative-fixture testing if a strong signal false-positives):

| Signal | Strength | min_evidence | Rationale |
|---|---|---|---|
| `compliance_marker` | moderate | 2 | Specific citations (GDPR Art. 5, HIPAA §164.312) are strong individually but single-keyword matches ("data retention") can false-positive in benign prose |
| `performance_hotpath` | moderate | 2 | Pattern matches (N+1, loop-over-collection) are diagnostic but noisy; require at least 2 signal hits |
| `test_imbalance` | strong | 1 | Src-without-test or test-without-src is a file-set operation; near-deterministic |
| `exec_keyword` | weak | 2 | Single keywords like "ROI" or "roadmap" common in unrelated prose; need ≥ 2 distinct exec-speak markers + artifact_type gate |
| `shared_infra_change` | strong | 1 | Path-based (changes to `shared/`, `platform/`, API contract files); deterministic |

### `artifact_type` parameter propagation (CLS-03)

- **D-05:** `classify()` signature extension = **keyword-only argument with default**:
  ```python
  def classify(text: str, filename_hint: str, *, artifact_type: str = "code-diff") -> dict:
  ```
  The `*` forces `artifact_type` to be keyword-only; default preserves backward compatibility with v1.0 callers that don't pass it.
- **D-06:** `bin/dc-prep.sh` already classifies artifacts as `code-diff | plan | rfc` (line 6, D-04). MANIFEST.json already carries this value. `bin/dc-classify.sh` (the shell driver) must read MANIFEST.artifact_type and pass it to `classify()` via `--artifact-type` CLI arg (new flag).
- **D-07:** Only signals that CARE about artifact_type read it. Initial consumer: `exec_keyword` detector (gates to `plan | rfc | design`, never fires on `code-diff`). Future signals may gate differently. Pattern: detector function can accept `artifact_type` as keyword arg; detectors that don't take it are backward-compatible.
- **D-08:** `design` is a valid artifact_type per ROADMAP SC-2 ("`exec_keyword` fires only on `plan | rfc | design`"). v1.0 `bin/dc-prep.sh` classifier only emits `code-diff | plan | rfc`. Phase 3 does NOT extend the classifier to emit `design` — that would require touching dc-prep.sh which is Phase 3-adjacent but not in scope. For v1.1, `exec_keyword` gates to `plan | rfc` (2 types); `design` left as future-proofing in the signal's `artifact_type` list but won't fire until a future phase adds `design` detection to dc-prep.sh.

### Bench priority order (CLS-04)

- **D-09:** `config.json .budget.bench_priority_order` = explicit 9-entry array:
  ```json
  "bench_priority_order": [
    "security-reviewer",
    "compliance-reviewer",
    "dual-deploy-reviewer",
    "performance-reviewer",
    "finops-auditor",
    "air-gap-reviewer",
    "test-lead",
    "executive-sponsor",
    "competing-team-lead"
  ]
  ```
- **D-10:** Rationale comment sidecar: add `bench_priority_order_rationale` field (or embedded `_comment` keys) documenting why each position:
  - security > compliance: both touch sensitive code, but security covers broader attack surface; compliance is narrower (citable controls)
  - dual-deploy: critical for air-gap/enterprise customers; appears in many artifacts
  - performance > finops: hot-path findings are often actionable fixes; finops is budget-oriented (less time-critical)
  - air-gap < finops: air-gap is niche (self-hosted only)
  - test-lead: broader scope than perf but less critical than security/compliance
  - executive-sponsor + competing-team-lead: weak-signal personas, correctly last (budget cap will most often skip these)
- **D-11:** Budget cap behavior: when budget exhausts mid-fan-out, remaining personas are skipped with `reason: budget_cap` in MANIFEST. Phase 3 does NOT change the budget algorithm (Phase 6 v1.0 scope) — only adds the ordering input.
- **D-12:** Junior Engineer is NOT in `bench_priority_order` (it's always-invokable on code-diff, not signal-driven; runs outside the bench priority system alongside core personas in the conductor).

### Negative-fixture discipline (CLS-05)

- **D-13:** Fixture directory: `tests/fixtures/classifier-negatives/` with subdirs per detector:
  ```
  tests/fixtures/classifier-negatives/
    compliance-marker/
    performance-hotpath/
    test-imbalance/
    exec-keyword/
    shared-infra-change/
  ```
- **D-14:** ≥3 benign fixtures per detector = 15+ total. **Mix strategy**: scan existing `tests/fixtures/bench-personas/*` — any fixture that contains a new-detector trigger keyword incidentally becomes a negative fixture (cheap, reuses validated fixtures). Fill gaps with new synthetic benign artifacts where existing fixtures don't happen to contain the keywords.
- **D-15:** Example repurposable candidates (planner/executor verifies during implementation):
  - `autoscaling-change.yaml` → negative for `performance_hotpath` (scaling config, no loops)
  - `aws-sdk-import.py.diff` → negative for `test_imbalance` (src file, no test context)
  - `chart-yaml-present.yaml` → negative for `exec_keyword` (YAML, not prose)
- **D-16:** CI step order enforces inverted-TDD: in `scripts/test-classify.sh` and `.github/workflows/ci.yml`, negative fixtures run FIRST. If any negative fails (produces evidence where it should be silent), the job exits 1 BEFORE positive fixtures run. This prevents positive-bias when detectors are over-tuned.

### `lib/signals.json` schema extension (CLS-01 + CLS-02)

- **D-17:** 5 new entries added to `signals.json` following the existing shape + new fields. Example for `compliance_marker`:
  ```json
  "compliance_marker": {
    "description": "Regulatory or compliance-framework citations in code or plan artifacts (GDPR, HIPAA, SOC2, PCI, CCPA, FedRAMP).",
    "detection_hint": "Regex for citation patterns (Art. N, §N, CC-N, Req N), framework names as tokens, and data-handling keywords (retention, residency, audit-trail).",
    "signal_strength": "moderate",
    "min_evidence": 2,
    "target_personas": ["compliance-reviewer"],
    "artifact_type": ["code-diff", "plan", "rfc"]
  }
  ```
- **D-18:** `artifact_type` field is OPTIONAL in signals.json. If absent, the detector fires regardless of artifact_type (backward-compatible with v1.0 signals). Only `exec_keyword` uses this gate in v1.1.

### Backward compatibility with v1.0 signals

- **D-19:** v1.0 signals (auth_code_change, crypto_import, secret_handling, dependency_update, aws_sdk_import, new_cloud_resource, autoscaling_change, storage_class_change, helm_deploy_change, kustomize_deploy_change, dockerfile_change, code_complexity_spike, chart_yaml_present, ingress_tls_change, air_gap_egress, rbac_change) default to `signal_strength: strong`, `min_evidence: 1`, no `artifact_type` gate. The classifier code applies these defaults when fields are absent. No edits to existing signal entries required (but executor may choose to add explicit strength fields for documentation clarity — non-breaking).
- **D-20:** Existing Phase 6 tests (`scripts/test-classify.sh`) MUST still pass after Phase 3 changes. Any regression in the 17 existing positive/negative fixtures = P-02 prevention failure = blocker.

### Claude's Discretion

- Exact regex patterns for each of the 5 new detectors (within the `detection_hint` guidance)
- Exact rationale-comment wording for `bench_priority_order`
- Whether to embed rationale as JSON comments (`_comment_*` keys, since strict JSON has no comments) or as a sibling markdown doc
- Which specific existing bench-personas fixtures to reuse as negatives (D-14 mix strategy; planner investigates)
- Negative-fixture filenames (suggested pattern: `{detector}-benign-{N}.{ext}`)
- Plan split: Plans 03-01 (signals.json + classify.py + bench_priority_order + artifact_type) and 03-02 (Haiku whitelist + negative fixtures + test-classify.sh + CI step order) per ROADMAP "estimated 2"

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1.1 milestone context
- `.planning/REQUIREMENTS.md` §CLS — CLS-01 through CLS-06
- `.planning/ROADMAP.md` §Phase 3 — 5 success criteria
- `.planning/research/STACK.md` §Q5 — 15 new detectors guidance (Phase 3 implements the 5 signal-names; STACK recommended ~3 detector functions per persona but a single higher-quality detector per signal is fine)
- `.planning/research/ARCHITECTURE.md` — classifier extension integration points
- `.planning/research/PITFALLS.md` P-02 (classifier false-positive inflation — negative-fixture-first mandate)

### v1.0 code surfaces (existing; Phase 3 extends, does not rewrite)
- `lib/classify.py` — existing 406-line classifier; 16 detectors in place. Phase 3 adds 5 more + extends `classify()` signature with `artifact_type` kwarg (D-05)
- `lib/signals.json` — v1 registry; 16 existing signals. Phase 3 adds 5 new entries + extends schema with `signal_strength` (D-02), `min_evidence` (D-03), optional `artifact_type` (D-18)
- `bin/dc-classify.sh` — shell driver. Phase 3 extends to pass `--artifact-type` from MANIFEST.json to Python via CLI arg (D-06)
- `bin/dc-prep.sh` — already emits `artifact_type` in MANIFEST.json lines 200-225 (D-06). Phase 3 does NOT modify dc-prep.sh
- `agents/artifact-classifier.md` — Haiku fallback. Phase 3 expands the "four bench personas (the only valid values)" section to 8 (D-01)
- `scripts/test-classify.sh` — existing test runner. Phase 3 extends with negative-fixture-first ordering + 5 new detector fixtures (D-16)
- `.github/workflows/ci.yml` — Phase 3 adjusts test-classify step to enforce negative-first order at CI level too

### Phase-boundary notes
- Phase 4 depends on THIS phase completing. Phase 4 sidecars reference `signals.json` keys via `triggers:` frontmatter; PreToolUse validator R7 (at `scripts/validate-personas.sh`) rejects sidecars referencing unknown signal IDs. Therefore ALL 5 new signals MUST be in `lib/signals.json` before Phase 4 commits any sidecar
- Phase 6 (Codex schema rollout) is independent — no overlap with classifier code paths
- Phase 2 (Codex spike) is complete; no dependency

### External refs
- No external specs for classifier detector regexes; STACK.md §Q5 provides guidance only
- JSON Schema draft 2020-12 (lib/signals.json is plain JSON, not schema'd; if Phase 3 wants to add a JSON Schema for signals.json itself, that's bonus scope — not required)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`lib/classify.py` detector pattern** — each detector is `_detect_<signal>(text: str, filename_hint: str) -> list[str]`. Returns evidence list. Empty list = no match. The 5 new detectors follow exactly this shape + optional `artifact_type` kwarg (D-07).
- **`lib/signals.json` entry shape** — 4 required fields in v1.0 (description, detection_hint, target_personas). Phase 3 adds 2 new fields (`signal_strength`, `min_evidence`) and 1 optional field (`artifact_type`).
- **`bin/dc-classify.sh` shell driver** — invokes Python with `lib/classify.py` as script. Phase 3 extends with `--artifact-type "$ARTIFACT_TYPE"` CLI arg (requires `argparse` or equivalent in classify.py's `__main__` block).
- **`scripts/test-classify.sh`** — existing fixture runner. Phase 3 adds 15+ new negative-fixture assertions + orders them FIRST (D-16).
- **`tests/fixtures/bench-personas/*`** — 17+ existing fixtures. Phase 3 scans for keyword-incidental matches to repurpose as negatives (D-14 D-15).

### Established Patterns

- **Deterministic classifier** — no LLM calls in `lib/classify.py`. Pattern stays.
- **Signal-to-persona fan-out** — personas reference signals by ID in their `triggers:` frontmatter. PreToolUse validator R7 gates. Pattern stays.
- **Haiku fallback for zero-structural-match** — `agents/artifact-classifier.md` invoked only when classify.py returns empty. Whitelist expansion (D-01) is the only Phase 3 change to this agent.
- **Test fixtures under `tests/fixtures/`** — organized by subsystem (bench-personas, classifier-negatives, injection-corpus, chair-strictness, shell-inject). Phase 3 adds `classifier-negatives/`.
- **Inverted TDD in CI** — new pattern introduced Phase 3 per CLS-05: negatives run FIRST. If any negative fails, positives don't run. Prevents positive-bias.

### Integration Points

- Phase 3 output feeds Phase 4 directly: Phase 4 persona sidecars reference signals by ID (`triggers: [compliance_marker]`). PreToolUse hook gates. Phase 4 CANNOT commit sidecars without Phase 3's signals.json entries existing first.
- Phase 6 independent: no Codex-schema-related code in classifier path.
- Budget cap (v1.0 Phase 6) reads `config.json .budget.bench_priority_order` — Phase 3 populates the 9-entry array (D-09). No v1.0 budget algorithm changes.

</code_context>

<specifics>
## Specific Ideas

- **Negative-fixture-first is load-bearing.** If test-classify.sh runs positives before negatives, a detector that fires on both its positive fixture AND a similar-looking negative will pass the positive assertion and mask the false-positive. Negative-first discipline is the P-02 prevention mechanism. CI step order must enforce this at the pipeline level, not just in the bash script (a future developer removing the `set -e` could mask the ordering). Recommend TWO separate CI steps: one for negatives, one for positives, with positives depending on negatives passing.

- **`exec_keyword` is the riskiest new detector.** Single words like "ROI", "strategic", "roadmap" appear in benign prose constantly. Combined defenses: (a) `artifact_type` gate (no firing on code-diff), (b) `min_evidence: 2` (need 2 distinct exec-speak markers), (c) specific keyword list (not generic business terms). Executor should bias the keyword list toward nominalization patterns ("move the needle", "strategic alignment", "unlock value", "de-risk") rather than single words.

- **`test_imbalance` needs a file-set view, not single-file regex.** Detection happens across the artifact: "are there src changes without matching test changes?" This is a structural pattern the classifier hasn't implemented before — all existing detectors are per-file regex/AST. Phase 3 may need to add a file-set-aware detector helper in classify.py (new utility function, not just a regex). Flag this in planning.

- **bench_priority_order rationale can use JSON comments via `_comment_*` keys** — strict JSON has no comments, but a convention of `"_comment_security": "reason text"` keys is acceptable and greppable. Alternative is a sidecar `.planning/research/bench-priority-rationale.md` — but then rationale drifts from the config it documents. Prefer JSON with `_comment_*` keys.

- **Plan split recommendation:** 2 plans per ROADMAP "estimated 2":
  - 03-01: `lib/classify.py` + `lib/signals.json` + `bin/dc-classify.sh --artifact-type` + `config.json .budget.bench_priority_order` (detector implementation + registry + pipeline plumbing)
  - 03-02: `tests/fixtures/classifier-negatives/` + `scripts/test-classify.sh` update + `agents/artifact-classifier.md` whitelist + `.github/workflows/ci.yml` step order (testing + Haiku whitelist)
  - Two plans can run sequentially within Phase 3 (03-02 depends on 03-01 producing new signals entries before test-classify can reference them).

</specifics>

<deferred>
## Deferred Ideas

- **JSON Schema for signals.json itself** (would formalize the structure described in D-17, D-18): bonus scope; not required for Phase 3 completion. Consider for v1.2 or a future hardening phase.
- **`design` artifact_type detection in bin/dc-prep.sh** (D-08 notes the gap): Phase 3 doesn't extend dc-prep.sh. If design-artifact detection becomes needed (e.g., a user runs `/devils-council:review figma-export.fig`), add in a future phase. For v1.1, `exec_keyword` effectively gates to `plan|rfc` since dc-prep.sh only emits those two non-code types.
- **Cross-detector hit-count rule** (Q2 Option B alternative): rejected. Per-signal `min_evidence` (D-03) is simpler and more explicit.
- **Greenfield-only negative fixtures** (Q5 Option A alternative): rejected. Mix-strategy is cheaper.
- **executive-sponsor in Haiku whitelist** (Q1 Option B alternative): rejected. Keeps SC-4 count at 8 and matches PITFALLS P-11 defense.
- **Junior Engineer in bench_priority_order**: explicitly NOT included (D-12). Junior Eng runs outside the bench priority system alongside core personas — it's always-invokable on code-diff, not signal-driven.

</deferred>

---

*Phase: 03-classifier-extension*
*Context gathered: 2026-04-25*
