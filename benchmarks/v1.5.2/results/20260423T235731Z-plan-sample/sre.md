---
persona: sre
artifact_sha256: 9d9bc13186daa5252f9419fa6469b128e01180490ecb7c3c1e9d7fc783d5bb83
findings:
- target: '## Risks'
  claim: Deploy-time reset of the token bucket means every deploy grants every client a fresh 60-token burst — an attacker who notices the deploy cadence can time abuse to the restart window. No blast-radius
    math, no estimate of how many minutes of unthrottled traffic per deploy, no SLO impact analysis.
  evidence: 'In-memory state does not survive restart; limits reset on deploy.

    '
  ask: 'Quantify the reset window: at your deploy frequency, what''s the expected per-day unthrottled-minute count on /api/v1/search? If that exceeds the endpoint''s error-budget burn target, in-memory
    state is a correctness violation, not a footnote. Either persist bucket state (Redis) or document the accepted burn.'
  severity: major
  category: blast-radius
  id: sre-f3de581a
- target: '## Risks'
  claim: '''We run one'' is a deploy topology masquerading as a response plan. When that single node''s process dies or the host is cordoned, 100% of /api/v1/search traffic is down — but the plan names
    no pager rotation, no runbook, no recovery SLO, and no trigger for ''stop accepting single-node as acceptable.'''
  evidence: 'Single-node deployment today; no shared counter across replicas (we run one).

    '
  ask: 'Before flipping the flag in prod, answer three questions in writing: (1) which rotation gets paged when the process dies, (2) what''s the linked runbook URL for restart, (3) at what traffic or revenue
    threshold do we revisit the single-node assumption? Without these, the rate limiter is adding a failure mode to a system that already has no HA story.'
  severity: major
  category: observability
  id: sre-d92ea456
- target: '## Approach'
  claim: '429 with Retry-After: 1 and no telemetry means the on-call cannot distinguish ''NAT''d corporate customer tripped the limit'' from ''actual abuser hammering the endpoint'' from ''legitimate traffic
    spike from a launch.'' The first pages the wrong team, the third is a customer-impact incident masquerading as a successful limiter.'
  evidence: 'On exhaustion, return HTTP 429 with a `Retry-After: 1` header.

    '
  ask: 'Emit three counters before the flag flips: ratelimit.trip{reason=bucket_exhausted, ip_class=[nat_suspected|residential|cloud], ua_family=...}, top-N tripped-IP cardinality (capped), and trip-rate-per-minute.
    Wire a dashboard and a burn-rate alert. Without these, the first 429 page at 3am is a blind investigation.'
  severity: major
  category: observability
  id: sre-31fcd0f9
- target: '## Rollout'
  claim: '''Flip on in staging for 24h. Flip on in prod next week'' has no rollback trigger, no success criteria, and no canary. ''It didn''t page anyone in staging'' is not evidence the production traffic
    distribution won''t trip legitimate users — staging traffic is almost never shaped like prod''s NAT''d enterprise egress.'
  evidence: 'Ship behind the flag. Flip on in staging for 24h. Flip on in prod next week.

    '
  ask: 'Define the rollout gate: what 429-rate on staging counts as green? What''s the prod canary — 1% of traffic for an hour? What metric triggers automatic flag-off (e.g., 429 rate > X% sustained for
    Y minutes)? Who owns the decision to proceed from canary to 100%?'
  severity: major
  category: rollout
  id: sre-3ad451bd
- target: '## Approach'
  claim: 'Retry-After: 1 with a bucket that refills 1 token/second creates a thundering-herd retry storm — every throttled client retries in lockstep at T+1s and either all succeed (limiter was pointless
    for that second) or all re-trip (amplifying load). The plan has no jitter and no backoff guidance.'
  evidence: 'On exhaustion, return HTTP 429 with a `Retry-After: 1` header.

    '
  ask: Either randomize Retry-After over a small range (1-5s) to spread retries, or document why synchronized retries are acceptable for this endpoint's downstream dependencies. This is the difference between
    a limiter that smooths load and one that creates a 1Hz square wave.
  severity: minor
  category: blast-radius
  id: sre-8a71287f
dropped_findings: []
---

## Summary

The plan describes a mechanism, not an operational story. The three risks listed are correctly identified — deploy-reset, single-node, NAT-hit — but each is a one-liner where a pager scenario should be. I need the blast-radius math on the deploy-reset window, a named rotation and runbook for the single-node failure mode, and telemetry that lets the on-call distinguish NAT trips from abuse from launch spikes before the flag flips. The rollout plan ("flip on in staging for 24h... flip on in prod next week") has no success criteria, no canary, and no automatic rollback trigger; that's not a rollout, that's a hope. Fix the observability and rollout gates before touching prod — otherwise the first 429 page at 3am is a blind investigation into a system with no HA story.

