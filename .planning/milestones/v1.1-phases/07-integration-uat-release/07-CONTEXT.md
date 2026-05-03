# Phase 7: Integration UAT + Release - Context

**Gathered:** 2026-04-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Validate the full 16-persona roster (4 core + 10 bench + Chair + classifier) under real-artifact conditions, cut the v1.1.0 release after all CI and UAT gates pass.

</domain>

<decisions>
## Implementation Decisions

### Real-Artifact UAT Target
- **D-01:** Use `anaconda-platform-chart` as the review artifact — rich signal surface (Helm values, KOTS config, container images, cloud resources) that naturally triggers Air-Gap, Dual-Deploy, FinOps.
- **D-02:** Committed fixture (not live chart from disk) — create a representative chart snapshot in `tests/fixtures/` for reproducibility in CI and to avoid proprietary content.
- **D-03:** Fixture must trigger enough signals to activate 9+ bench personas simultaneously so budget-cap enforcement can be observed.

### 9-Bench Budget-Cap Scenario
- **D-04:** Extend existing `scripts/test-budget-cap.sh` with a 6th scenario (all 9 bench signals fire simultaneously). Keep all budget-cap tests in one file, consistent with existing pre-baked classifier fixture pattern.
- **D-05:** The 6th scenario asserts: top-6 selection by `bench_priority_order`, at least 3 personas skipped with `reason: budget_cap` correctly rendered.

### Release Documentation
- **D-06:** Standard release flow — move `[Unreleased]` to `[1.1.0]` with date, annotated git tag, GitHub Release with auto-generated notes + curated highlights.
- **D-07:** CHANGELOG entries consolidated into feature-grouped sections: New Personas, Scaffolder, Codex Schema (WRAPPER verdict), Tech Debt Closeouts. Easier to scan than individual bullets.
- **D-08:** Plugin version bump `1.0.2` → `1.1.0` in `plugin.json` and `marketplace.json`.

### Tech Debt Closeout
- **D-09:** Trust existing REQUIREMENTS.md checkmarks for TD-01 through TD-07. Each was verified during its respective phase. Release plan documents them in CHANGELOG without re-verification.

### Claude's Discretion
- Fixture content details (specific Helm values, container image references, signal-triggering patterns)
- Blinded-reader evaluation methodology (LLM-as-judge prompt, scoring rubric)
- CI preflight step ordering and matrix configuration
- GitHub Release body formatting

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Test Infrastructure
- `scripts/test-budget-cap.sh` — Existing 5-scenario budget-cap test harness (extend with 6th)
- `scripts/test-blinded-reader.sh` — Blinded-reader structural readiness test
- `tests/fixtures/bench-personas/` — Existing classifier fixture directory

### Release Artifacts
- `CHANGELOG.md` — Current [Unreleased] section with v1.1 entries
- `.claude-plugin/plugin.json` — Plugin manifest (version to bump)
- `.claude-plugin/marketplace.json` — Marketplace catalog (version to bump)
- `README.md` — May need badge update from v1.0.0 to v1.1.0

### Prior Phase Outputs
- `.planning/phases/02-codex-output-schema-spike/02-01-SUMMARY.md` — WRAPPER verdict (for CHANGELOG documentation)
- `.planning/REQUIREMENTS.md` — TD-01 through TD-07 closeout evidence

### CI Pipeline
- `.github/workflows/ci.yml` — Current CI matrix (verify all steps pass on release candidate)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/test-budget-cap.sh` — Established harness pattern with pre-baked fixtures; extend rather than rewrite
- `scripts/test-blinded-reader.sh` — Structural readiness already verified; need to add actual LLM-as-judge evaluation
- `tests/fixtures/bench-personas/budget-classifier-*.json` — Pre-baked classifier output fixtures for budget tests

### Established Patterns
- CI runs the full test matrix on every push; release candidate just needs all steps green
- v1.0.x releases used annotated tags + GitHub Releases with Keep a Changelog format
- Budget-cap tests use deterministic fixtures (no live LLM calls in CI)

### Integration Points
- `bin/dc-budget-plan.sh` — Budget planner invoked by the review engine; test harness exercises this
- `commands/review.md` — Entry point that orchestrates the full review; real-artifact UAT exercises this end-to-end
- `config.json` `bench_priority_order` — Determines which 6 of 9 personas are selected under cap

</code_context>

<specifics>
## Specific Ideas

- The fixture chart should be synthetic but realistic — modeled on anaconda-platform-chart patterns (Helm values with image references, kots config, cloud resource definitions)
- Blinded-reader evaluation should achieve ≥80% persona-attribution accuracy (PQUAL-03 target)
- Release notes should explicitly call out the WRAPPER verdict and what it means for Codex integration

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-integration-uat-release*
*Context gathered: 2026-04-29*
