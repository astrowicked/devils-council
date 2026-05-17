---
persona: sre
artifact_sha256: 304ef5895a8a1f04329f98f9c0627e1764401b7fa9812d77fb7f6a5ce6a3af88
findings:
- target: '## Proposal'
  claim: Shipping this unflagged with no kill switch means when the limiter mis-calibrates the on-call has no lever to disable it short of a rollback — and the rollback itself restarts the process, resetting
    every bucket and paging the customer during their demo.
  evidence: 'No feature flag. No kill switch. No staged rollout. The deploy window is

    the May 7 release train.

    '
  ask: Give me a runtime kill switch (env var or config reload) that disables the limiter without a deploy. Name the on-call rotation that owns this middleware and link the runbook for 'limiter is 429'ing
    Acme's CI fleet at 14:55 on May 15'. Without that lever, the blast radius of a bad default is the demo itself.
  severity: blocker
  category: blast-radius
  id: sre-3826bc38
- target: '## Proposal'
  claim: 100 req/sec burst / 600 req/min sustained is quoted with no evidence that Acme's CI fleet stays under it — and the artifact says their CI is what caused the original 502s. Ship day is also 7 days
    before the demo, so a miscalibration surfaces as a pager during rehearsal at best, during live demo at worst.
  evidence: 'burst requests from

    their internal CI fleet can exceed our per-tenant soft quota and produce

    502s in the live demo.

    '
  ask: Before May 7, replay 24–72h of Acme's production request log against the token bucket offline and report the 429 rate. If more than 0.1% of legitimate traffic would trip, the defaults are wrong.
    'Customer team signed off on ship it on by default' is not load data.
  severity: blocker
  category: blast-radius
  id: sre-0c1f9c85
- target: '## Risks'
  claim: The artifact names the exact 3am scenario — deploy at 9am PT on May 14 nukes the buckets — and then proposes no integration test for it. The author has identified the pager event and declined to
    cover it.
  evidence: 'No integration test

    for the deploy-reset behavior (too much setup cost for a one-off

    feature).

    '
  ask: Freeze deploys to this service from May 13 00:00 PT through May 15 23:59 PT and publish the freeze in the release channel. If the freeze is unacceptable, then the integration test is not optional
    — pick one. 'Too much setup cost' for a control that protects a $1.2M ARR demo is not a tradeoff I accept.
  severity: blocker
  category: release-safety
  id: sre-bbff619a
- target: '## Proposal'
  claim: In-memory per-tenant state means every replica has its own bucket; a tenant hitting N replicas gets N× the advertised quota, and a replica restart silently widens that further. The artifact treats
    the limiter as a single counter but doesn't say how many replicas the API runs on.
  evidence: 'Add `src/quota/limiter.ts` with an in-memory token bucket keyed by tenant id.

    '
  ask: State the replica count in front of this middleware and compute the real effective burst (replicas × 100 rps). If that number is not what you want to enforce, either pin to a single replica for this
    tenant or move the counter to Redis before May 7. Don't ship a limit whose actual value depends on autoscaler decisions.
  severity: major
  category: correctness
  id: sre-8d4dcfdf
- target: '## Proposal'
  claim: 429 with Retry-After is the right response shape, but there's no mention of what metric/log the on-call greps at 14:55 on May 15 to distinguish 'Acme tripped the limit' from 'the limiter is broken
    and 429ing everyone'. Without that signal the pager has no runbook.
  evidence: 'Exceeded: return 429 with `Retry-After` header.

    '
  ask: 'Emit two counters before ship: `quota.429.tenant_id=<id>` and `quota.bucket.tokens_remaining{tenant_id}`. Put a dashboard panel on the demo-day war-room board. If we can''t tell a legitimate throttle
    from a bug in under 60 seconds, the limiter is not demo-safe.'
  severity: major
  category: observability
  id: sre-8ff4e232
dropped_findings: []
---

## Summary

The author has handed me the 3am scenario in writing — "a bad deploy at 9am PT on May 14 would take the demo rehearsal down" — and then declined to cover it with a test, a flag, a kill switch, or a deploy freeze. That is the whole review. The token-bucket math is fine; the release posture around a $1.2M ARR live-on-stage customer is not. Before this ships on May 7 I need: a runtime disable lever, a replay of Acme's real traffic against the proposed defaults, a named on-call rotation with a runbook, and either an integration test for the deploy-reset behavior or a hard deploy freeze May 13–15. The unit tests on token-bucket arithmetic are the least interesting thing in the plan.
