---
persona: sre
run_id: 20260516T153219Z-demo-plan
findings:
- id: sre-27846e85
  target: '## Risks & Mitigations'
  claim: The Kafka consumer lag mitigation is literally the string 'Auto-scaling is configured' in quotes — there is no scaling metric, no threshold, no lead time estimate for how many seconds of notification
    delay accumulate before new consumers come online, and no named owner for the alert.
  evidence: 'Kafka consumer lag causes delayed notifications | "Auto-scaling is configured"

    '
  ask: State the consumer lag threshold in seconds that triggers scaling, the time-to-ready for a new consumer instance, and the resulting max notification delay under a 10x spike. At 10,000 msg/sec sustained
    (your success criteria), a 90-second scale-up window is 900,000 queued messages — is that within your 30-second p99 latency SLO or does it blow it?
  severity: blocker
  category: capacity
- id: sre-fc1f08af
  target: '### Task 1: Kafka Consumer with Exactly-Once Processing'
  claim: The plan claims 'Zero duplicate deliveries (exactly-once semantics)' but the mechanism is Redis SET NX with a 24h TTL — if Redis evicts keys under memory pressure or a node restarts within that
    24h window, dedup state is lost and users get duplicate security alerts or billing notifications. This is at-least-once with a dedup cache, not exactly-once, and the failure mode pages nobody.
  evidence: 'Deduplication via Redis SET NX with 24h TTL on event_id

    '
  ask: 'Name the alert that fires when Redis memory exceeds 80% or eviction count spikes. Quantify the blast radius: at 10k msg/sec, how many event_ids are in Redis at steady state (864M keys at 24h TTL),
    and does your Redis sizing actually hold that? If not, the dedup guarantee fails silently.'
  severity: blocker
  category: reliability
- id: sre-7f5620c5
  target: '### Task 6: Multi-Region Active-Active Deployment'
  claim: Cross-region PostgreSQL conflict resolution is described as 'eventually consistent' without naming the conflict resolution strategy (last-write-wins? application-level merge?), the replication
    lag SLO, or what happens when both regions mark the same notification as delivered — which is a duplicate delivery that violates the zero-duplicate success criterion.
  evidence: 'PostgreSQL logical replication with conflict resolution

    '
  ask: Define the conflict resolution rule for delivery_state rows when both regions process the same event during a network partition. Specify the replication lag p99 you're targeting and the alert threshold
    that pages someone when lag exceeds it. 'Eventually consistent' is a CAP theorem property, not a runbook.
  severity: major
  category: reliability
- id: sre-731d5b5b
  target: '### Task 3: Delivery Channels'
  claim: Circuit breaker opens after 5 consecutive failures with a 60s half-open window, but at 14 msg/sec SES rate (your stated limit), 5 failures takes 360ms — meaning a single SES blip opens the circuit
    and drops all email delivery for 60 seconds, which is 840 queued messages. No fallback channel during circuit-open state is specified, no alert fires, and no on-call rotation is named.
  evidence: 'Circuit breaker pattern: open after 5 consecutive failures, half-open after 60s

    '
  ask: What happens to the 840 messages that arrive during the 60s open window — are they queued, dropped, or routed to a fallback? Which PagerDuty service gets the alert when a channel circuit opens? The
    current parameters mean a transient SES 503 response pages nobody but silently drops a minute of notifications.
  severity: major
  category: incident-response
- id: sre-b19db209
  target: '### Task 5: Observability Stack'
  claim: PagerDuty integration fires on DLQ depth > 1000, but at 10,000 msg/sec ingest rate, 1000 messages in the DLQ accumulates in 100ms of a bad deploy. By the time the alert fires and a human responds
    (5-minute MTTA target), the DLQ could hold 3 million messages. The threshold is set for a low-volume system but the success criteria demand a high-volume one.
  evidence: 'PagerDuty integration for DLQ depth > 1000

    '
  ask: Set the alert on DLQ growth rate (messages/sec entering DLQ) rather than absolute depth, so a bad deploy that poisons 100% of traffic pages within seconds, not after 1000 messages have already been
    lost to retry exhaustion. Name the PagerDuty service and escalation policy that owns this alert.
  severity: major
  category: observability
dropped_findings: []
---

## Summary

This plan will page me three ways and I won't have a runbook for any of them. First, the dedup layer is a Redis cache marketed as exactly-once — at the stated throughput of 10k msg/sec, steady-state key count is ~864 million in 24 hours, which will either OOM the Redis cluster or trigger evictions that silently break the zero-duplicate guarantee. Second, the multi-region active-active deployment hand-waves conflict resolution as "eventually consistent" without naming what happens to delivery state during a split-brain, which means duplicate sends and a customer-facing incident with no documented resolution path. Third, the circuit breaker parameters are tuned for a system doing single-digit requests per second — at the actual rate limits in the plan, a transient cloud provider blip opens the circuit and silently drops a minute of traffic with no alert, no fallback, and no named on-call rotation. The capacity story ("auto-scaling is configured") has no numbers behind it and cannot survive a 10x burst without blowing the 30-second p99 SLO.
