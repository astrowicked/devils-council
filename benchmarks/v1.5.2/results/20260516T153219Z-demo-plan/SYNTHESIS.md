# Council Synthesis: Real-Time Notification Service Plan

**Run**: `20260516T153219Z-demo-plan`  
**Artifact**: `templates/demo-plan.md` (plan, 4068 bytes)  
**Personas**: staff-engineer, sre, product-manager, devils-advocate  
**Findings**: 19 kept, 0 dropped  
**Verdict**: ❌ BLOCKED — 3 blocker findings require resolution before execution

---

## Top-3 Blockers

| ID | Persona | Finding |
|----|---------|---------|
| sre-1 | SRE | **"Auto-scaling is configured" is not a mitigation.** No scaling metric, threshold, or lead time. At 10k msg/sec sustained, a 90s scale-up window queues 900K messages — blowing the 30s p99 SLO with no alert and no named owner. |
| sre-2 | SRE | **Redis SET NX dedup is not exactly-once.** At 10k msg/sec, 24h TTL produces ~864M keys. Redis will OOM or evict, silently breaking the zero-duplicate guarantee with no alert for memory pressure. This is at-least-once with a dedup cache, not exactly-once. |
| da-002 | Devil's Advocate | **"Zero duplicate deliveries (exactly-once semantics)" is an indefensible commitment.** No transactional boundary spans Kafka → Redis → external channel → PostgreSQL. A crash between channel send and offset commit produces a duplicate with no mechanism to prevent it. |

---

## Cross-Persona Contradictions

1. **Exactly-once vs. distributed reality**: The plan claims zero duplicates (Success Criteria) while specifying mechanisms (Redis SET NX + manual offset commit) that mathematically cannot guarantee it across the full delivery path. Staff-engineer, SRE, and devils-advocate all independently flagged this — it is the plan's structural lie.

2. **Multi-region as Week 4 vs. 6-month infrastructure project**: Staff-engineer calls it scope creep (1 week allocated), SRE calls it operational hand-waving (no conflict resolution strategy named), product-manager calls it unjustified (no regulatory/market evidence), and devils-advocate attacks the premise that active-active is required at all. Four personas, four angles, one conclusion: Task 6 is premature.

3. **10k msg/sec throughput vs. no load data**: Devils-advocate attacks the premise (no current volume cited), SRE shows the infrastructure can't handle it (Redis sizing, circuit breaker params tuned for low volume), and product-manager notes it's an engineering SLO without user-facing meaning.

---

## Severity Distribution

| Severity | Count | Personas |
|----------|-------|----------|
| blocker  | 3     | sre (2), devils-advocate (1) |
| major    | 13    | staff-engineer (3), sre (3), product-manager (3), devils-advocate (4) |
| minor    | 3     | staff-engineer (1), product-manager (2) |
| nit      | 0     | — |

---

## Per-Persona Summary

### Staff Engineer (5 findings)
Deletes half the template engine (A/B testing, Liquid parser, dependency graph), rejects multi-region as premature scope creep, and declares the 2-week timeline for Tasks 1-3 non-credible. Core message: *this plan builds a platform when the problem statement requires a pipeline*.

### SRE (5 findings)
Two blockers: the dedup guarantee fails silently under load, and the capacity plan is a platitude. The circuit breaker parameters will drop 840 messages on any transient SES blip with no alert. DLQ alerting threshold is meaningless at the stated volume. Core message: *this plan will page me three ways with no runbook for any of them*.

### Product Manager (5 findings)
No ticket, no customer, no product brief anywhere in the plan. The A/B testing framework has no hypothesis or metric owner. Multi-region has no market justification. Success criteria are engineering SLOs, not user outcomes. User-facing behavior changes (quiet hours, channel fallback) ship without a transition owner. Core message: *every decision is an engineering guess wearing a PM label*.

### Devil's Advocate (4 findings)
Four premises attacked: (1) inline sends ARE the latency cause (never proven), (2) exactly-once is achievable (architecturally impossible as designed), (3) 10k msg/sec is a grounded target (no load data cited), (4) active-active is required (no requirement stated that active-passive can't satisfy). Core message: *any one premise failing reshapes scope by ≥30%*.

---

## Recommended Actions (priority order)

1. **Resolve the exactly-once lie** — Either downgrade to "best-effort dedup with <0.01% duplicate rate" (honest) or design a true idempotency layer with transactional delivery receipts (expensive). Do not ship a success criterion the architecture cannot meet.

2. **Cut Task 6 entirely** — Ship single-region. Gate multi-region on production traffic data proving it's needed.

3. **Cut Task 2 to core** — Handlebars from S3 with locale folders. Delete A/B testing, Liquid parser, preview API, dependency graph.

4. **Add load evidence** — Current volume, growth rate, and the math that produces 10k msg/sec as the design point.

5. **Name stakeholders** — A ticket number, a product brief, or an incident that justifies 5 weeks of capacity.

6. **Replace the Risks table** — Each mitigation needs: alert threshold, named responder, and documented behavior when the mechanism itself fails.
