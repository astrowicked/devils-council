# Phase 7: Integration UAT + Release - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-29
**Phase:** 07-integration-uat-release
**Areas discussed:** Real-artifact target, 9-bench budget-cap scenario, Release documentation, Tech debt closeout audit

---

## Real-Artifact Target

| Option | Description | Selected |
|--------|-------------|----------|
| anaconda-platform-chart Helm chart | Rich signal surface — Helm values, KOTS config, container images, cloud resources | ✓ |
| outerbounds-data-plane | Alternative infrastructure artifact | |
| Synthetic fixture | Purpose-built artifact triggering all signals | |
| You decide | Claude picks based on signal coverage | |

**User's choice:** anaconda-platform-chart Helm chart
**Notes:** Most relevant to user's day job; naturally triggers Air-Gap, Dual-Deploy, FinOps signals.

| Option | Description | Selected |
|--------|-------------|----------|
| Committed fixture | Representative chart snapshot as test fixture. Reproducible in CI. | ✓ |
| Live chart from disk | Actual chart directory. Most realistic but not CI-reproducible. | |

**User's choice:** Committed fixture
**Notes:** Reproducibility in CI and avoiding proprietary content were deciding factors.

---

## 9-Bench Budget-Cap Scenario

| Option | Description | Selected |
|--------|-------------|----------|
| Extend existing test-budget-cap.sh | Add 6th scenario. Consistent with existing pattern. | ✓ |
| Separate test file | New scripts/test-9bench-budget-cap.sh. Cleaner isolation. | |
| You decide | Claude picks based on test conventions. | |

**User's choice:** Extend existing test-budget-cap.sh
**Notes:** Keeps all budget-cap tests in one file, avoids duplicating harness scaffolding.

---

## Release Documentation

| Option | Description | Selected |
|--------|-------------|----------|
| Standard release | Move [Unreleased] to [1.1.0], GitHub Release with auto-generated notes + highlights, annotated tag | ✓ |
| Detailed release notes | Handcrafted GitHub Release body with sections per feature area | |
| You decide | Claude picks based on v1.0.x precedent | |

**User's choice:** Standard release
**Notes:** Matches v1.0.x release pattern.

| Option | Description | Selected |
|--------|-------------|----------|
| Feature-grouped | Group under: New Personas, Scaffolder, Codex Schema, Tech Debt | ✓ |
| Keep individual bullets | Move existing bullets as-is | |
| You decide | Claude picks based on CHANGELOG style | |

**User's choice:** Feature-grouped
**Notes:** Easier to scan for users adopting v1.1.

---

## Tech Debt Closeout Audit

| Option | Description | Selected |
|--------|-------------|----------|
| Trust existing checkmarks | Each verified during respective phase. Release just documents them. | ✓ |
| Re-verify each TD | Quick spot-check per TD. Higher confidence. | |

**User's choice:** Trust existing checkmarks
**Notes:** All 7 TDs resolved per REQUIREMENTS.md; no re-verification needed.

---

## Claude's Discretion

- Fixture content details
- Blinded-reader evaluation methodology
- CI preflight step ordering
- GitHub Release body formatting

## Deferred Ideas

None
