---
persona: sre
artifact_sha256: 9d9bc13186daa5252f9419fa6469b128e01180490ecb7c3c1e9d7fc783d5bb83
findings:
- target: '## Risks'
  claim: Deploy resets every token bucket, so every deploy is an instant free pass for abusers and a mass false-429 event for legitimate clients mid-burst; the plan names the behavior but never quantifies
    the blast radius against the API's error budget.
  evidence: 'In-memory state does not survive restart; limits reset on deploy.

    '
  ask: 'Give me the number: at N active clients/min through /api/v1/search and a rolling-deploy window of T seconds, how many 429s do legitimate clients eat, and how many requests does an abuser get during
    the reset gap? If either exceeds the error-budget burn target, the deploy behavior is a contract violation and needs a shared store before prod flip.'
  severity: major
  category: blast-radius
  id: sre-954b4029
- target: '## Risks'
  claim: '''We run one'' is a deployment topology, not a response plan. Single replica means the limiter process dying takes the endpoint with it (or fails open to unlimited, which is worse); no pager rotation,
    no runbook, no decision on fail-open vs fail-closed is named.'
  evidence: 'Single-node deployment today; no shared counter across replicas (we run one).

    '
  ask: 'Name the pager rotation that owns /api/v1/search and link the runbook for ''limiter process crashed''. Explicitly decide: when the limiter errors, does the request fail open (abuse risk) or fail
    closed (availability hit)? That decision needs to be in the plan, not discovered at 3am.'
  severity: major
  category: observability
  id: sre-9ae3b34c
- target: '## Rollout'
  claim: '''Flip on in prod next week'' is a calendar date, not a rollout. No canary slice, no per-metric rollback trigger, no SLO gate — so the on-call has no automatic signal to flip the flag back off
    when 429s spike on real customers.'
  evidence: 'Ship behind the flag. Flip on in staging for 24h. Flip on in prod next week.

    '
  ask: 'Define the rollback trigger in concrete numbers before flip: what 429 rate, what p95 latency, and what customer-ticket volume auto-pages the on-call and flips RATE_LIMIT_ENABLED=false? A staging
    soak doesn''t catch NAT''d enterprise traffic; prod needs a percentage ramp (1% → 10% → 100%) with a named abort metric.'
  severity: major
  category: rollout
  id: sre-21634f36
- target: '## Approach'
  claim: No telemetry is specified. There's no metric for trips-per-key, no log line with the offending IP/UA, and no way to tell 'abuse' from 'one NAT gateway for a Fortune 500 customer' once the pager
    fires.
  evidence: 'On exhaustion, return HTTP 429 with a `Retry-After: 1` header.

    '
  ask: 'Emit at minimum: a counter `ratelimit.trips{key, route}`, a structured log line per trip with IP+UA+route, and a gauge of distinct keys currently throttled. Without these, the on-call receives ''customer
    says search is broken'' and has no way to distinguish a legit NAT collision from a real attack inside the SLA window.'
  severity: major
  category: observability
  id: sre-35f938c3
- target: '## Risks'
  claim: The NAT collision risk is named but left as a hazard, not a mitigation. A single enterprise customer behind one egress IP will trip 60/min trivially and page us with a 'your API is broken' ticket
    that isn't a bug.
  evidence: 'IP-based keying hits NAT''d corporate clients disproportionately.

    '
  ask: Before prod flip, either (a) key on API-key when present and fall back to IP only for unauthenticated traffic, or (b) publish an allowlist mechanism and the SLA for getting on it. 'We know it hurts
    NAT'd customers' is not a plan — it's a known-bad-outcome shipped on purpose.
  severity: major
  category: correctness
  id: sre-410c01d3
dropped_findings: []
---

## Summary

The plan names three risks in its own Risks section and then ships anyway without mitigations for any of them — the deploy-reset, the single-replica topology, and the NAT collision are each a pager scenario this change creates, not an abstract concern. The rollout is a calendar ("next week") rather than a percentage ramp with a numeric rollback trigger, and the approach specifies the 429 wire format but no telemetry, so when the on-call gets paged they will have no metric to separate an abusive client from a Fortune 500 customer behind one NAT. Fix the observability gap and the rollback trigger before prod flip, and decide fail-open vs fail-closed for the limiter process explicitly; the rest can follow.
