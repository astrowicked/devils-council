---
persona: product-manager
artifact_sha256: 9d9bc13186daa5252f9419fa6469b128e01180490ecb7c3c1e9d7fc783d5bb83
findings:
- target: '## Goal'
  claim: The goal names an adversary ('abusive clients') but no stakeholder — no customer, no incident, no support ticket, no PM, no ticket reference. A 60 req/min cap on a public endpoint is a business
    decision about acceptable partner traffic, not a neutral engineering default, and there is nobody on the hook for that number.
  evidence: 'Protect the `/api/v1/search` endpoint from abusive clients by rate-limiting

    per-IP to 60 requests/min.

    '
  ask: Name the stakeholder who asked for this. Which customer complaint, incident ticket, or cost signal drove 60/min specifically? If the answer is 'nobody asked, we're being proactive', say so in the
    plan and get a PM or on-call lead to sign the number — because today a paying integration partner hitting 61/min gets a 429 and no one in this document owns the resulting support ticket.
  severity: major
  category: business-alignment
  id: product-manager-f4b2c042
- target: '## Rollout'
  claim: The rollout has no owner, no customer-communication plan, and no definition of what 'flip on in prod next week' requires — this is an engineering schedule pretending to be a product decision. A
    public API adding 429s without notice is a contract change for every integration that depends on it.
  evidence: 'Ship behind the flag. Flip on in staging for 24h. Flip on in prod next week.

    '
  ask: Who owns the flip-on decision, and what goes out to `/api/v1/search` consumers before it? Name the comms channel (changelog, email to API keys, status page), the lead time, and the rollback trigger.
    If there is no list of who calls this endpoint, that is the first deliverable — not the token bucket.
  severity: major
  category: business-alignment
  id: product-manager-2cd6e7ff
- target: '## Risks'
  claim: The plan acknowledges that IP-based keying punishes NAT'd corporate clients but treats it as a line-item risk, not a stakeholder question. 'Disproportionately hits corporate clients' is a description
    of which customers will get told no — and nobody in this document is named as having decided that is an acceptable trade.
  evidence: 'IP-based keying hits NAT''d corporate clients disproportionately.

    '
  ask: Which customer segment is this endpoint for, and is 'NAT'd corporate clients' inside or outside that segment? If enterprise customers behind a shared egress are the ones getting 429'd first, the
    product decision is 'we accept losing that segment's throughput to stop abuse' — get that decision signed, or key on API key / account ID instead of IP and delete this risk entirely.
  severity: major
  category: business-alignment
  id: product-manager-25f3f89b
- target: '## Approach'
  claim: 'A `Retry-After: 1` header is a client-contract decision — it tells every SDK and integration partner how to back off. The plan picks the value with no reference to what current clients do on 429,
    whether any SDK retries automatically, or whether 1 second is defensible vs. the refill rate.'
  evidence: 'On exhaustion, return HTTP 429 with a `Retry-After: 1` header.

    '
  ask: 'Who owns the client-side story? Name the SDK maintainer or DX lead who confirms `Retry-After: 1` won''t cause a thundering-herd loop with existing retry logic, and document what a well-behaved client
    is expected to do on 429. Without that, this header is a guess wearing an RFC label.'
  severity: minor
  category: business-alignment
  id: product-manager-b852dedd
dropped_findings: []
---

## Summary

Every decision in this plan has a stakeholder-shaped hole: the 60/min cap has no customer or incident anchor, the rollout has no owner and no comms plan, the NAT'd-corporate-clients risk describes which customers get told no without anyone signing for that trade, and the `Retry-After: 1` header picks a client-contract value with no DX owner. The token bucket itself is fine engineering; the plan around it reads as an engineering team making product decisions for an absent PM and an unnamed customer base. Fix the stakeholder gaps before fixing the code — or the first flip-on in prod writes the support-ticket backlog for Q3.
