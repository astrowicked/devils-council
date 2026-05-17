---
persona: sre
artifact_sha256: 304ef5895a8a1f04329f98f9c0627e1764401b7fa9812d77fb7f6a5ce6a3af88
findings:
- target: '## Proposal'
  claim: Shipping unflagged with no kill switch means the only rollback from a bad limiter is a revert-and-redeploy, which is the slowest incident path we have. If the bucket math is wrong and Acme's CI
    trips 429s in production, on-call has no toggle — they have to cut a release. That's not a deploy plan, that's a hostage situation.
  evidence: 'No feature flag. No kill switch. No staged rollout. The deploy window is

    the May 7 release train.

    '
  ask: Name the rollback path with a wall-clock number. If on-call gets paged at 2am on May 9 because the limiter is dropping legit traffic, what's the MTTR? If the answer is 'revert PR, rebuild, redeploy'
    that's 30+ minutes of 429s for every tenant — get a flag or a runtime-tunable bucket size in before May 8.
  severity: blocker
  category: blast-radius
- target: '## Risks'
  claim: The author acknowledges a deploy-reset wipes the token buckets and that a bad May 14 deploy takes rehearsal down — then proposes no mitigation and no integration test for that exact failure mode.
    The risk section names the pager scenario and the Approach section refuses to cover it.
  evidence: 'In-memory state does not survive restart; limits reset on deploy. A bad

    deploy at 9am PT on May 14 would not only cause a paging incident — it

    would take the demo rehearsal down.

    '
  ask: 'Pick one: (a) deploy freeze on the API from May 13 00:00 PT through May 15 EOD, owned by release-eng, documented in the on-call runbook; (b) move buckets to Redis/shared store before May 8 so restarts
    don''t reset. ''We noted the risk'' is not a mitigation.'
  severity: blocker
  category: blast-radius
- target: '## Approach'
  claim: Refusing the integration test for the exact failure mode the Risks section calls out ('too much setup cost for a one-off feature') means the first time anyone observes deploy-reset behavior under
    load is during the customer's conference rehearsal. That's the worst possible place to discover the bug.
  evidence: 'No integration test

    for the deploy-reset behavior (too much setup cost for a one-off

    feature).

    '
  ask: Write the integration test. A token-bucket reset across a process restart is a 30-line test with supertest + a restart stub. If the setup cost genuinely exceeds the value, say so with hours — 'too
    much' isn't a budget.
  severity: major
  category: testing
- target: '## Proposal'
  claim: 100 req/sec burst / 600 req/min sustained is asserted with no reference to Acme's actual CI fleet traffic pattern — the same fleet whose burst behavior is the reason this feature exists. If their
    CI peaks at 150/sec the limiter ships the demo failure it was built to prevent.
  evidence: 'Default bucket: 100 req/sec burst, 600 req/min sustained.

    '
  ask: Pull Acme's p50/p95/p99 request rate from the last 30 days of access logs and show the bucket sits above p99 with headroom. Name the metric and the dashboard. Right now the numbers are vibes against
    a $1.2M ARR deadline.
  severity: major
  category: observability
- target: '## Proposal'
  claim: Limiter is the first middleware after auth but there's no mention of emitting per-tenant trip metrics. On May 15, when the demo is live and the on-call phone rings, there's no signal to distinguish
    'Acme is being limited' from 'limiter is broken' from 'API is down' — and the customer is on stage.
  evidence: 'Wire it in `src/api/middleware.ts` as the first middleware after auth.

    '
  ask: Emit `quota.trip{tenant=<id>,bucket=burst|sustained}` and `quota.allow{tenant=<id>}` counters. Pre-build one Grafana panel filtered to Acme's tenant id before May 8. Without it, the May 15 pager
    is blind.
  severity: major
  category: observability
dropped_findings: []
---

## Summary

The Risks section of this plan names the exact scenario that will wake on-call during the customer's conference — a deploy resets the in-memory buckets — and the Approach section then refuses to test for it or mitigate it. That's the contradiction: the author has already identified the failure mode and is shipping anyway, with no flag, no kill switch, no runtime tunable, and no integration test. Combined with a bucket-size number asserted without reference to Acme's actual traffic (the traffic that motivated the feature), this plan is one bad 9am deploy away from a $1.2M ARR incident on stage. At minimum: a deploy freeze owned by release-eng across the rehearsal-and-demo window, a runtime-tunable bucket or flag so MTTR is measured in seconds instead of release-train-minutes, and a tenant-scoped trip metric on a pre-built dashboard so the on-call can tell the difference between "limiter working as designed" and "limiter is the outage" while the customer is live.
