---
persona: sre
artifact_sha256: 02517281e3dfe34ff8d6abbeb0cdca019ff2bbae839d63f766e354e327db88e3
findings:
- target: '## Performance-Critical Path: Session Validation'
  claim: The session validation function is an N+1 DB query on the hot path of every authenticated request. With no bound on the `sessions` array length, a user with K active sessions produces K sequential
    round-trips to Postgres. At any non-trivial request rate this will saturate connection pool and spike p99 latency until the gateway starts failing health checks.
  evidence: "// N+1 pattern: each session triggers a DB lookup for revocation status\nfor (const session of sessions) {\n  const revoked = await db.query('SELECT revoked FROM sessions WHERE hash = $1',\
    \ [session.hash]);\n"
  ask: What is the upper bound on sessions per user? If a user can accumulate 50 sessions, every request costs 50 sequential queries. Give me the expected p99 latency at peak req/s with that fan-out, and
    confirm the connection pool size on the r6g.large can absorb it. If it can't, this is the first thing that pages the on-call when auth gateway pods start failing readiness probes.
  severity: blocker
  category: blast-radius
  id: sre-1ec0bf0e
- target: '## Authentication Gateway Migration'
  claim: The JWKS endpoint is fetched via `createRemoteJWKSet` with no cache TTL, no fallback, and no circuit breaker. If the auth issuer has a DNS blip or returns 5xx, every token verification fails simultaneously
    across all 3 replicas. That is a full auth outage -- zero requests pass.
  evidence: 'const JWKS = createRemoteJWKSet(new URL(`${AUTH_ISSUER}/.well-known/jwks.json`));

    '
  ask: What is the JWKS cache TTL and what happens during a fetch failure? The `jose` library does cache keys by default, but if the cache is cold (deploy, pod restart, key rotation) and the issuer is unreachable,
    all requests 401. Name the alert rule and runbook for 'JWKS fetch failure rate > 0 for 60s'. Without one, on-call finds out from a customer ticket wave.
  severity: major
  category: observability
  id: sre-a9ffd1f6
- target: '## Deployment Timeline'
  claim: The rollout plan says enterprise self-hosted customers go first (Weeks 1-2) but there is no rollback procedure, no success criteria gate between stages, and no mention of how the on-call distinguishes
    'migration broke auth' from 'customer misconfigured OIDC'. Enterprise customers in air-gapped environments cannot be hotfixed quickly -- a bad bundle stays bad until the next bundle ships.
  evidence: '- Week 1-2: Enterprise self-hosted customers (air-gapped bundle generation)

    - Week 3: SaaS staging environment

    - Week 4: SaaS production (canary 10% -> 50% -> 100%)

    '
  ask: 'Define the go/no-go gate between Week 2 and Week 3. What metric or signal from the enterprise deployments must be green before SaaS staging begins? For air-gapped customers specifically: what is
    the rollback procedure if the v3.0 bundle breaks auth? If the answer is ''ship a v3.0.1 bundle'', that is a multi-day remediation window during which the customer is down.'
  severity: major
  category: rollback
  id: sre-cda8267c
- target: '## Cloud Infrastructure (AWS CDK)'
  claim: The RDS session store is provisioned as a single r6g.large with MultiAZ but no read replicas, no connection pooling (PgBouncer/RDS Proxy), and no alarm definitions. The N+1 query pattern on the
    hot path will hit the connection limit of a single-instance writer at moderate load. When connections are exhausted, the auth gateway stops serving -- every request 503s.
  evidence: "const sessionDb = new rds.DatabaseInstance(this, 'SessionStore', {\n  engine: rds.DatabaseInstanceEngine.postgres({ version: rds.PostgresEngineVersion.VER_15 }),\n  instanceType: ec2.InstanceType.of(ec2.InstanceClass.R6G,\
    \ ec2.InstanceSize.LARGE),\n"
  ask: r6g.large gives you ~650 max connections out of the box. With 3 auth gateway pods running the N+1 loop, each request holding a connection per query, what is the steady-state connection count at peak?
    Add RDS Proxy or PgBouncer, and define CloudWatch alarms on DatabaseConnections, ReadLatency, and FreeableMemory with pager thresholds. Without these, the first sign of saturation is customer-facing
    503s.
  severity: major
  category: capacity
  id: sre-18f90155
- target: '## Shared Platform API Contract Changes'
  claim: The plan ships a breaking change to /api/v2/platform/auth/verify consumed by 4 downstream teams, with no versioning strategy beyond 'all teams must update their clients before the v3.0 cutover'.
    If even one of the four teams misses the cutover window, their service starts throwing 400s or 500s against the new schema. That is a cross-team incident with unclear ownership.
  evidence: 'This shared API contract is consumed by 4 downstream teams: data-platform, model-serving, notebook-service, and package-management. All teams must update their clients before the v3.0 cutover.

    '
  ask: Who pages when notebook-service sends the old VerifyRequest schema to the new endpoint? Is that the auth-gateway team's pager or the notebook-service team's? Define explicit per-team readiness gates
    -- a canary health check per consumer -- so the cutover does not proceed until all four consumers are confirmed compatible. Otherwise this is a coordination-failure incident waiting to happen.
  severity: major
  category: blast-radius
  id: sre-59a44437
- target: '## Test Coverage Gap'
  claim: Five source files modified or created with zero test coverage, explicitly deferred to 'sprint 2'. The deployment timeline starts enterprise rollout in Week 1 -- meaning untested auth code ships
    to air-gapped customers who cannot be patched quickly. A regression in session rotation or token verification surfaces as a full auth outage at the customer site.
  evidence: 'No corresponding test files created yet. Test plan deferred to sprint 2.

    '
  ask: At minimum, the hot path (validateSession, verifyToken, rotateSession) needs integration tests that run before the air-gapped bundle is cut. If a regression ships in the bundle, what is the mean-time-to-remediation
    for an air-gapped customer? If it exceeds 4 hours, this is a contractual SLA risk, not just a code quality issue.
  severity: major
  category: risk
  id: sre-aef7415b
dropped_findings:
- id: finding-2
  reason: evidence_not_verbatim
  phrase: null
---

## Summary

This migration plan puts untested authentication code on the hot path of every request, backed by a database query pattern that is unbounded in fan-out and unmonitored. The session validation N+1 loop is the clearest pager scenario: at any meaningful concurrency, it exhausts Postgres connections and takes down auth for all consumers. The JWKS remote fetch has no failure-mode story -- a cold cache plus an issuer blip is a full outage with no distinguishing signal for the on-call. The deployment timeline ships breaking changes to air-gapped customers first, with no rollback procedure and no test coverage, which means the first signal of a bug is a customer-down ticket with a multi-day remediation window. Every finding here is a specific wake-up call, not a process suggestion -- they are the scenarios that will page someone at 3am if this plan ships as written.
