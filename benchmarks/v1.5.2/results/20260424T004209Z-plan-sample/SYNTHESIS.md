## Contradictions

- **Staff Engineer** (staff-engineer-436d5544): «The flag has one consumer, one environment, and a stated flip date a week away. It is scaffolding for a rollback you will not execute; delete it and rely on revert.»
  **SRE** (sre-21634f36): «'Flip on in prod next week' is a calendar date, not a rollout. No canary slice, no per-metric rollback trigger, no SLO gate — so the on-call has no automatic signal to flip the flag back off when 429s spike on real customers.»
  *Tension:* Staff Eng wants the flag deleted as scaffolding for a rollback the team will not execute; SRE wants the flag kept and load-bears on it as the on-call's automatic abort lever. The disagreement is about whether `RATE_LIMIT_ENABLED` is YAGNI or the primary safety mechanism — and the plan picks one posture without naming the trade.

- **Product Manager** (product-manager-25f3f89b): «The plan acknowledges that IP-based keying punishes NAT'd corporate clients but treats it as a line-item risk, not a stakeholder question. 'Disproportionately hits corporate clients' is a description of which customers will get told no — and nobody in this document is named as having decided that is an acceptable trade.»
  **SRE** (sre-410c01d3): «The NAT collision risk is named but left as a hazard, not a mitigation. A single enterprise customer behind one egress IP will trip 60/min trivially and page us with a 'your API is broken' ticket that isn't a bug.»
  *Tension:* PM wants a named stakeholder to sign the "we lose NAT'd corporate throughput to stop abuse" trade; SRE wants the trade eliminated by keying on API-key when present and falling back to IP only for unauthenticated traffic. PM's ask presumes the trade is real and owned; SRE's ask presumes the trade is an artifact of the wrong key function. Both cannot be the right next step.

- **Staff Engineer** (staff-engineer-fdc865a1): «A 24-hour staging bake cannot exercise 60 req/min/IP traffic unless staging has production-shaped clients. The bake produces a green light with zero signal.»
  **SRE** (sre-21634f36): «'Flip on in prod next week' is a calendar date, not a rollout. No canary slice, no per-metric rollback trigger, no SLO gate — so the on-call has no automatic signal to flip the flag back off when 429s spike on real customers.»
  *Tension:* Staff Eng's fix is to shorten or skip the staging bake and go to a prod canary in logging-only mode; SRE's fix is to keep staging but add a percentage ramp (1% → 10% → 100%) in prod with a named abort metric. Both agree the current rollout is broken; they disagree on whether staging is salvageable or should be abandoned for a prod canary.

## Top-3 Blocking Concerns

1. **SRE** (sre-35f938c3): No telemetry is specified — no trips-per-key counter, no structured log line with offending IP/UA, no gauge of distinct throttled keys — so when the pager fires the on-call cannot distinguish a NAT collision from an actual attack. Candidate: `## Approach` is raised by four personas (staff-engineer-2dd2c7b9, sre-35f938c3, staff-engineer-436d5544, product-manager-b852dedd).

2. **SRE** (sre-410c01d3): IP-keying will page the team with a "your API is broken" ticket from a single enterprise customer behind a shared egress on day one, and no mitigation (API-key keying, allowlist) is in the plan. Candidate: `## Risks` target is raised by four personas (staff-engineer-5a5cd587, sre-410c01d3, product-manager-25f3f89b, devils-advocate-fb0e206d).

3. **Devil's Advocate** (devils-advocate-67888b9e): The number 60 req/min is never sourced — not from p99 of current traffic, a product contract, a competitor's published limit, or an incident. Every downstream choice (bucket size, refill, `Retry-After`) is a mechanical consequence of accepting a guess. Candidate: `## Goal` target is raised by two personas (product-manager-f4b2c042, devils-advocate-67888b9e + devils-advocate-a11a52bd).

## Agreements

- All four personas converge on `## Risks` — the Risks section names real hazards (deploy-reset, single-node, NAT collision) and ships without mitigations for any of them. (staff-engineer-5a5cd587, sre-410c01d3, product-manager-25f3f89b, devils-advocate-fb0e206d)
- **Staff Engineer** (staff-engineer-5a5cd587) and **SRE** (sre-410c01d3) agree the NAT-collision mitigation must land before prod flip — either allowlist, logging-only warmup, or re-key on API-key. Severity band: major for both.
- **Product Manager** (product-manager-f4b2c042) and **Devil's Advocate** (devils-advocate-67888b9e) agree the 60 req/min threshold has no source — PM frames it as a missing stakeholder signoff, Devil's Advocate frames it as an unexamined premise; same gap, two vocabularies.
- **Staff Engineer** (staff-engineer-fdc865a1), **SRE** (sre-21634f36), and **Product Manager** (product-manager-2cd6e7ff) all flag the rollout as under-specified — missing abort metric (SRE), missing bake signal (Staff Eng), missing owner and comms (PM).

## Also Raised

- staff-engineer: `## Approach` — staff-engineer-2dd2c7b9 — major (bucket=60 + refill=1/s is the same number by accident, not by design)
- staff-engineer: `## Risks` — staff-engineer-24603748 — minor (`Retry-After: 1` coaches abusive clients into a tight poll loop at the limit)
- sre: `## Risks` — sre-954b4029 — major (deploy resets every bucket; blast radius vs error budget unquantified)
- sre: `## Risks` — sre-9ae3b34c — major (single replica; no fail-open vs fail-closed decision, no runbook, no pager rotation named)
- product-manager: `## Rollout` — product-manager-2cd6e7ff — major (no owner, no customer-comms plan for a public-API contract change)
- product-manager: `## Approach` — product-manager-b852dedd — minor (`Retry-After: 1` is a client-contract decision with no DX owner)
- devils-advocate: `## Goal` — devils-advocate-a11a52bd — major (threat model asserted as "abuse" without evidence; wrong driver would reshape the design)
- devils-advocate: `## Risks` — devils-advocate-fb0e206d — major (single-node premise is load-bearing; the first second replica silently doubles the limit to 120/min)

## Raw Scorecards

- [staff-engineer.md](./staff-engineer.md)
- [sre.md](./sre.md)
- [product-manager.md](./product-manager.md)
- [devils-advocate.md](./devils-advocate.md)
