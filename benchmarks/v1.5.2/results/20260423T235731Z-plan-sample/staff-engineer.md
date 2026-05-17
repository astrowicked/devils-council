---
persona: staff-engineer
artifact_sha256: 9d9bc13186daa5252f9419fa6469b128e01180490ecb7c3c1e9d7fc783d5bb83
findings:
- target: '## Approach'
  claim: The feature flag buys nothing here. One endpoint, one knob, single-node deploy, and a staged flip — the flag is a config surface you will delete in a week.
  evidence: 'Feature-flag via `RATE_LIMIT_ENABLED=true`.

    '
  ask: Drop the flag. If you need a kill switch, set the per-minute ceiling to a config value and ship it unflagged; a zero or very-high value is the off switch.
  severity: minor
  category: complexity
  id: staff-engineer-ce982fb6
- target: '## Risks'
  claim: You listed 'limits reset on deploy' as a risk and then kept walking. For a 60/min bucket, a deploy-time reset is a free bypass for any attacker who can trigger or observe a restart — that's a limiter
    you cannot rely on.
  evidence: 'In-memory state does not survive restart; limits reset on deploy.

    '
  ask: Either state explicitly that the threat model tolerates reset-on-deploy (and why 60/min still matters after that bypass), or move the counter to a shared store before shipping. Don't ship a security
    control whose failure mode is undocumented.
  severity: major
  category: correctness
  id: staff-engineer-0fb002b1
- target: '## Approach'
  claim: Bucket size 60 with 1 token/sec refill is not 'per-IP to 60 requests/min' — it is a burst of 60 followed by a strict 1 rps ceiling. The Goal and the Approach describe two different limiters.
  evidence: 'Bucket size 60, refill 1 token/second.

    '
  ask: Pick the contract you actually want. If it's 60/min rolling, size and refill should reflect that; if it's 1 rps with a 60-burst, say so in the Goal so on-call and clients are not surprised.
  severity: major
  category: correctness
  id: staff-engineer-a511ff1a
- target: '## Approach'
  claim: '`Retry-After: 1` is a lie when the bucket is fully drained — a client that obeys it and retries after 1s gets exactly one token and then 429s again. You are telling clients to hammer you.'
  evidence: 'On exhaustion, return HTTP 429 with a `Retry-After: 1` header.

    '
  ask: Compute Retry-After from the bucket state (seconds until N tokens are available for the client's expected call pattern), or at minimum return a value large enough that a compliant client backs off
    meaningfully.
  severity: major
  category: correctness
  id: staff-engineer-94b2cf44
- target: '## Risks'
  claim: '''We run one'' is a deploy fact, not a design constraint — the moment you add a second replica (autoscale, blue/green, canary), the limiter silently doubles. This is the exact shape of a control
    that works until it matters.'
  evidence: 'Single-node deployment today; no shared counter across replicas (we run one).

    '
  ask: 'State the assumption as a guardrail: either block horizontal scale-out until the counter moves to a shared store, or pick Redis/equivalent now. Don''t leave ''we run one'' as the load-bearing assumption.'
  severity: major
  category: correctness
  id: staff-engineer-0f25ad54
- target: '## Rollout'
  claim: No rollback plan, no observability gate, no abuse-traffic baseline — 'flip on in prod next week' is a calendar, not a rollout.
  evidence: 'Ship behind the flag. Flip on in staging for 24h. Flip on in prod next week.

    '
  ask: 'Before the prod flip, define: what 429-rate is ''working'' vs ''broken'', what dashboard/alert you are watching, and the one-command rollback. Staging traffic will not tell you whether the 60/min
    threshold is right for real clients.'
  severity: minor
  category: operability
  id: staff-engineer-74c0e579
dropped_findings: []
---

## Summary

The plan has three real holes stacked on each other: the stated 60/min goal does not match the 60-burst + 1 rps bucket, the `Retry-After: 1` tells compliant clients to retry into a guaranteed 429, and the limiter's correctness rests on "we run one replica" — a deploy fact, not an invariant. Any one of those turns this from a rate limiter into a footgun. The feature flag is noise; the rollout is a date rather than a gate. Fix the contract, fix the Retry-After math, and either own the single-replica assumption in writing or move the counter to a shared store before the prod flip.
