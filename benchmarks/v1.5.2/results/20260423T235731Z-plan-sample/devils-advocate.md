---
persona: devils-advocate
artifact_sha256: 9d9bc13186daa5252f9419fa6469b128e01180490ecb7c3c1e9d7fc783d5bb83
findings:
- target: '## Goal'
  claim: The Goal treats `abusive clients` as a known, defined threat that per-IP rate-limiting is the right answer to — but the artifact never characterizes who the abusive clients actually are (scrapers?
    credential-stuffers? a single misconfigured partner? LLM crawlers?), and the entire plan is calibrated to that undefined adversary. Different abuser profiles demand different defenses; the plan cannot
    be evaluated until the adversary is named.
  evidence: 'Protect the `/api/v1/search` endpoint from abusive clients by rate-limiting

    '
  ask: Name the specific abuse pattern this plan is responding to. Is it a real incident with logs, a theoretical concern, or a compliance check-box? If the answer is 'we have not seen abuse yet but want
    to be proactive', write that down — it reframes the plan from incident response to defense-in-depth, and a token-bucket is a weak tool against a motivated adversary but fine against accidental misuse.
  severity: major
  category: unexamined-framing
  id: devils-advocate-295fe71d
- target: '## Approach'
  claim: 'The Approach posits `60 requests/min` as though the number is self-evident. The artifact cites no traffic data, no p99 baseline, no partner contract, no industry reference. Every parameter downstream
    (bucket size 60, refill 1/s, Retry-After: 1) is a mechanical restatement of that unsourced number — if 60 is wrong, the entire configuration is wrong in lockstep.'
  evidence: 'per-IP to 60 requests/min.

    '
  ask: Cite the source of 60. If it came from observed legitimate p99 traffic, say so and link the data. If it is a guess, call it a guess and commit to measuring real traffic in staging before flipping
    in prod. The 24h staging soak in Rollout does not accomplish this unless someone is explicitly watching the reject rate against legitimate-user baselines.
  severity: major
  category: unexamined-framing
  id: devils-advocate-a6bab7c9
- target: '## Risks'
  claim: The Risks section lists three operational quirks of the chosen implementation but is silent on the premise that justifies building this in-process at all. The second bullet mentions `we run one`
    node almost in passing — that single parenthetical is the load-bearing assumption for the whole approach being viable, and it is stated as present-tense fact with no defense of how long it will hold.
  evidence: 'Single-node deployment today; no shared counter across replicas (we run one).

    '
  ask: How long does `we run one` remain true? If the service is scaling to multiple replicas inside the next two quarters, this rate-limiter ships broken on the day of that scale-up — limits become per-replica,
    effective ceiling becomes N*60, and the feature silently stops doing what its Goal section promises. Either commit to replacing the in-memory bucket with a shared counter before horizontal scaling,
    or defend why horizontal scaling is not on the roadmap.
  severity: major
  category: unexamined-framing
  id: devils-advocate-b557630a
- target: '## Risks'
  claim: The third risk bullet acknowledges that NAT'd corporate clients are hit disproportionately but treats it as a footnote. The premise the plan never defends is that `req.ip` is a meaningful identity
    for rate-limiting at all — a single corporate NAT, a mobile carrier CGNAT, or a cloud egress pool can represent thousands of legitimate users behind one IP, which means the 60/min limit is not really
    'per user' or even 'per client', it is 'per network boundary'.
  evidence: 'IP-based keying hits NAT''d corporate clients disproportionately.

    '
  ask: 'Defend `req.ip` as the rate-limit key against at least one alternative: API key, authenticated user ID, or an IP+UA composite. If the answer is ''the endpoint is unauthenticated so we have no better
    key'', say so — that makes the NAT problem a structural limit of the design, not a known-issue footnote, and may argue for a much higher threshold or a different mitigation entirely.'
  severity: minor
  category: unexamined-framing
  id: devils-advocate-5eaf0346
dropped_findings: []
---

## Summary

Four premises hold this plan up and none of them are defended in the artifact. First, the Goal names `abusive clients` as the threat without characterizing the adversary — a token-bucket is a reasonable response to accidental misuse and a weak response to motivated abuse, and the plan cannot be evaluated until the reader knows which one is being defended against. Second, `60 requests/min` is treated as given; no data source is cited, and every parameter downstream inherits whatever error lives in that number. Third, the entire in-process design rests on the parenthetical `we run one` node — that is a present-tense fact masquerading as a permanent constraint, and the feature silently breaks on the day the service scales horizontally. Fourth, `req.ip` as the keying function is acknowledged as imperfect but never defended against alternatives, which matters because NAT/CGNAT makes the limit effectively per-network not per-client. The plan may well be correct. The reader has no way to verify that without the author writing down the four premises and saying which data or decisions back each one.
