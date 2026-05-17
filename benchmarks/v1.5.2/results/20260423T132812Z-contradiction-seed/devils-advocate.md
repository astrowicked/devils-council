---
persona: devils-advocate
artifact_sha256: 304ef5895a8a1f04329f98f9c0627e1764401b7fa9812d77fb7f6a5ce6a3af88
findings:
- target: '## Proposal'
  claim: 'The plan assumes an unflagged, demo-driven ship is safer than a flagged one — the load-bearing premise is that ''the customer team has already signed off'' substitutes for an internal rollback
    story. The customer cannot sign off on something they will never see: the kill-switch path when the limiter itself breaks the demo.'
  evidence: 'The customer team has already signed off on "ship it on by default."

    '
  ask: Name the premise that makes customer sign-off equivalent to engineering sign-off on a no-flag, no-kill-switch change. If the premise is 'the customer team has authority over risk posture for our
    production middleware,' write it down and defend it. If not, customer sign-off is evidence for the feature being desired, not evidence for the rollout shape being safe.
  severity: blocker
  category: unexamined-framing
- target: '## Context'
  claim: The entire plan rests on the unstated premise that the right fix for a demo 502 is a new middleware rather than raising the tenant's existing soft quota. The artifact identifies a burst from one
    known tenant as the trigger, then proposes a platform-wide hard limiter — skipping the simpler intervention it never names.
  evidence: 'burst requests from

    their internal CI fleet can exceed our per-tenant soft quota and produce

    502s in the live demo.

    '
  ask: Defend why the fix is a new hard limiter rather than raising Acme's soft quota for the demo window. The plan acknowledges a soft quota already exists; if raising it is infeasible (auth path? config
    rollout? tenant isolation?), say so — that is the premise the limiter exists to work around, and it is load-bearing.
  severity: blocker
  category: unexamined-framing
- target: '## Risks'
  claim: The Risks section names a deploy-reset failure mode, then the Approach section explicitly refuses to test for it. The unstated premise is that a risk the team has chosen not to test is somehow
    less real than one it has tested — but the artifact provides no basis for that asymmetry.
  evidence: 'No integration test

    for the deploy-reset behavior (too much setup cost for a one-off

    feature).

    '
  ask: Name the premise that justifies shipping a known, artifact-documented failure mode without a test gate. 'Too much setup cost' is a cost claim, not a risk claim — quantify the setup cost and compare
    it to the cost of the May 14 rehearsal going down, which the artifact itself says is a real scenario.
  severity: major
  category: unexamined-framing
- target: '## Proposal'
  claim: The bucket sizing of 100 req/sec burst / 600 req/min sustained is presented as a default without any defense of where those numbers came from. Every downstream behavior — whether Acme's CI fleet
    triggers 429s, whether other tenants notice — is a consequence of accepting this premise, which the artifact never connects to the observed burst that motivated the work.
  evidence: 'Default bucket: 100 req/sec burst, 600 req/min sustained.

    '
  ask: State the empirical basis for 100/600. Is it above or below the Acme CI burst rate that produced the 502s? If above, the limiter does not fix the demo problem. If below, the limiter will cause the
    demo to 429 instead of 502 — a different failure, not a fix. The artifact cannot be evaluated without this number's provenance.
  severity: major
  category: unexamined-framing
dropped_findings: []
---

## Summary

Four premises hold this plan together and none are defended in the
artifact. First, that customer sign-off authorizes a no-flag no-kill-switch
rollout — a category error substituting product approval for engineering
risk approval. Second, that a new hard limiter is the right fix for a
single tenant's burst when a soft quota for that tenant already exists and
could presumably be raised. Third, that a risk the team named in its own
Risks section becomes less real once the team decides not to test it.
Fourth, that 100/600 are reasonable bucket defaults without any stated
relationship to the Acme CI burst rate that triggered the whole plan —
meaning the limiter could 429 the demo it exists to save. The plan may
still be the right call under time pressure, but the reader has no way to
verify that because the load-bearing premises are unspoken.
