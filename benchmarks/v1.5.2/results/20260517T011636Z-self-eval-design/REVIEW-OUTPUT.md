# Devils Council Self-Eval Design — Adversarial Review

**Artifact**: `.planning/self-eval-design.md` (340 lines)  
**Reviewed**: 2026-05-17  
**Reviewer**: Devils Council (self-applied, sequential persona mode)

---

## Staff Engineer Scorecard

### Findings

---

**Finding 1**

- **Severity**: blocker
- **Target**: Layer 2 — Matching Algorithm
- **Claim**: The substring-match algorithm is not fit for purpose. It hardcodes specific words that must appear in a finding's `claim` field, but LLMs produce semantically equivalent findings with different vocabulary. The matching will produce false negatives on valid recalls — making the benchmark measure vocabulary consistency, not issue detection.
- **Evidence**: `"must_claim_contains": "A/B testing"` and `"must_claim_contains": "multi-region"` and `"must_claim_contains": "circular"` — these are literal substring matches, not semantic matches
- **Ask**: Replace substring matching with embedding-similarity (cosine ≥ 0.85) or at minimum a synonym-aware keyword set. If that's too complex for v1, use a bag-of-keywords with OR logic (`"multi-region" OR "cross-region" OR "geographic redundancy"`) rather than a single required term. Document the false-negative rate with the current approach before shipping.

---

**Finding 2**

- **Severity**: major
- **Target**: Layer 2 — Corpus Structure / Open Questions
- **Claim**: 5 corpus items produce recall statistics that look precise (93.3%) but are statistically meaningless. With 15 total expected findings, a single miss changes recall from 100% to 93.3%. The benchmark is too small to distinguish noise from signal, yet it's being proposed as a CI gate.
- **Evidence**: `"Corpus: 5 items, 23 expected findings"` in the sample output, and Open Question 1: `"Corpus size: 5 items enough for v1? Or should we aim for 10+ before gating?"` — the design ships a gate before answering its own question about whether the gate is valid
- **Ask**: Either: (a) don't gate on recall until corpus reaches 30+ expected findings across 10+ items, or (b) set gate threshold based on corpus-size-adjusted confidence interval, not a fixed 0.8. At n=23 expected findings, the 95% CI for an 80% recall rate spans roughly ±16 points — you can't distinguish 80% from 96% with this corpus.

---

**Finding 3**

- **Severity**: major
- **Target**: Iterative Exit Criteria
- **Claim**: The exit criteria logic is contradictory. It claims to exit when findings converge, but the CONTINUE condition overlaps with the EXIT condition in ways that produce indeterminate behavior when an artifact is modified mid-review.
- **Evidence**: `"EXIT when: No new BLOCKER findings in 2 consecutive rounds AND no new MAJOR findings in the latest round"` versus `"CONTINUE when: New BLOCKERs appeared (the artifact changed in a way that created new issues)"` — if an artifact is modified between rounds, new BLOCKERs may legitimately appear (triggering CONTINUE), but the EXIT condition was already triggered (no BLOCKERs in the previous two rounds on the OLD artifact). The state machine is undefined.
- **Ask**: Make exit criteria artifact-version-scoped. Track rounds per SHA256 of the artifact, not globally. If the SHA256 changes, reset the round counter. State machine: `[(sha, round)] → {EXIT, CONTINUE}`, not global round tracking.

---

**Finding 4**

- **Severity**: major
- **Target**: Implementation Phases / Self-Eval Command
- **Claim**: The command `opencode run "/devils-council:self-eval --compare $(git describe --tags --abbrev=0 HEAD~1)"` in the release CI is not actually defined as an opencode command anywhere in the design. The spec describes its output format and flags but never specifies where the implementation lives or what it does. Phase 2 says "implement the command" but provides no interface contract.
- **Evidence**: `"Phase 2: Self-Eval Command — /devils-council:self-eval command in .opencode/commands/"` with no spec of what the command script must do, what it reads, or how it produces `RESULTS.md`. Compare to Phase 1 which has concrete deliverables: `"Create benchmarks/corpus/ from existing test fixtures"`.
- **Ask**: Write a concrete interface spec for the command before Phase 2 begins: input format (corpus path, baseline version), output format (RESULTS.md schema), error codes (exit 0=pass, 1=BLOCK, 2=WARN, 3=error), timeout behavior, and side effects (does it write to `benchmarks/`?).

---

**Finding 5**

- **Severity**: minor
- **Target**: Layer 3 — Quality Rubric
- **Claim**: Layer 3 dimension 2 ("Evidence grounding (1-5): Is the evidence a verbatim quote from the artifact?") is a scored duplicate of a Layer 1 structural check. You're paying LLM inference costs to re-grade something Layer 1 already validates deterministically.
- **Evidence**: Layer 1: `"Evidence is verbatim (appears in INPUT.md)"` — this is a boolean check. Layer 3 dimension 2: `"Evidence grounding (1-5): Is the evidence a verbatim quote from the artifact?"` — this is the same predicate on a 1-5 scale.
- **Ask**: Remove dimension 2 from Layer 3. If you want gradations beyond boolean, express them at Layer 1 (e.g., check evidence length ≥ 10 chars, check it appears without normalization). Spending LLM tokens to re-assess a deterministically verifiable property is waste.

---

---

## SRE Scorecard

### Findings

---

**Finding 1**

- **Severity**: blocker
- **Target**: CI Integration — Per-release golden set / failure detection
- **Claim**: The CI failure detection is broken. Using `grep -q "VERDICT: BLOCK"` to detect CI failure means: if the self-eval command itself fails (crashes, times out, produces malformed output, or RESULTS.md is never created), the grep returns non-zero for a different reason — and the pipeline behavior depends on shell errexit settings, not intentional logic. A command crash silently passes CI.
- **Evidence**: `"if grep -q \"VERDICT: BLOCK\" .council/self-eval/RESULTS.md; then exit 1; fi"` — this check only fails if the file exists AND contains "VERDICT: BLOCK". If the file doesn't exist or the prior step exits non-zero, the behavior is undefined without explicit `set -e` or step-level `continue-on-error: false`.
- **Ask**: Invert the failure condition. The self-eval command should exit with a non-zero code directly on BLOCK verdict, and the CI step should rely on that exit code. Remove the grep post-processing entirely. If RESULTS.md must be parsed, add an explicit pre-check: `test -f .council/self-eval/RESULTS.md || exit 2`.

---

**Finding 2**

- **Severity**: blocker
- **Target**: Layer 2 — Scoring / Gate Criteria / Open Questions
- **Claim**: The design proposes a 0.8 recall gate without measuring the actual run-to-run variance of recall. LLM outputs are non-deterministic. The design's own Open Question 2 acknowledges this but ships the gate anyway. If variance is ±10%, a 0.8 gate will fail randomly on 50% of compliant runs.
- **Evidence**: Open Question 2: `"Recall threshold: 0.8 too lenient? 0.9 too strict given LLM non-determinism?"` — the design admits the threshold is unvalidated. Gate criteria: `"recall >= 0.8 (must catch 80% of expected findings)"` — this is shipped as a hard gate without empirical basis.
- **Ask**: Before setting any gate threshold, run the same council configuration 10 times against corpus item 01 and measure recall variance. If σ > 0.05, the gate is noise. Consider requiring deterministic expected findings to be matched in 3 of 3 runs before they're counted, or use majority-vote scoring across N runs (N=3 minimum) for gating.

---

**Finding 3**

- **Severity**: major
- **Target**: Dogfooding — council-self-review workflow
- **Claim**: The dogfooding CI job reports council findings on its own PRs but has no merge-blocking condition. A blocker finding on the council's own code changes would be annotated and then ignored. The review is theater, not a gate.
- **Evidence**: The workflow yaml shows `severity-threshold: major` as a filter parameter, not a fail-on parameter. The job has no explicit `exit 1` or `fail-fast: true` equivalent when blockers are found. Compare to the golden set job which explicitly uses `exit 1`.
- **Ask**: Add `fail-on-severity: blocker` to the `devils-council-action` invocation, or add a post-step that exits 1 if any blocker finding appears in the output. Otherwise this is a notification system, not a quality gate.

---

**Finding 4**

- **Severity**: major
- **Target**: Anti-Bias Measures — Expected findings as ground truth
- **Claim**: "Human-curated" expected findings are presented as a bias mitigation, but there is no process defined for who reviews, challenges, or updates those expectations. A single contributor could encode their blind spots into the expected findings manifest, and every future run would validate against those blind spots indefinitely.
- **Evidence**: `"Expected-findings as ground truth (Layer 2): human-curated, not LLM-generated"` — the anti-bias measure asserts human curation = correctness, with no governance process described. No reviewer requirement, no expiry, no challenge mechanism.
- **Ask**: Define a governance policy for the expected findings corpus: (a) at least 2 contributors must sign off on each expected finding, (b) expected findings must include a rationale comment explaining WHY this finding is expected, (c) expected findings older than 6 months or 3 major versions must be re-reviewed. This transforms "human-curated" from a trust assertion into a verifiable process.

---

**Finding 5**

- **Severity**: minor
- **Target**: Implementation Phases / Cost Budget
- **Claim**: The cost estimate of ~$0.50/run is stated without basis and is likely wrong. A 4-persona council run on a medium-length artifact with claude-sonnet at current pricing could easily reach $1.50–$3.00 per run depending on context length. The design's total estimate of $2.50 for a release gate could be 4-6× off.
- **Evidence**: `"Full golden set with 5 corpus items = 5 council runs. At ~$0.50/run that's $2.50 per release gate. Acceptable?"` — no derivation for the $0.50 figure, no citation to model pricing, no analysis of average token counts per corpus item.
- **Ask**: Replace the estimate with a measured cost. Run the full corpus once manually, record actual API cost per item, sum to a real baseline. Update the open question with the measured figure. This matters because cost determines whether teams will disable the gate.

---

---

## Product Manager Scorecard

### Findings

---

**Finding 1**

- **Severity**: blocker
- **Target**: Design Goals / Problem Statement
- **Claim**: The design is entirely inward-facing — it measures whether the council performs consistently across versions, but never connects this to user-facing value. A user of Devils Council doesn't benefit from 93.3% recall on an internal benchmark. The design never articulates what user outcome improves when the benchmark passes.
- **Evidence**: `"Design Goals: (1) Release gating — CI blocks release if scorecard quality regresses, (2) Drift detection — measure finding recall/precision across versions, (3) Exit criteria — iterative review knows when to stop, (4) Dogfooding — the council action reviews DC's own PRs"` — all four goals are developer/operator concerns. Zero goals are framed as user outcomes ("users catch more bugs", "users trust council findings", "users spend less time on false positives").
- **Ask**: Add a user-outcome goal to the design: e.g., "Precision ≥ X% means users waste fewer cycles on false positives" or "Recall ≥ Y% means users catch critical issues that reach production less often." Tie at least one gate metric to a user-facing KPI. Otherwise this benchmark only measures self-consistency, not actual value delivered.

---

**Finding 2**

- **Severity**: major
- **Target**: Dogfooding section
- **Claim**: The dogfooding use case ("council reviews its own PRs") is asserted as useful but provides no analysis of what value it actually delivers that existing code review doesn't. "Meta-circular, but useful" is a claim without evidence. If the council is running on its own prompt files, it's reviewing Markdown, not code — and the council is explicitly designed for plans and code diffs. This is a feature optimized for demos, not for user value.
- **Evidence**: `"The council reviews its own code changes. Meta-circular, but useful — catches persona prompt regressions, validates new features don't break existing behavior."` — "meta-circular, but useful" acknowledges the awkwardness without resolving it. "Catches persona prompt regressions" is a function already served by Layer 2 golden set recall. The same job is being done twice.
- **Ask**: Either justify dogfooding with a concrete example of a bug it would have caught that other testing missed, or remove Phase 3 dogfooding from v1 scope. The CI complexity and meta-circularity cost is real; the benefit is asserted. If dogfooding is kept, define what artifact type the council reviews on a PR to prompt files (it's not a plan or diff in the traditional sense).

---

**Finding 3**

- **Severity**: major
- **Target**: Layer 3 — Quality Rubric (optional, expensive)
- **Claim**: Layer 3 is designed as optional and expensive with no clear trigger for when it gets used in practice. "Only on release candidates, not every CI run" combined with "use --rubric to enable" means it will never be run unless someone remembers to run it. Expensive optional features that require manual invocation become shelfware.
- **Evidence**: `"When to use: Only on release candidates, not every CI run. Too expensive for per-PR gating."` and in the sample output: `"Layer 3: Quality Rubric (skipped — use --rubric to enable)"` — the default behavior skips Layer 3 entirely.
- **Ask**: Either (a) make Layer 3 mandatory on release CI with a defined budget cap (`max-cost: $5.00` parameter that aborts cleanly if exceeded), or (b) acknowledge Layer 3 as deferred to a future milestone and remove it from this spec. A feature that's "optional and expensive" with no automatic trigger is not a feature — it's aspirational documentation.

---

**Finding 4**

- **Severity**: minor
- **Target**: Implementation Phases
- **Claim**: The phases have no time estimates, no resource requirements, and no success criteria beyond "done." Phase 3 (CI integration) depends on Phase 2 (the command) but the dependency is not stated. A reader cannot estimate whether this is a 1-week or 3-month effort.
- **Evidence**: `"Phase 1: Corpus + Expected Findings (immediate)"` — "immediate" is the only time signal in the entire phasing section. Phases 2, 3, and 4 have no time signal at all.
- **Ask**: Add effort estimates (S/M/L/XL) and explicit dependencies to each phase. Mark Phase 4 explicitly as a stretch goal that may never ship. This enables prioritization conversations.

---

**Finding 5**

- **Severity**: minor
- **Target**: Open Questions
- **Claim**: The open questions section reads like deferred decisions disguised as questions. Questions 1-4 are actually blockers for implementing the gate correctly — corpus size determines gate validity, recall threshold determines gate reliability, model vs prompt drift affects regression attribution, cost estimate affects adoption. These should be resolved before the spec is executed, not left as open questions.
- **Evidence**: `"Open Questions: (1) Corpus size: 5 items enough for v1? Or should we aim for 10+ before gating? (2) Recall threshold: 0.8 too lenient? (3) Model drift vs prompt drift: Should we separate... (4) Cost budget: Full golden set... Acceptable?"` — all four are prerequisites to the design working correctly, not post-implementation concerns.
- **Ask**: Convert open questions to either (a) explicit decisions with rationale, or (b) explicit Phase 0 research tasks that block Phase 1. Don't ship a spec that acknowledges its core parameters are undecided.

---

---

## Devil's Advocate Scorecard

### Findings

---

**Finding 1**

- **Severity**: blocker
- **Target**: Anti-Bias Measures / Layer 2 — entire framing
- **Claim**: The design names "meta-evaluation collapse" as the key risk, then proposes mitigations that don't resolve it — they relocate it. Human-curated expected findings still encode the perspective of humans who evaluated the council's existing behavior. The corpus was presumably built using findings from DC runs that worked well. This means the benchmark measures "does DC still do what it used to do" — which is consistency, not correctness. Consistently wrong is still wrong.
- **Evidence**: `"The research identified 'meta-evaluation collapse' as the key risk — the same model grading its own output will rate itself higher. Mitigations: (2) Expected-findings as ground truth (Layer 2): human-curated, not LLM-generated"` — the anti-bias claim is that human curation avoids LLM self-preference. But if the humans curated findings BY RUNNING DC and selecting ones that looked good, the circularity is one step removed, not removed.
- **Ask**: Document the provenance of each corpus item and expected finding: was the expected finding generated by running DC, by independent human review, or by a different tool? If any expected finding was seeded from DC's own output, mark it as "consistency anchor" rather than "ground truth" — and gate only on non-circular findings. The distinction matters for what the benchmark actually measures.

---

**Finding 2**

- **Severity**: major
- **Target**: Layer 2 — Scoring / Recall metric definition
- **Claim**: The recall metric measures divergence from previous behavior, not improvement in quality. If v1.3.4 had a systematic bias (e.g., over-flagging architecture decisions as "over-engineering"), and those biased findings were pinned as expected, then v1.4.0 correctly reducing false positives would show as a recall regression. The metric would report a quality improvement as a failure.
- **Evidence**: `"Regression: Did it LOSE a finding that v(N-1) caught?"` and `"regression_count == 0 for blocker/major expected findings"` — the regression definition is "changed from previous" not "missed a real issue." A system that was wrong before and is now right would be penalized.
- **Ask**: Add a "finding disposition" field to each expected finding: `disposition: confirmed-real-issue` vs `disposition: historical-anchor`. Only gate on regressions for `confirmed-real-issue` expected findings. Historical anchors should generate warnings, not failures. This requires human review of each expected finding at pin time, which is the right moment to make this call.

---

**Finding 3**

- **Severity**: major
- **Target**: Iterative Exit Criteria
- **Claim**: The exit criteria embeds an untested assumption that good artifact reviews converge to a stable finding count. For sufficiently complex or flawed artifacts, each review round may legitimately surface new angles — the review is deepening, not repeating. The exit condition "total finding count delta < 10% between rounds" would terminate useful reviews early.
- **Evidence**: `"EXIT when: No new BLOCKER findings in 2 consecutive rounds AND no new MAJOR findings in the latest round AND total finding count delta < 10% between rounds"` — the 10% delta criterion assumes convergence is the norm. It assumes review quality stabilizes, which is true for simple artifacts but not for architecturally complex ones.
- **Ask**: Make the 10% delta criterion configurable and document the assumption explicitly: "This criterion assumes the artifact is sufficiently scoped that exhaustive review is reachable." Add an override: `--max-rounds N` that terminates regardless of convergence, and default max-rounds to a finite number (e.g., 5) to prevent infinite loops on adversarial artifacts.

---

**Finding 4**

- **Severity**: major
- **Target**: Problem Statement / Design Goals
- **Claim**: The design assumes release gating is the right solution for quality drift, but never considers whether release cadence is high enough to make drift detection meaningful. If DC releases once a month, by the time a drift is caught at release gate, it has been in use for weeks. The design solves a problem (drift) but the solution (release gate) is disconnected from the failure mode (users experiencing drift in production).
- **Evidence**: `"Design Goals: (1) Release gating — CI blocks release if scorecard quality regresses"` — the entire architecture is oriented around blocking releases, but the problem statement says `"Today there's no way to measure whether v1.4.0 catches more, less, or different issues than v1.3.4 on the same input"`. The gap is measurement, not gating. You can measure without gating, and gating without continuous measurement misses drift between releases.
- **Ask**: Separate measurement from gating. Implement continuous measurement (run golden set on every merge to main, store time-series results) separate from release gating. The time-series tells you WHEN drift started; the gate only tells you it exists. You need both, but the design only builds the gate.

---

**Finding 5**

- **Severity**: minor
- **Target**: Layer 3 — Cross-model grading / Anti-Bias Measures
- **Claim**: "Cross-model grading to avoid self-preference bias" assumes that a different model family is unbiased relative to the graded model. This is an untested assumption. GPT-4 grading Claude's output may introduce its own systematic preferences (e.g., grading findings that match GPT-4's reasoning style higher, regardless of quality). The bias is relocated, not eliminated.
- **Evidence**: `"Use a DIFFERENT model (cross-model grading to avoid self-preference bias) to score each finding on 5 dimensions"` — the premise is that inter-model bias < intra-model bias. This may be true, but it's asserted without evidence. There is published research showing cross-model bias is real (e.g., models tend to prefer findings that resemble their own generation patterns).
- **Ask**: Either cite evidence that cross-model grading reduces net bias for this use case, or add a calibration step: have humans score 20 findings, compare to cross-model scores, and compute agreement. If human-model agreement is not meaningfully better than chance, cross-model grading provides no value and should be removed.

---

---

## SYNTHESIS

### Top 3 Issues by Severity

**1. CI failure detection is broken (SRE-1, BLOCKER)**  
The release gate's failure condition uses `grep -q "VERDICT: BLOCK"` on a file that may not exist. A crashing self-eval command silently passes CI. This is an operational correctness defect that makes the entire gate untrustworthy. Attributed to: SRE persona.

**2. Substring matching will generate systematic false negatives (Staff Engineer-1, BLOCKER)**  
`must_claim_contains: "multi-region"` fails to match semantically equivalent findings using different vocabulary. The benchmark will report recall misses for valid findings that use different words, making the metric noisy and the gate unreliable. Attributed to: Staff Engineer persona.

**3. Meta-evaluation collapse is renamed, not resolved (Devil's Advocate-1, BLOCKER)**  
The design correctly identifies circular self-evaluation as the core risk, then relocates it rather than resolving it. Human-curated expected findings likely encoded DC's own prior outputs, making the benchmark measure consistency with past behavior rather than correctness. Attributed to: Devil's Advocate persona.

---

### Persona Contradictions

**Staff Engineer vs SRE on corpus size:**  
Staff Engineer says the corpus is too small to yield statistically meaningful recall metrics (Finding SE-2: "At n=23 expected findings, the 95% CI spans roughly ±16 points"). SRE says the gate threshold is set without measuring variance (Finding SRE-2). These are complementary, not contradictory — both agree the gate is unvalidated, but from different angles. Together they demand: measure variance FIRST, set threshold SECOND, define corpus size THIRD.

**Product Manager vs Devil's Advocate on dogfooding:**  
PM says dogfooding is a vanity feature without demonstrated value (Finding PM-2: "optimized for demos, not user value"). Devil's Advocate doesn't directly address dogfooding, but its overall framing — that the benchmark measures consistency not correctness — implies dogfooding has negative value: it would validate that DC catches its own prompt regressions, but if the original prompts were subtly wrong, it'd just confirm the existing bias persists. These are reinforcing, not contradictory.

**Staff Engineer vs SRE on Layer 3:**  
Staff Engineer says Layer 3 dimension 2 is a wasteful duplication of Layer 1 (Finding SE-5). SRE doesn't address Layer 3 directly. PM says Layer 3 will become shelfware due to manual invocation (Finding PM-3). No contradiction — three independent reasons to be skeptical of Layer 3 as designed.

---

### Overall Verdict: **WARN**

The design is not blocked on architectural grounds — the three-layer stack is a reasonable structure and the corpus+expected-findings approach is the right pattern for this problem. However:

- **Two operational defects** (broken CI failure detection, unvalidated gate threshold) must be fixed before shipping CI integration. These are Phase 3 blockers, not Phase 1 blockers.
- **One conceptual defect** (substring matching in the recall algorithm) must be fixed before the benchmark produces meaningful signal. This is a Phase 2 blocker.
- **One philosophical risk** (meta-evaluation circularity) should be addressed by documenting expected-finding provenance before pinning the v1.4.0 baseline. This is not a blocker but will silently corrupt the benchmark if ignored.

The implementation phases are reasonable but the Open Questions section should be converted to resolved decisions before any code is written. Shipping Phase 1 with unresolved corpus size and threshold questions means building against parameters that may invalidate the work.

**Recommended action**: Address SE-1 (matching algorithm), SRE-1 (CI failure detection), and SRE-2 (threshold validation) before Phase 2 begins. The rest can be tracked as follow-up issues.
