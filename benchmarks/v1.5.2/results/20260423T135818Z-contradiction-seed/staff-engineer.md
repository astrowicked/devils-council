---
persona: staff-engineer
artifact_sha256: 304ef5895a8a1f04329f98f9c0627e1764401b7fa9812d77fb7f6a5ce6a3af88
findings:
- target: '## Proposal'
  claim: 'The plan ships a hard limiter unflagged with no kill switch, then names a failure mode that the flag would have covered. Pick one: either the rollback path exists, or the demo is the rollback
    path.'
  evidence: 'No feature flag. No kill switch. No staged rollout.

    '
  ask: Add a per-tenant bypass (env var or config entry keyed by tenant id) so a bad deploy on May 14 is a config flip, not a redeploy. The flag is not speculative generality — it is the rollback path for
    the exact risk you already wrote down.
  severity: blocker
  category: correctness
- target: '## Risks'
  claim: You identified that a deploy resets limits and takes the rehearsal down, then proposed zero mitigation. Naming a risk is not the same as addressing it.
  evidence: 'A bad deploy at 9am PT on May 14 would not only cause a paging incident — it

    would take the demo rehearsal down.

    '
  ask: Either freeze deploys from May 13 through May 15 in writing, or move the limiter state out of process (Redis/shared store) so a restart does not drop the enforcement. State which.
  severity: major
  category: correctness
- target: '## Approach'
  claim: The one risk you named is deploy-reset behavior; the one test you refuse to write is for deploy-reset behavior. The test cost is the feature cost.
  evidence: 'No integration test

    for the deploy-reset behavior (too much setup cost for a one-off

    feature).

    '
  ask: Write the restart test. If the limiter is worth shipping to protect a $1.2M ARR demo, it is worth one integration test covering the failure mode you already flagged.
  severity: major
  category: testing
- target: '## Proposal'
  claim: A 100 req/sec burst cap is a number pulled from nowhere. The customer problem is 'CI fleet exceeds soft quota' — you have no stated measurement of what their CI fleet actually sends.
  evidence: 'Default bucket: 100 req/sec burst, 600 req/min sustained.

    '
  ask: Cite the observed peak from Acme's CI traffic (logs, metrics, anything) and show the headroom. If you do not have that number, you are guessing at the value that determines whether the demo 429s
    live on stage.
  severity: major
  category: correctness
- target: '## Proposal'
  claim: In-memory token bucket keyed by tenant id does not survive horizontal scale either — two API pods means a tenant gets 2x the stated limit, silently.
  evidence: 'Add `src/quota/limiter.ts` with an in-memory token bucket keyed by tenant id.

    '
  ask: State the replica count for the API tier. If it is greater than one, the per-tenant limit in this plan is a lie; move to a shared counter or document that the real limit is N x stated.
  severity: major
  category: correctness
dropped_findings: []
---

## Summary

The plan contradicts itself in two places. It names deploy-reset as the headline risk, then refuses the integration test that would catch it and refuses the kill switch that would recover from it. It claims a per-tenant limit while proposing in-memory state that breaks under either restart or horizontal scale. The 100 req/sec number is unsourced for a change whose whole job is to not 429 a live demo. Either the limiter is a one-week throwaway for one customer — in which case write it as a hardcoded allowlist bypass and skip the middleware — or it is a real quota system, in which case it needs shared state, a flag, and the restart test.
