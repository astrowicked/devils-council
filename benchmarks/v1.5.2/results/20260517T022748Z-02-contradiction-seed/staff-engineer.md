---
persona: staff-engineer
findings:
- target: '## Proposal'
  claim: The plan explicitly refuses a kill switch while simultaneously identifying a scenario (bad deploy on May 14) where the only remediation is a rollback-and-redeploy — which is a kill switch with
    a 10-minute MTTR instead of a 10-second one. This is speculative risk acceptance for a feature that serves one customer's demo.
  evidence: 'No feature flag. No kill switch. No staged rollout.

    '
  ask: Add an env-var kill switch (`QUOTA_LIMITER_DISABLED=true`) that costs four lines of code and gives you a sub-second recovery path on demo day without a full deploy.
  severity: major
  category: correctness
  id: staff-engineer-ae1b058d
- target: '## Risks'
  claim: 'The Risks section names the exact failure mode that would destroy the demo — state loss on deploy — and then the Approach section explicitly declines to test it. The plan contradicts itself: it
    acknowledges the risk is real and then treats mitigation as too expensive.'
  evidence: 'No integration test for the deploy-reset behavior (too much setup cost for a one-off feature).

    '
  ask: Write a 20-line integration test that restarts the process and asserts the bucket refills. If that's genuinely too expensive, delete the Risks section — you're documenting a risk you've chosen to
    ignore, which is worse than silence.
  severity: major
  category: correctness
  id: staff-engineer-8a0853eb
- target: '## Proposal'
  claim: An in-memory token bucket in a multi-instance deployment means each pod gets its own counter. A tenant hitting two pods gets 2× the stated limit. The plan does not mention instance count or sticky
    routing — this is speculative generality applied as permanent middleware for all tenants when one caller needs it.
  evidence: 'Add `src/quota/limiter.ts` with an in-memory token bucket keyed by tenant id.

    '
  ask: State how many instances serve this path. If more than one, either use Redis/shared state or document that the effective limit is `N × 100 req/sec` and confirm Acme's CI fleet cannot exceed that.
  severity: major
  category: correctness
  id: staff-engineer-20edf4a6
dropped_findings: []
---

## Summary

The plan has one structural contradiction: it identifies deploy-time state loss as the scenario that would kill the demo, then declines both a kill switch and an integration test for that exact scenario. The "No kill switch" stance costs nothing to reverse and would be the difference between a 10-second recovery and a 10-minute deploy cycle during a live customer event.
