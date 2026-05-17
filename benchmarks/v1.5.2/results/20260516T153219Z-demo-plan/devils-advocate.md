---
persona: devils-advocate
run_id: 20260516T153219Z-demo-plan
findings:
- id: devils-advocate-5d0941e1
  target: '## Context'
  claim: The Context section asserts that inline notification sending causes p99 latency spikes, but never defends the premise that the notification path is the latency source — it could be database writes,
    third-party API calls, or lock contention in the request handler that happen to correlate with notification sends.
  evidence: 'Currently notifications are sent inline during API request handling, causing p99 latency spikes.

    '
  ask: What evidence exists that the notification code path is the cause of the latency spikes rather than a correlated symptom? Has anyone produced a flame graph or trace breakdown showing that notification
    delivery (vs. the surrounding request logic) accounts for the observed p99 increase? If the answer is 'we assume so because removing notifications fixes it,' that is a different intervention than building
    Kafka infrastructure.
  severity: major
  category: unstated-premise
- id: devils-advocate-b77563c8
  target: '## Success Criteria'
  claim: The plan commits to zero duplicate deliveries via exactly-once semantics, but this assumes exactly-once is achievable across a distributed pipeline spanning Kafka, Redis, PostgreSQL, and four external
    delivery channels — none of which offer transactional guarantees with each other.
  evidence: 'Zero duplicate deliveries (exactly-once semantics)

    '
  ask: Name the mechanism that provides exactly-once across the full delivery path — from Kafka consumer through Redis dedup through external channel API call through PostgreSQL state write. Redis SET NX
    with 24h TTL is at-most-once dedup for the consumer stage; it does not prevent a delivery channel from receiving the same HTTP request twice if the service crashes after sending but before committing
    offset. Is this criterion achievable, or is it an aspirational restatement of 'best-effort dedup' that the team will silently downgrade during implementation?
  severity: blocker
  category: unstated-premise
- id: devils-advocate-8cb0f0b5
  target: '## Success Criteria'
  claim: The plan requires 10,000 notifications/second sustained throughput but never defends this number against any current or projected load measurement — every architectural choice (Kafka, multi-region,
    auto-scaling) is sized to serve a number that may be 100x the actual requirement.
  evidence: 'Support 10,000 notifications/second sustained throughput

    '
  ask: What is the current notification volume? What is the growth projection that produces 10,000/sec as the design point? If the current peak is 50/sec with 20% monthly growth, this target is years away
    and the infrastructure built to serve it (Kafka, multi-region active-active, Redis Cluster) is premature. If no load data exists, who chose this number and what did they base it on?
  severity: major
  category: unstated-premise
- id: devils-advocate-23499d56
  target: '### Task 6: Multi-Region Active-Active Deployment'
  claim: Task 6 assumes multi-region active-active is a requirement for a notification service, but the artifact never states a latency, compliance, or availability need that single-region with a passive
    failover could not satisfy — the entire task (and its attendant complexity in cross-region Kafka replication, PostgreSQL conflict resolution, and Redis Enterprise) rests on this undefended premise.
  evidence: 'Kafka MirrorMaker 2 for cross-region replication

    '
  ask: What failure scenario or regulatory requirement demands active-active rather than active-passive? If the answer is 'we want low-latency template API serving in EU,' that is a CDN problem, not a dual-region
    Kafka replication problem. If the answer is 'DR with <5min RTO,' active-passive with automated failover achieves that without cross-region conflict resolution. Name the specific requirement that only
    active-active satisfies.
  severity: major
  category: architectural-assumption
dropped_findings: []
---

## Summary

Four premises hold this plan together without defense: that inline notification sending (not something else in the request path) causes the latency spikes; that exactly-once delivery is achievable across a pipeline with no shared transactional boundary; that 10,000 msg/sec is a grounded throughput target rather than a round number someone typed; and that multi-region active-active is required rather than merely impressive. The first determines whether building Kafka infrastructure is the right intervention at all. The second determines whether the primary success criterion is a lie the team will quietly reclassify during load testing. The third and fourth together determine whether half the system's complexity (Task 6 in its entirety, plus the scaling architecture) is justified by actual load or is engineering for a future that no one has measured. None of these are defended in the artifact; any one failing reshapes the plan's scope by at least 30%.
