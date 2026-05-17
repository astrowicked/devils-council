---
persona: staff-engineer
artifact_sha256: 9d9bc13186daa5252f9419fa6469b128e01180490ecb7c3c1e9d7fc783d5bb83
findings:
- target: '## Approach'
  claim: The flag has one consumer, one environment, and a stated flip date a week away. It is scaffolding for a rollback you will not execute; delete it and rely on revert.
  evidence: 'Feature-flag via `RATE_LIMIT_ENABLED=true`.

    '
  ask: Drop the flag. If you need a kill switch, wire it to the same config that already controls the endpoint — do not introduce a new env var for one limiter.
  severity: minor
  category: complexity
  id: staff-engineer-436d5544
- target: '## Rollout'
  claim: A 24-hour staging bake cannot exercise 60 req/min/IP traffic unless staging has production-shaped clients. The bake produces a green light with zero signal.
  evidence: 'Ship behind the flag. Flip on in staging for 24h. Flip on in prod next week.

    '
  ask: Name the specific signal the staging bake is supposed to produce (429 rate, false-positive IPs, latency delta) and how you will generate it. Otherwise shorten the bake and go straight to a prod canary
    with logging-only mode.
  severity: major
  category: correctness
  id: staff-engineer-fdc865a1
- target: '## Risks'
  claim: The plan acknowledges the corporate-NAT problem but does nothing about it. A 60-req/min cap on a shared egress IP will brick a single office within minutes of flip-on.
  evidence: 'IP-based keying hits NAT''d corporate clients disproportionately.

    '
  ask: Either add an allowlist for known partner/corporate egress ranges before flip, or start in logging-only mode and flip enforcement on only after you have seen the 429 distribution by IP.
  severity: major
  category: correctness
  id: staff-engineer-5a5cd587
- target: '## Approach'
  claim: Bucket=60 with refill=1/s means the steady-state cap is 60/min AND the burst cap is 60 — a client hitting the endpoint once per second forever never trips the limit. The stated goal and the stated
    math are the same number by accident, not by design.
  evidence: 'Bucket size 60, refill 1 token/second.

    '
  ask: State the threat you are defending against (scrapers? credential stuffing? cost?) and pick burst and refill separately. If 60/min is the real ceiling, refill should be lower than 1/s or the bucket
    smaller than 60.
  severity: major
  category: correctness
  id: staff-engineer-2dd2c7b9
- target: '## Risks'
  claim: '`Retry-After: 1` tells a misbehaving client to retry in one second, which is exactly when the next token refills — you are coaching abusive clients into a tight poll loop that stays right at the
    limit.'
  evidence: 'On exhaustion, return HTTP 429 with a `Retry-After: 1` header.

    '
  ask: Set `Retry-After` to a value that forces real backoff (seconds-to-full-bucket, or a fixed 30–60s), not the refill interval.
  severity: minor
  category: correctness
  id: staff-engineer-24603748
dropped_findings: []
---

## Summary

The plan has two real holes and one piece of theater. The theater is the feature flag — one consumer, one environment, a flip date already on the calendar. The holes are the math (bucket=60 and refill=1/s do not enforce 60/min the way the goal implies) and the NAT risk that is named but not mitigated. The staging bake is also load-bearing in the rollout narrative without a stated signal it is supposed to produce. Fix the math, decide what to do about corporate NAT before flip (allowlist or log-only), and either give the bake a measurable exit criterion or skip it.
