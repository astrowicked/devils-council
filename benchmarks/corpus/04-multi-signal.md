# Platform API Gateway Migration Plan

## Executive Summary

Migrate the shared API gateway from Express to Fastify, consolidate
authentication into a unified OAuth2 flow, update Helm charts for
dual-deploy compatibility, and ensure GDPR audit logging compliance.
This initiative targets Q4 delivery with a phased rollout strategy.

## Authentication Changes

Replace the legacy session-based auth with OAuth2 + PKCE flow:

```typescript
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { createHash } from 'crypto';

const JWKS = createRemoteJWKSet(new URL(process.env.AUTH_ISSUER_URL));
async function validateToken(token: string): Promise<TokenPayload> {
  const { payload } = await jwtVerify(token, JWKS, {
    audience: process.env.AUTH_AUDIENCE,
  });
  return payload as TokenPayload;
}
```

The secret rotation moves from 90-day manual to 24-hour automated
rotation via AWS Secrets Manager.

## Infrastructure (AWS)

```typescript
import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
import * as rds from 'aws-cdk-lib/aws-rds';

const alb = new elbv2.ApplicationLoadBalancer(this, 'GatewayALB', {
  vpc, internetFacing: true,
});
const db = new rds.DatabaseCluster(this, 'AuditDB', {
  engine: rds.DatabaseClusterEngine.auroraPostgres({
    version: rds.AuroraPostgresEngineVersion.VER_15_4,
  }),
  instances: 3,
});
```

## Helm Chart Updates

### Chart.yaml

```yaml
apiVersion: v2
name: api-gateway
version: 3.0.0
dependencies:
  - name: postgresql
    version: "12.x"
    repository: "https://charts.bitnami.com/bitnami"
```

### values.yaml changes

```yaml
gateway:
  replicas: 3
  image:
    registry: registry.internal.corp
    repository: platform/api-gateway
    tag: "2.0.0"
```

Air-gap deployments must pre-pull the Bitnami PostgreSQL chart and
the gateway image into the private registry. No external image
pulls at install time.

## Compliance and Audit

All API access must be audit-logged per:

- **GDPR Art. 5(1)(f)**: Log accessor identity, timestamp, and data
  categories. Retention: 6 years. No deletion schedule exists today.
- **HIPAA 164.312(b)**: Record who accessed ePHI and when. Current
  audit log omits user identity on read-only queries.
- **SOC2 CC7.2**: Detect anomalous access patterns. No anomaly
  detection exists today.
- **PCI Req 10**: Track all access to cardholder data. Tamper
  protection via append-only S3 bucket with Object Lock.

## Performance Considerations

The validation middleware runs on every inbound request:

```typescript
for (const rule of validationRules) {
  const result = rule.validate(request.body);
  if (!result.valid) errors.push(formatError(rule, result));
}
```

This loop allocates per rule per request. No stated request rate
or p99 latency budget. The `validationRules` array grows with each
endpoint. The audit-log query uses no index on `accessed_at` — at
50M rows/month, performance degrades to sequential scan.

## Test Coverage

Source changes span 14 files across `src/auth/`, `src/gateway/`,
`src/middleware/`, and `src/audit/`. The test diff adds coverage
for `src/auth/oauth2.test.ts` only. No tests for the validation
loop, audit write path, Helm rendering, or secret rotation.

## Shared API Contract

The gateway `/v2/api/` endpoints are consumed by:

| Consumer | Endpoint | Owner |
|----------|----------|-------|
| billing-service | `/v2/api/usage` | Billing Team |
| dashboard-bff | `/v2/api/sessions` | Frontend Team |
| partner-integrations | `/v2/api/webhooks` | Integrations Team |

The response schema adds a required `rate_limit_remaining` field.
The migration drops the `X-RateLimit-Count` header that
`billing-service` currently parses.
