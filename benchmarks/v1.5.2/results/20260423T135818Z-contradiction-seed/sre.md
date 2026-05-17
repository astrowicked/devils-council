---
persona: sre
artifact_sha256: 304ef5895a8a1f04329f98f9c0627e1764401b7fa9812d77fb7f6a5ce6a3af88
findings:
- target: '## Proposal'
  claim: Shipping a first-middleware-after-auth limiter unflagged with no kill switch means the only remediation for a bad bucket default is a revert-and-redeploy — and the demo rehearsal is May 14, so
    your mean-time-to-recover is bounded by how fast you can cut a new release train, not by how fast you can flip a toggle.
  evidence: 'No feature flag. No kill switch. No staged rollout. The deploy window is

    the May 7 release train.

    '
  ask: Name the rollback procedure and its wall-clock ETA. If 'revert the PR and redeploy' is the answer, state that explicitly and compare it to Acme's tolerance window on May 14 9am PT. If MTTR exceeds
    the demo-rehearsal blast radius, add a runtime kill switch (env var, config flag, anything that does not require a redeploy) before May 8.
  severity: blocker
  category: blast-radius
- target: '## Risks'
  claim: The artifact already names the worst-case pager scenario — deploy-resets-state on May 14 — and then refuses to quantify it. How many tenants trip the bucket during warm-up? What is Acme's steady-state
    req/sec against the 100/sec burst? Without those two numbers, the author has not actually assessed the risk they surfaced.
  evidence: 'In-memory state does not survive restart; limits reset on deploy. A bad

    deploy at 9am PT on May 14 would not only cause a paging incident — it

    would take the demo rehearsal down.

    '
  ask: 'Put numbers on it: Acme''s observed p95 req/sec from CI fleet, count of other tenants sharing the process, expected 429 rate in the first 60s after restart. Then decide whether the May 7 → May 15
    window can absorb a second restart. If the answer is ''we freeze deploys May 13–15'', write that into the plan as the actual mitigation.'
  severity: blocker
  category: blast-radius
- target: '## Approach'
  claim: The one failure mode the author already identified — deploy-reset behavior — is also the one explicitly excluded from integration tests. That is not a test-cost decision; that is shipping the known-broken
    path untested into the week of a $1.2M customer demo.
  evidence: 'No integration test

    for the deploy-reset behavior (too much setup cost for a one-off

    feature).

    '
  ask: 'Write the one integration test: start limiter, burn tokens to 429, restart process, assert behavior matches spec (either tokens reset cleanly or persist — pick one and test it). ''Too much setup
    cost'' for the single highest-blast-radius behavior on a customer-demo ship is a pager scenario, not an engineering trade-off.'
  severity: major
  category: testing
- target: '## Proposal'
  claim: A hard 429 on the first middleware after auth means any limiter bug — miscounted tokens, tenant-id collision, clock skew in the bucket math — presents to Acme as 'your API rejected my CI fleet'
    during their partner conference. There is no mention of which rotation owns this code path or what the runbook is when Acme's ops pages us mid-keynote.
  evidence: 'Wire it in `src/api/middleware.ts` as the first middleware after auth.

    '
  ask: Name the on-call rotation that owns src/api/middleware.ts, link the runbook for 'tenant reports spurious 429s', and confirm the rotation is staffed May 15 during the conference window. If the runbook
    does not exist, write it before May 8 — not after the first page.
  severity: major
  category: observability
- target: '## Proposal'
  claim: 100 req/sec burst / 600 req/min sustained is asserted without reference to Acme's measured traffic. If their CI fleet's dry-run burst was the trigger for this whole plan, the plan should cite that
    number and show headroom. Otherwise the default is a guess that could trip the exact demo it is meant to protect.
  evidence: 'Default bucket: 100 req/sec burst, 600 req/min sustained.

    '
  ask: Cite the measured peak req/sec from Acme's dry-run and show the margin against 100/sec. If Acme's own burst exceeds the default, the plan ships a 429 into the demo it was written to prevent.
  severity: major
  category: blast-radius
dropped_findings: []
---

## Summary

The artifact identifies its own worst pager scenario in the Risks
section — deploy resets limiter state, a bad May 14 deploy nukes the
rehearsal — and then systematically removes every mitigation that would
contain it: no flag, no kill switch, no staged rollout, and explicitly
no integration test for the deploy-reset path. The default bucket
numbers are asserted without reference to Acme's measured traffic, even
though Acme's burst behavior is the stated reason the limiter exists.
This is not an operational plan; it is a plan whose author has already
written the postmortem's first paragraph and chosen not to read it. The
fixes are small and cheap: a runtime kill switch, one integration test,
and a sentence citing Acme's measured peak against the 100/sec default.
