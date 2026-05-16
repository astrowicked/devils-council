---
description: "Run a devils-council review against a built-in flawed plan — see all personas in action in 60 seconds, no project setup needed."
---

## Setup

Write the demo plan to a temp file and invoke the review pipeline against it.

!`set -e
DEMO_DIR="/tmp/devils-council-demo-$$"
mkdir -p "$DEMO_DIR"
cat > "$DEMO_DIR/PLAN.md" << 'DEMO_EOF'
# Plan: Real-Time Notification Service

## Context

Our platform needs a notification service to alert users about account events (password changes, billing updates, security alerts). Currently notifications are sent inline during API request handling, causing p99 latency spikes.

## Approach

Build a microservice that receives notification events via Kafka, renders templates, and delivers via email (SES), SMS (Twilio), push (FCM), and Slack webhook.

## Architecture

API servers → Kafka topic (notifications.v1) → Notification Service → Delivery channels
                                                      ↓
                                              PostgreSQL (delivery state)
                                              Redis (dedup + rate limit)
                                              S3 (template storage)
                                              Vault (channel credentials)

## Implementation

### Task 1: Kafka Consumer with Exactly-Once Processing

- Consumer group with manual offset commit
- Deduplication via Redis SET NX with 24h TTL on event_id
- Dead letter queue for poison messages after 3 retries
- Partition key: user_id (ordering guarantee per user)

### Task 2: Template Engine

- Handlebars templates stored in S3 with versioning
- Template compilation cache in Redis (invalidated on S3 event notification)
- Support for i18n via per-locale template variants
- Liquid fallback parser for legacy templates
- Markdown-to-HTML conversion pipeline with sanitization
- Custom Handlebars helpers for date formatting, currency, pluralization
- Template preview API with mock data injection
- A/B testing framework for template variants with statistical significance tracking
- Template dependency graph for cascade invalidation

### Task 3: Delivery Channels

- Channel-specific rate limiting (SES: 14/sec, Twilio: 1/sec per number)
- Retry with exponential backoff per channel
- Circuit breaker pattern: open after 5 consecutive failures, half-open after 60s
- Delivery receipts stored in PostgreSQL for audit

### Task 4: User Preferences & Quiet Hours

- Preferences stored in PostgreSQL with 5-minute TTL Redis cache
- Quiet hours enforcement (user timezone-aware)
- Channel preference fallback chain: push → email → SMS
- Do-not-disturb override for security-critical notifications

### Task 5: Observability Stack

- OpenTelemetry traces for full delivery lifecycle
- Prometheus metrics: delivery_total, delivery_latency_seconds, dlq_depth
- Grafana dashboards with per-channel SLO tracking
- PagerDuty integration for DLQ depth > 1000

### Task 6: Multi-Region Active-Active Deployment

- Deploy to us-east-1 and eu-west-1 simultaneously
- Kafka MirrorMaker 2 for cross-region replication
- PostgreSQL logical replication with conflict resolution
- Route53 latency-based routing for template API
- Redis Cluster with cross-region replication via Redis Enterprise

## Security

- All credentials fetched from Vault at startup (AppRole auth)
- TLS 1.3 for all inter-service communication
- PII fields encrypted at rest in PostgreSQL using application-level encryption
- Template injection prevention via Handlebars strict mode

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Kafka consumer lag causes delayed notifications | "Auto-scaling is configured" |
| Template rendering failures | "The circuit breaker handles this" |
| Cross-region data consistency | "PostgreSQL logical replication is eventually consistent" |
| Cost overrun from SMS channel | "Rate limiting prevents this" |
| Credential rotation during delivery | "Vault handles credential rotation automatically" |

## Timeline

- Week 1-2: Tasks 1-3 (core pipeline)
- Week 3: Tasks 4-5 (preferences + observability)
- Week 4: Task 6 (multi-region)
- Week 5: Load testing and hardening

## Success Criteria

- p99 delivery latency < 30 seconds for email
- Zero duplicate deliveries (exactly-once semantics)
- 99.95% delivery success rate across all channels
- Support 10,000 notifications/second sustained throughput
DEMO_EOF
echo "DEMO_ARTIFACT=$DEMO_DIR/PLAN.md"
echo ""
echo "=== Devils Council Demo ==="
echo "Reviewing a deliberately flawed notification service plan..."
echo ""
echo "This plan contains:"
echo "  - Over-engineering (Task 2: A/B testing framework for a notification service)"
echo "  - Circular risk mitigations ('auto-scaling is configured' is not an answer)"
echo "  - Missing operational details (no runbook, no rollback plan)"
echo "  - Unjustified scope (multi-region active-active for notifications?)"
echo ""
echo "Watch how each persona catches different issues."
echo ""`

## Run the review

Invoke `/devils-council:review $DEMO_DIR/PLAN.md --type=plan`

The `$DEMO_DIR` value was printed above as `DEMO_ARTIFACT=...`. Use that exact path.

## After review completes

Print this summary:

```
=== Demo Complete ===

The council found issues that would have shipped without review:
- Staff Engineer caught over-engineering (template A/B framework, multi-region for notifications)
- SRE caught hand-wavy mitigations ("auto-scaling is configured" isn't a real answer)
- Product Manager caught scope creep with no business case
- Devil's Advocate caught circular reasoning in the risk table

To run this on YOUR plans:
  /devils-council:review path/to/your/PLAN.md
  /devils-council:on-plan <phase-number>     (for GSD/speckit projects)
  /devils-council:on-code <phase-number>     (for code diffs)

Output lives in .council/<timestamp>-<slug>/ with per-persona scorecards + SYNTHESIS.md
If python3 is available, an HTML report is also generated at REPORT.html
```

## Cleanup

!`rm -r "/tmp/devils-council-demo-"* 2>/dev/null || true`
