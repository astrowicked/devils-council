# Self-Eval Design: Devils Council Quality Benchmark

## Problem Statement

The council's output quality can drift between releases (prompt changes, persona
rewrites, model updates). Today there's no way to measure whether v1.4.0 catches
more, less, or different issues than v1.3.4 on the same input. There's also no
iterative exit criterion — no way to know "this artifact has been reviewed enough."

## Design Goals

1. **Release gating** — CI blocks release if scorecard quality regresses
2. **Drift detection** — measure finding recall/precision across versions
3. **Exit criteria** — iterative review knows when to stop
4. **Dogfooding** — the council action reviews DC's own PRs

---

## Architecture: Three-Layer Eval Stack

```
Layer 1: Structural validation (deterministic, zero LLM cost)
         → scorecard YAML valid, required fields present, severity enum valid,
           evidence is non-empty, finding IDs match format, no banned phrases

Layer 2: Golden set recall (LLM cost = 1 council run per fixture)
         → run council against known-bad artifacts, compare findings to
           version-pinned expected-findings manifest

Layer 3: Quality rubric (LLM-as-judge, optional, expensive)
         → grade finding quality on 5 dimensions, compare to baseline scores
```

### Layer 1: Structural Validation (existing)

Already implemented: `dc-validate-scorecard.sh` (24KB). Checks:
- YAML frontmatter parseable
- Required fields: persona, findings[], each finding has id/target/claim/evidence/ask/severity
- Severity enum: blocker/major/minor/nit
- Finding IDs match `<persona-slug>-<8hex>` format
- No banned phrases per persona voice kit
- Evidence is verbatim (appears in INPUT.md)

**No changes needed.** This is the fast gate.

### Layer 2: Golden Set Recall (new)

A curated corpus of inputs + expected findings. On each release, run the council
against the corpus and measure:

- **Recall**: Did it find the things we expect? (per expected-finding)
- **Precision**: How many findings are noise? (not in expected set)
- **Regression**: Did it LOSE a finding that v(N-1) caught?

#### Corpus Structure

```
benchmarks/
├── MANIFEST.json              # version, date, expected-findings count
├── v1.4.0/                    # version-pinned baseline
│   ├── MANIFEST.json
│   └── results/               # actual scorecard outputs from this version
├── corpus/
│   ├── 01-over-engineering.md         # the demo plan
│   ├── 02-contradiction-seed.md       # deliberate contradictions
│   ├── 03-security-diff.patch         # session token expiry change
│   ├── 04-multi-signal.md             # triggers multiple bench personas
│   └── 05-clean-plan.md              # well-written plan (should have FEW findings)
└── expected/
    ├── 01-over-engineering.yml        # expected findings for corpus item 01
    ├── 02-contradiction-seed.yml
    ├── 03-security-diff.yml
    ├── 04-multi-signal.yml
    └── 05-clean-plan.yml
```

#### Expected Findings Format

```yaml
# benchmarks/expected/01-over-engineering.yml
corpus_item: 01-over-engineering.md
version_pinned: "1.4.0"
expected_findings:
  - id: "staff-engineer-*"           # glob — ID will vary per run
    persona: staff-engineer
    severity: major
    must_target: "Task 2"            # target must reference this section
    must_claim_contains: "A/B testing"  # claim must mention this concept
    
  - persona: sre
    severity: major
    must_target: "Risks & Mitigations"
    must_claim_contains: "auto-scaling"  # catches circular mitigation
    
  - persona: product-manager
    severity: major
    must_claim_contains: "multi-region"  # catches unjustified scope
    
  - persona: devils-advocate
    severity: major
    must_target: "Risks & Mitigations"
    must_claim_contains: "circular"     # catches circular reasoning

not_expected:
  - description: "False positive on Kafka partition key choice"
    if_persona: staff-engineer
    if_claim_contains: "partition key"
    if_severity: blocker               # this should be minor at most
```

#### Matching Algorithm

For each expected finding, search actual findings with:
1. Persona matches exactly
2. Severity matches or exceeds (blocker > major > minor > nit)
3. `must_target` substring appears in `target`
4. `must_claim_contains` substring appears in `claim`

Match = found. Miss = regression.

For `not_expected`, if a finding matches the pattern, it's a precision failure.

#### Scoring

```
recall    = matched_expected / total_expected
precision = findings_not_in_noise / total_findings
regression_count = expected_findings_in_v(N-1)_but_not_v(N)
```

**Gate criteria:**
- recall >= 0.8 (must catch 80% of expected findings)
- regression_count == 0 for blocker/major expected findings
- no `not_expected` patterns matched at blocker severity

### Layer 3: Quality Rubric (optional, expensive)

Use a DIFFERENT model (cross-model grading to avoid self-preference bias) to
score each finding on 5 dimensions:

1. **Specificity** (1-5): Does the claim name a concrete thing, or is it vague?
2. **Evidence grounding** (1-5): Is the evidence a verbatim quote from the artifact?
3. **Actionability** (1-5): Does the ask tell you what to DO, not just what's wrong?
4. **Calibration** (1-5): Is the severity appropriate for the actual risk?
5. **Voice fidelity** (1-5): Does the finding sound like the persona's voice kit?

Score per finding, aggregate per persona, compare to baseline.

**When to use**: Only on release candidates, not every CI run. Too expensive for
per-PR gating.

---

## Iterative Exit Criteria

For interactive use (not CI), when running multiple review rounds on the same
artifact:

```
EXIT when:
  - No new BLOCKER findings in 2 consecutive rounds
  - AND no new MAJOR findings in the latest round
  - AND total finding count delta < 10% between rounds

CONTINUE when:
  - New BLOCKERs appeared (the artifact changed in a way that created new issues)
  - OR previous round's asks were not addressed
```

Implementation: track `MANIFEST.json` across runs for the same artifact (keyed by
SHA256). The exit criterion is metadata-only — no LLM call.

---

## Dogfooding: Council Reviews Its Own PRs

Add to `.github/workflows/ci.yml`:

```yaml
  council-self-review:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - uses: astrowicked/devils-council-action@v2
        with:
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          severity-threshold: major
          exclude-paths: "*.lock,dist/**,.council/**"
```

The council reviews its own code changes. Meta-circular, but useful — catches
persona prompt regressions, validates new features don't break existing behavior.

---

## Self-Eval Command: `/devils-council:self-eval`

### Usage

```bash
# Run the full benchmark (Layer 1 + Layer 2)
/devils-council:self-eval

# Run against a specific corpus item
/devils-council:self-eval --item 01-over-engineering

# Compare current results to a pinned baseline
/devils-council:self-eval --compare v1.4.0

# Pin current results as the new baseline
/devils-council:self-eval --pin v1.5.0
```

### Output

```
=== Devils Council Self-Eval ===

Layer 1: Structural Validation
  ✓ 5/5 corpus items produced valid scorecards
  ✓ All findings have required fields
  ✓ No banned phrases detected

Layer 2: Golden Set Recall
  Corpus: 5 items, 23 expected findings

  01-over-engineering.md    4/4 expected ✓  (0 regressions)
  02-contradiction-seed.md  3/3 expected ✓  (0 regressions)
  03-security-diff.patch    2/3 expected ⚠  (1 miss: security-reviewer token-expiry)
  04-multi-signal.md        5/5 expected ✓  (0 regressions)
  05-clean-plan.md          0/0 expected ✓  (0 false blockers)

  Recall: 14/15 (93.3%)
  Regressions: 0 blocker, 1 major
  Precision violations: 0

  VERDICT: WARN (1 major miss — review benchmarks/expected/03-security-diff.yml)

Layer 3: Quality Rubric (skipped — use --rubric to enable)
```

### Pin Workflow

After a release passes self-eval satisfactorily:

```bash
/devils-council:self-eval --pin v1.4.0
```

This copies the current run's scorecards into `benchmarks/v1.4.0/results/` and
updates `benchmarks/MANIFEST.json`. Future runs compare against this baseline.

---

## CI Integration

### Per-PR: Structural only (fast, free)

```yaml
  self-eval-structural:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          for scorecard in tests/fixtures/scorecards/*.md; do
            bin/dc-validate-scorecard.sh "$(basename $scorecard .md)" . || exit 1
          done
```

### Per-release: Full golden set (expensive, gates tag)

```yaml
  self-eval-golden:
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astrowicked/devils-council-action@v2
        with:
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
      - run: |
          # Run self-eval against corpus
          opencode run "/devils-council:self-eval --compare $(git describe --tags --abbrev=0 HEAD~1)"
          # Fail on regressions
          if grep -q "VERDICT: BLOCK" .council/self-eval/RESULTS.md; then
            exit 1
          fi
```

---

## Anti-Bias Measures

The research identified "meta-evaluation collapse" as the key risk — the same
model grading its own output will rate itself higher. Mitigations:

1. **Deterministic anchor** (Layer 1): structural checks can't be gamed
2. **Expected-findings as ground truth** (Layer 2): human-curated, not LLM-generated
3. **Cross-model grading** (Layer 3): use a different model family for the rubric judge
4. **Version pinning**: compare against PREVIOUS version's output, not self-assessed quality
5. **Negative examples**: `not_expected` patterns catch false positives that self-eval would miss

---

## Implementation Phases

### Phase 1: Corpus + Expected Findings (immediate)
- Create `benchmarks/corpus/` from existing test fixtures
- Write `expected/` manifests for each corpus item
- Pin v1.4.0 baseline from current demo run output

### Phase 2: Self-Eval Command
- `/devils-council:self-eval` command in `.opencode/commands/`
- Matching algorithm (expected vs actual)
- Score + verdict output
- `--pin` and `--compare` flags

### Phase 3: CI Integration
- Add structural validation to per-PR CI
- Add golden set eval to release CI (tag-triggered)
- Add council self-review via the action (dogfooding)

### Phase 4: Quality Rubric (stretch)
- Cross-model judge prompt
- 5-dimension scoring
- Baseline comparison
- Only on release candidates

---

## Open Questions

1. **Corpus size**: 5 items enough for v1? Or should we aim for 10+ before gating?
2. **Recall threshold**: 0.8 too lenient? 0.9 too strict given LLM non-determinism?
3. **Model drift vs prompt drift**: Should we separate "model changed" from "prompt changed" in regression analysis?
4. **Cost budget**: Full golden set with 5 corpus items = 5 council runs. At ~$0.50/run that's $2.50 per release gate. Acceptable?
