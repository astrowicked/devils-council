---
persona: sre
findings:
- target: '## Open questions'
  claim: Redis failure is listed as an open question but the RFC proposes shipping on the existing Redis cluster without naming what happens to the 50k jobs in flight — are they lost, retried, or duplicated?
    The answer determines whether a Redis restart during the nightly batch is a data-loss incident or a transient delay.
  evidence: 'What happens if Redis fails? (BullMQ has no cross-Redis replication.)

    '
  ask: 'Quantify the blast radius: at peak nightly batch, how many jobs are in-flight in Redis memory? If Redis restarts with AOF fsync=everysec, you lose up to 1 second of writes — is that 0 jobs or 500?
    That number decides whether you need a persistence guarantee or just idempotent retry.'
  severity: minor
  category: blast-radius
  id: sre-146a85d3
- target: '## Open questions'
  claim: Queue-depth and dead-letter monitoring is flagged as open, but without naming who gets paged when dead-letter count crosses a threshold. 50k jobs/day means a stuck consumer can dead-letter hundreds
    of jobs per minute — if nobody is watching, the customer notices (emails stop arriving) before the on-call does.
  evidence: 'How do we monitor queue depth and dead-lettered jobs?

    '
  ask: 'Define the alert: dead-letter count > N in 5 minutes pages the owning rotation. Pick N from your SLO — if p99 latency is 2 minutes, a dead-lettered job was already late. Name the rotation before
    shipping.'
  severity: minor
  category: observability
  id: sre-4dc47414
dropped_findings: []
---

## Summary

The RFC is operationally sound for a 50k/day workload. The two open questions about Redis failure and monitoring are legitimate and already acknowledged — the gap is that neither has an owner or a threshold defined. These are minor concerns that should be resolved before shipping, not blockers on the technology choice itself.
