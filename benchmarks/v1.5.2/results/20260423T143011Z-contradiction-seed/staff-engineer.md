---
persona: staff-engineer
artifact_sha256: 304ef5895a8a1f04329f98f9c0627e1764401b7fa9812d77fb7f6a5ce6a3af88
findings:
- target: '## Proposal'
  claim: The customer problem is bursts exceeding quota and getting 502s; the fix ships a hard limiter that returns 429s. That swaps one rejection code for another — the CI fleet bursts still fail, the
    demo still breaks. The plan does not solve the stated problem.
  evidence: 'burst requests from

    their internal CI fleet can exceed our per-tenant soft quota and produce

    502s in the live demo.

    '
  ask: 'Name the actual failure: is the 502 a capacity/backpressure bug upstream of the soft quota, or is the CI fleet genuinely over budget? If it''s the former, fix the 502 path and leave quota alone.
    If it''s the latter, raise Acme''s quota for the demo window and stop pretending a new limiter is the answer.'
  severity: blocker
  category: correctness
  id: staff-engineer-ea32b314
- target: '## Proposal'
  claim: Default bucket numbers are pulled from thin air. The plan never states Acme's measured burst rate, so 100 req/sec could be twice what they need or half. Shipping a hard cap without that number
    means the demo fails in a new way on May 15.
  evidence: 'Default bucket: 100 req/sec burst, 600 req/min sustained.

    '
  ask: Put Acme's observed p99 burst from the dry-run in the plan. If the limiter's ceiling isn't above that number with margin, the limiter causes the outage it's meant to prevent.
  severity: blocker
  category: correctness
  id: staff-engineer-1ced53ad
- target: '## Proposal'
  claim: No flag, no kill switch, no staged rollout for a change that sits in the hot path of every authenticated request, one week before a $1.2M-ARR demo. The Risks section itself describes the May 14
    failure mode — and the Approach offers nothing to contain it.
  evidence: 'No feature flag. No kill switch. No staged rollout.

    '
  ask: Add one env-var kill switch that bypasses the middleware. That is the smallest thing that lets you turn this off at 9:15am PT on May 14 without a redeploy. Everything else can stay as sketched.
  severity: blocker
  category: operability
  id: staff-engineer-1d7f23fe
- target: '## Approach'
  claim: The Risks section names deploy-reset as the paging scenario. The Approach then explicitly skips the one test that would catch it, citing setup cost for 'a one-off feature' — but the plan just shipped
    this to production unflagged, so it is not a one-off, it is load-bearing.
  evidence: 'No integration test

    for the deploy-reset behavior (too much setup cost for a one-off

    feature).

    '
  ask: Either write the restart test, or move the bucket to a shared store (Redis) so the reset stops being a risk. Skipping both is choosing the failure.
  severity: major
  category: correctness
  id: staff-engineer-0f3c9cf3
- target: '## Risks'
  claim: The Risks section identifies a specific, dated, demo-killing scenario and then stops. No mitigation, no owner, no rehearsal plan — just acknowledgment. That is not risk management, that is a disclaimer.
  evidence: 'A bad

    deploy at 9am PT on May 14 would not only cause a paging incident — it

    would take the demo rehearsal down.

    '
  ask: Freeze deploys from May 13 00:00 PT through May 15 EOD, name the on-call who holds the kill switch, and write down the rollback command. If you won't do those three things, the risk is unowned.
  severity: major
  category: operability
  id: staff-engineer-58208cb4
dropped_findings: []
---

## Summary

The plan has a load-bearing contradiction at its core: the customer reports 502s from burst traffic, and the proposed fix is a hard limiter that returns 429s on burst traffic. Nothing in the Implementation sketch closes that gap, and the bucket defaults are asserted without a single number from Acme's dry-run. Until that's reconciled, the rest of the design — flag, kill switch, tests, deploy window — is argument over the color of a car with no engine.

The operational posture is the second problem. Shipping unflagged, with no kill switch, with an explicit acknowledgment in the Risks section that a bad May 14 deploy takes the demo rehearsal down, and then skipping the integration test that would catch that exact failure — that is a sequence of choices that each make the next one worse. One env-var bypass and a deploy freeze from May 13 would cost a day and neutralize most of it.

