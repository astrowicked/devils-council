# RFC: Background-job queue selection

## Context
We need to run ~50k email-send jobs/day, triggered by user actions and by a
nightly batch. Latency under 2m p99 is acceptable.

## Options considered
1. Redis + BullMQ — simple, runs in our existing Redis cluster.
2. PostgreSQL `LISTEN/NOTIFY` + a custom worker.
3. AWS SQS — managed, pay-per-message.

## Proposal
Go with Redis + BullMQ. Reuses existing infra. Team already knows the stack.

## Open questions
- What happens if Redis fails? (BullMQ has no cross-Redis replication.)
- How do we monitor queue depth and dead-lettered jobs?
- Cost estimate at 50k/day was not computed.
- Retention / PII: email bodies sit in Redis until processed — acceptable?
