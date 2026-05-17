---
persona: sre
artifact_sha256: 02517281e3dfe34ff8d6abbeb0cdca019ff2bbae839d63f766e354e327db88e3
findings:
- target: '## Authentication Gateway Migration'
  claim: The JWKS endpoint is fetched via createRemoteJWKSet which makes a network call to AUTH_ISSUER on startup and periodically refreshes. In an air-gapped deployment, this URL is unreachable. Every
    request that needs token verification will fail with an unhandled network timeout, meaning 100% auth failure for all self-hosted customers until someone figures out the JWKS needs to be locally mirrored.
  evidence: 'const JWKS = createRemoteJWKSet(new URL(`${AUTH_ISSUER}/.well-known/jwks.json`));

    '
  ask: What is the JWKS resolution path for air-gapped KOTS installs? If the answer is 'local file or bundled keys', show me the fallback code. If it doesn't exist, every air-gapped enterprise deploy is
    a total auth outage on day one.
  severity: blocker
  category: blast-radius
  id: sre-4d92b940
- target: '## Shared Platform API Contract Changes'
  claim: A breaking change to /api/v2/platform/auth/verify is deployed to enterprise self-hosted customers in weeks 1-2, before SaaS staging in week 3. The 4 downstream teams must update clients before
    cutover, but the deployment timeline puts the breaking API live on enterprise first. If any downstream client in an enterprise bundle ships the old schema, every verify call returns 4xx and the customer's
    platform is down.
  evidence: 'All teams must update their clients before the v3.0 cutover.

    '
  ask: 'Name the coordination gate: which CI check or deployment precondition blocks the v3.0 chart from shipping to an enterprise customer whose air-gapped bundle still contains old-schema clients? Without
    a gate, the blast radius is 100% of auth-dependent features for that customer.'
  severity: major
  category: blast-radius
  id: sre-9e6afd40
- target: '## Deployment Timeline'
  claim: 'The canary rollout for SaaS production goes 10% -> 50% -> 100% but names no success criteria, no bake time between stages, no rollback trigger, and no metric that gates promotion. Without these,
    the canary is decorative: whoever is on-call during week 4 has no defined signal to halt the rollout before 100% of traffic hits a broken auth path.'
  evidence: 'Week 4: SaaS production (canary 10% -> 50% -> 100%)

    '
  ask: 'Define the promotion gate: which metric (error rate, p99 latency, session-creation success rate), at what threshold, over what bake window, triggers automatic rollback? Without this, the canary
    percentages are just a deploy schedule, not a safety mechanism.'
  severity: major
  category: observability
  id: sre-fa665719
- target: '## Test Coverage Gap'
  claim: The auth gateway, session store, and validation middleware ship with zero test coverage. Test plan deferred to sprint 2 means the code goes to enterprise customers untested. The on-call for enterprise
    support will be diagnosing bugs in production code that has never run outside of a developer laptop.
  evidence: 'No corresponding test files created yet. Test plan deferred to sprint 2.

    '
  ask: Which enterprise customers receive the week 1-2 air-gapped bundle, and what is the rollback procedure if the untested auth gateway fails in their environment where you have no access to debug?
  severity: major
  category: blast-radius
  id: sre-22e08cdd
- target: '## Cloud Infrastructure (AWS CDK)'
  claim: The RDS session store is provisioned as r6g.large with 100GB and multi-AZ, but there is no mention of connection pooling (PgBouncer or RDS Proxy), no backup/restore RPO/RTO, and no alerting on
    connection count or replication lag. The N+1 hot path will exhaust connections before anyone notices.
  evidence: 'instanceType: ec2.InstanceType.of(ec2.InstanceClass.R6G, ec2.InstanceSize.LARGE),

    allocatedStorage: 100,

    multiAz: true,

    '
  ask: 'State the connection pool configuration and the max_connections math: 3 gateway pods * N connections_per_pod vs. RDS max_connections for r6g.large (default ~1600). Add an alarm on connection utilization
    at 80% so the on-call knows before the pool is exhausted.'
  severity: minor
  category: observability
  id: sre-eabe4eac
dropped_findings:
- id: finding-0
  reason: evidence_not_verbatim
  phrase: null
- id: finding-3
  reason: evidence_not_verbatim
  phrase: null
---

## Summary

This migration plan will page the on-call in two distinct ways on day one. First, the N+1 session validation query on every authenticated request is an unbounded latency multiplier with no stated cap on sessions-per-user -- this is a connection-pool-exhausting, p99-spiking production incident waiting to happen. Second, the JWKS remote fetch has no air-gapped fallback, meaning every self-hosted enterprise customer deployed in weeks 1-2 gets a total auth outage the moment their gateway starts.

Beyond the two blockers, the operational story is missing the connective tissue that turns a deploy schedule into a safe rollout: no canary promotion gates, no rollback triggers, no load-test baseline for the fixed-replica count, and no coordination gate preventing broken downstream clients from shipping in enterprise bundles. The test coverage deferral means the on-call will be debugging net-new auth code in customer environments they cannot access. Each of these is a named 3am scenario, not a theoretical concern.
