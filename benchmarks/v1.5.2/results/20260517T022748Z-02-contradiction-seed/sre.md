---
persona: sre
findings:
- target: '## Proposal'
  claim: No feature flag, no kill switch, no staged rollout means a bad token-bucket configuration pages every on-call simultaneously because the only remediation is a full rollback of the entire release
    train. The plan acknowledges restart resets state but refuses the kill switch that would let you survive a restart without losing the limiter entirely.
  evidence: 'No feature flag. No kill switch. No staged rollout. The deploy window is the May 7 release train.

    '
  ask: What's the MTTR for a full release-train rollback vs. flipping a flag? If the rollback takes >5 minutes and the limiter is rejecting legitimate traffic from all tenants, that's 5 minutes × N tenants
    × their request rate in hard 429s.
  severity: blocker
  category: blast-radius
  id: sre-3824a252
- target: '## Risks'
  claim: 'The plan acknowledges deploy-reset as a risk and then explicitly skips testing it. This is the exact code path that will page someone on May 14: a hotfix deploy resets all buckets, CI fleet burst-fills
    them instantly, and the limiter starts 429ing the demo presenter mid-slide.'
  evidence: 'In-memory state does not survive restart; limits reset on deploy.

    '
  ask: 'Name the specific failure mode: after a deploy, how many seconds until a tenant with a CI fleet re-saturates the fresh bucket? If the answer is <10s, the reset behavior is operationally identical
    to ''limiter is off for 10s then slams on'' — which is worse than no limiter at all for a demo audience watching live.'
  severity: major
  category: blast-radius
  id: sre-8fd25368
- target: '## Risks'
  claim: In-memory state on a single release train with no canary means the limiter is either working for all tenants or broken for all tenants. There's no mention of which pager rotation owns this code
    path, what the runbook is when the limiter misfires, or how to distinguish 'limiter is correctly rejecting abuse' from 'limiter is incorrectly rejecting the $1.2M demo.'
  evidence: 'A bad deploy at 9am PT on May 14 would not only cause a paging incident

    '
  ask: Who gets paged when 429 rate crosses a threshold? What's the alert definition? And how does the on-call know in 30 seconds whether the 429s are intended rate-limiting or a misconfigured bucket?
  severity: major
  category: blast-radius
  id: sre-b2a44152
dropped_findings: []
---

## Summary

This plan ships a hard rate limiter with no kill switch to protect a $1.2M customer demo — and then identifies the exact deploy-reset scenario that would destroy that demo, without mitigating it. The MTTR without a feature flag is a full release-train rollback (5-10 minutes of hard 429s for all tenants). That's the pager scenario: not the limiter working, but the limiter breaking and having no off switch.
