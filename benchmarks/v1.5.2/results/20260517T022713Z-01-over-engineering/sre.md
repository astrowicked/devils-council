---
persona: sre
findings:
- target: '## Risks & Mitigations'
  claim: Kafka consumer lag mitigation is 'Auto-scaling is configured' — but auto-scaling has a cold-start window (new consumers joining the group trigger a rebalance that pauses ALL partitions for 30-90s).
    During that rebalance, lag grows worse, not better. There's no number for how many seconds of lag triggers scale-out, no cap on notification age before discard, and no alert for 'lag exceeds SLO-breach
    threshold'.
  evidence: 'Kafka consumer lag causes delayed notifications | "Auto-scaling is configured"

    '
  ask: What's the rebalance-stall duration for a new consumer joining? At 10k msg/sec ingest, a 60s rebalance adds 600k messages of lag. If the SLO is p99 <30s delivery, what lag depth in seconds triggers
    the page, and what does the on-call do — scale out (making it worse short-term) or wait?
  severity: major
  category: blast-radius
  id: sre-fd8f840f
- target: '## Risks & Mitigations'
  claim: Template rendering failure mitigation is 'The circuit breaker handles this' — but the circuit breaker (Task 3) is on delivery channels, not on the template engine. If rendering fails, what happens
    to the message? It either gets DLQ'd (losing notifications) or retried in a loop (wasting compute). No fallback rendering path is defined.
  evidence: 'Template rendering failures | "The circuit breaker handles this"

    '
  ask: 'Name the degraded-mode behavior when template rendering fails: does the user get a plaintext fallback, does the notification queue behind a retry, or does it DLQ and the user never gets alerted
    about a security event? If it DLQs, a security-critical notification (password change) is silently lost.'
  severity: blocker
  category: blast-radius
  id: sre-931f4bd5
- target: '### Task 6: Multi-Region Active-Active Deployment'
  claim: 'Multi-region active-active with Kafka MirrorMaker 2 and PostgreSQL logical replication means both regions consume and deliver the same notification. There is no dedup coordination across regions
    — the Redis SET NX dedup in Task 1 is per-region (Redis Cluster replication is async). Result: user gets duplicate notifications during normal operation, violating the ''Zero duplicate deliveries''
    success criterion.'
  evidence: 'Redis Cluster with cross-region replication via Redis Enterprise

    '
  ask: If region A consumes event E and sets dedup key in its Redis, and region B consumes the mirrored copy of E before async replication propagates the key — the user gets two emails. At what replication
    lag (ms) does this become a guaranteed duplicate, and what's your measured p99 for Redis Enterprise cross-region sync?
  severity: major
  category: blast-radius
  id: sre-db6ee0b3
- target: '## Risks & Mitigations'
  claim: Credential rotation mitigation is 'Vault handles credential rotation automatically' — Vault rotates secrets in its store, but running consumers hold in-memory copies of SES/Twilio credentials.
    Without a lease-expiry refresh loop or a sidecar agent, the consumer uses revoked credentials until restart.
  evidence: 'Credential rotation during delivery | "Vault handles credential rotation automatically"

    '
  ask: How does a running consumer learn that its Twilio credential was rotated? If the answer is 'restart,' what's the blast radius in queued notifications during the restart window?
  severity: minor
  category: blast-radius
  id: sre-f407e165
dropped_findings: []
---

## Summary

The operational story has one structural hole: multi-region active-active contradicts the exactly-once success criterion because Redis dedup is per-region with async replication. The risk mitigations are all hand-waves that name the tool but not the mechanism. Template rendering failure is the sharpest pager scenario — a bad template deploy silently loses security-critical notifications to the DLQ with no fallback path.
