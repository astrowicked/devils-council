# Case Study: Plumbing Without Water

> A 4-plan phase that built all the tooling infrastructure but never proved it worked end-to-end — caught by the Product Manager asking "what actually ships?"

## The Plan (excerpt)

A container image pipeline needed to add vendor image support (third-party images like Redis, Prometheus, Kafka). The phase had 4 plans:

1. **Plan 01:** Discovery script — scan the org for vendor image references
2. **Plan 02:** Validation pipeline — add vendor-specific scanning rules
3. **Plan 03:** Allowlist governance — reporting for exceptions and stale entries
4. **Plan 04:** Drift detection — alert when upstream vendors publish new versions

All four plans built tooling. None of them actually onboarded a single vendor image.

## What the Council Found

### Product Manager: No plan delivers a real outcome

> **Finding (BLOCKER):** All 4 plans build tooling (discovery script, validation, allowlist reporting, drift detection) but no plan commits a real `images/<vendor>/manifest.yaml`. The phase delivers plumbing without flowing water through it. The downstream phase (Kyverno enforcement) can't validate anything until at least one vendor image exists in the golden registry.

### Staff Engineer: Classic "build the framework, forget the feature"

> **Finding (HIGH):** The plans exhibit a common anti-pattern: building generic infrastructure without a concrete instance to validate it. Discovery that finds 294 images but onboards zero is a tooling exercise, not a delivery.

### The fix applied

Added a concrete deliverable to Plan 02: "At minimum, onboard `redis` as `images/redis/manifest.yaml` with `build_type: vendor`, scan it, promote it to `golden/redis` in ECR. This proves the path end-to-end before Phase 08 depends on it."

## Impact

Without this catch, the team would have spent 2 weeks building tooling, declared the phase "done," then discovered during the next phase that the tooling didn't actually work with real vendor images (different auth patterns, different tag conventions, different registry behaviors). The discovery-to-fix cycle would have added another week.

**Time to find:** 48 seconds  
**What it prevented:** A "Phase 08 is blocked because Phase 07's tooling doesn't actually work" situation 2 weeks later.
