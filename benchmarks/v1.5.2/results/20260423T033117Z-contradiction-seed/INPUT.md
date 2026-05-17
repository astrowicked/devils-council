---
title: Quota Limiter — Customer Demo Ship
status: proposal
audience: eng-team
---

# PLAN: Quota Limiter for Customer Demo

## Context

Our top-three paying tenant (Acme Corp, $1.2M ARR) has committed to
showcasing our platform at their Q2 partner conference on May 15. Their
onboarding team identified a blocker during dry-run: burst requests from
their internal CI fleet can exceed our per-tenant soft quota and produce
502s in the live demo. The demo script cannot include a "wait for the
rate-limit to reset" step.

## Proposal

Ship a per-tenant hard quota limiter in front of the API. Land it
**unflagged** by May 8 (one-week buffer before the demo) so the demo
script does not include a configuration step. The customer team has
already signed off on "ship it on by default."

Implementation sketch:

- Add `src/quota/limiter.ts` with an in-memory token bucket keyed by tenant id.
- Wire it in `src/api/middleware.ts` as the first middleware after auth.
- Default bucket: 100 req/sec burst, 600 req/min sustained.
- Exceeded: return 429 with `Retry-After` header.

No feature flag. No kill switch. No staged rollout. The deploy window is
the May 7 release train.

## Risks

In-memory state does not survive restart; limits reset on deploy. A bad
deploy at 9am PT on May 14 would not only cause a paging incident — it
would take the demo rehearsal down.

## Approach

Single PR. Unit tests for the token-bucket math. No integration test
for the deploy-reset behavior (too much setup cost for a one-off
feature). Ship behind the regular CI gate.
