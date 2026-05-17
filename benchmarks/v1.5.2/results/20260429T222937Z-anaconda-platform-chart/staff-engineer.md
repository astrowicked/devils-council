---
persona: staff-engineer
artifact_sha256: 02517281e3dfe34ff8d6abbeb0cdca019ff2bbae839d63f766e354e327db88e3
findings:
- target: '## Performance-Critical Path: Session Validation'
  claim: The validateSession function has an explicit N+1 query pattern on the hot path — every authenticated request will issue one DB round-trip per session in the user's list. With 3 concurrent sessions
    and 10k RPM, that is 30k queries/min against the new RDS instance, yet the plan prices only a single r6g.large and moves on.
  evidence: "// N+1 pattern: each session triggers a DB lookup for revocation status\nfor (const session of sessions) {\n  const revoked = await db.query('SELECT revoked FROM sessions WHERE hash = $1',\
    \ [session.hash]);\n"
  ask: Batch the revocation check into a single WHERE hash IN ($1...$N) query, or maintain a revocation bloom filter / in-memory set refreshed on a TTL. Either eliminates N+1 without adding infrastructure.
  severity: blocker
  category: correctness
  id: staff-engineer-72a116c5
- target: '## Shared Platform API Contract Changes'
  claim: The plan introduces a BREAKING change on /api/v2/platform/auth/verify — the same version path, same major API version — and relies on 4 downstream teams coordinating a simultaneous cutover. The
    Overview section promises 'backward-compatible API contracts throughout the phased rollout' which directly contradicts this.
  evidence: 'summary: Verify platform token (BREAKING - new request schema)

    '
  ask: Either version the breaking change as /api/v3/ (matching the chart version), or provide a migration window where v2 accepts both schemas and the old shape is deprecated with a sunset header. Pick
    one; doing neither is a coordination landmine with four teams.
  severity: major
  category: correctness
  id: staff-engineer-b6a54238
- target: '## Test Coverage Gap'
  claim: Five source files form the security boundary of the new auth gateway, and the plan explicitly defers all testing to 'sprint 2' — yet enterprise self-hosted customers ship in week 1-2. You are deploying
    untested auth code to your least-recoverable environment first.
  evidence: 'No corresponding test files created yet. Test plan deferred to sprint 2.

    '
  ask: Gate the enterprise air-gapped bundle on passing integration tests for session rotation and token verification at minimum. Move those two test files into sprint 1 or swap the deployment order so
    SaaS staging is the canary, not enterprise.
  severity: major
  category: correctness
  id: staff-engineer-5d263fdc
- target: '## Authentication Gateway Migration'
  claim: The JWKS endpoint is fetched via createRemoteJWKSet which issues an outbound HTTPS call on every verification (with internal caching, but requiring network). In an air-gapped environment — the
    first deployment target — there is no network path to AUTH_ISSUER/.well-known/jwks.json. The plan never addresses offline JWKS provisioning.
  evidence: 'const JWKS = createRemoteJWKSet(new URL(`${AUTH_ISSUER}/.well-known/jwks.json`));

    '
  ask: 'Add a local-JWKS path for air-gapped deployments: either bundle the JWKS in the KOTS config, or accept a PEM/JWK file mount. The jose library supports createLocalJWKSet for exactly this case.'
  severity: major
  category: correctness
  id: staff-engineer-70344a10
- target: '## Cloud Infrastructure (AWS CDK)'
  claim: The S3 migration bucket uses S3_MANAGED encryption (SSE-S3) instead of KMS, meaning you cannot enforce key rotation policies or grant cross-account decrypt through KMS key policies. For a bucket
    holding migration artifacts that likely contain session data, this is an unnecessary downgrade from the KMS default most CDK stacks use.
  evidence: 'encryption: s3.BucketEncryption.S3_MANAGED,

    '
  ask: Switch to BucketEncryption.KMS_MANAGED or pass an explicit KMS key. The cost difference is negligible; the auditability difference is not.
  severity: minor
  category: complexity
  id: staff-engineer-85d9973b
- target: '## Strategic Alignment'
  claim: The section is pure filler — 'unlocks value', 'move the needle', 'north star metric' — without binding any of those phrases to a measurable decision in the plan. The only concrete number (4h to
    45min) has no connection to any technical choice in the document.
  evidence: 'This initiative unlocks value by consolidating three separate auth services into one platform gateway. The competitive landscape demands we move the needle on self-hosted deployment times

    '
  ask: Delete this section or replace it with a single sentence linking the 45min target to a specific technical enabler in this plan (pre-baked air-gap bundle? smaller image? parallel init?). If none of
    the work here achieves the 45min target, say so.
  severity: nit
  category: complexity
  id: staff-engineer-de96f9f0
dropped_findings: []
---

## Summary

The plan has one correctness blocker: the session validation hot path carries an N+1 query pattern that the document itself labels as such, yet ships anyway against a single RDS instance sized for steady-state, not for per-request fan-out. Beyond that, three major gaps compete for attention: a breaking API change that contradicts the plan's own backward-compatibility promise, zero test coverage shipping to the least-recoverable environment first, and an air-gapped deployment that cannot reach the remote JWKS endpoint the auth gateway depends on. The strategic alignment section is noise that could be deleted without losing a single technical decision.
