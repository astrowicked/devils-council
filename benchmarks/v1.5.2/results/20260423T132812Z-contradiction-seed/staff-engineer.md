---
persona: staff-engineer
artifact_sha256: 304ef5895a8a1f04329f98f9c0627e1764401b7fa9812d77fb7f6a5ce6a3af88
findings:
- target: '## Proposal'
  claim: Shipping unflagged with no kill switch seven days before a revenue-critical demo is the opposite of what the demo constraint demands — you have removed every lever that would let you recover in-flight.
  evidence: 'No feature flag. No kill switch. No staged rollout.

    '
  ask: Land it behind a per-tenant config (off by default, on for Acme) so a bad deploy on May 14 is a config flip, not a rollback train. The 'no configuration step in the demo script' constraint is satisfied
    by pre-flipping the tenant flag, not by removing the flag entirely.
  severity: blocker
  category: correctness
- target: '## Risks'
  claim: The plan names the exact failure mode that kills the demo and then does nothing about it. 'A bad deploy at 9am PT on May 14 would take the demo rehearsal down' is a design requirement, not a risk
    bullet.
  evidence: 'A bad deploy at 9am PT on May 14 would not only cause a paging incident — it

    would take the demo rehearsal down.

    '
  ask: Either freeze deploys from May 13 through May 15 (cheap, boring, effective) or move the bucket state to a shared store so restarts are survivable. Writing the risk down without mitigating it is not
    risk management.
  severity: blocker
  category: correctness
- target: '## Approach'
  claim: The deploy-reset behavior is the one behavior most likely to break the demo, and it is the one behavior you explicitly refuse to test. 'Too much setup cost for a one-off feature' is exactly backwards
    when the feature is shipping unflagged into a $1.2M-ARR demo path.
  evidence: 'No integration test

    for the deploy-reset behavior (too much setup cost for a one-off feature).

    '
  ask: Write the integration test for restart behavior, or change the design so restart behavior is not load-bearing (shared store). Pick one.
  severity: major
  category: testing
- target: '## Proposal'
  claim: Hard limits with values pulled from nowhere. 100 req/sec and 600 req/min are not consistent with each other at sustained load (100/s × 60s = 6000, not 600), and there is no citation of Acme's observed
    CI fleet burst profile.
  evidence: 'Default bucket: 100 req/sec burst, 600 req/min sustained.

    '
  ask: Show the measured burst profile from Acme's dry-run that produced the 502s, and pick limits that (a) are internally consistent and (b) sit above that profile with headroom. Otherwise you will 429
    the demo you are trying to protect.
  severity: blocker
  category: correctness
dropped_findings: []
---

## Summary

The plan diagnoses its own failure mode in the Risks section and then removes every mechanism that would let you respond to it. Unflagged, no kill switch, no staged rollout, no integration test for the exact restart behavior called out as demo-killing, and rate-limit numbers that do not even multiply out consistently — all seven days before a $1.2M-ARR demo. The fastest path to the stated goal is the opposite of what is written: flag it on per-tenant, freeze deploys around the demo window, and produce the burst measurement that justifies the bucket sizing.
