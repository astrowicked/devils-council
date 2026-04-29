# Anaconda Platform Chart v3.0 Migration Plan

## Overview

This plan covers the v3.0 migration of the anaconda-platform-chart Helm deployment across both SaaS multi-tenant and self-hosted enterprise (air-gapped) environments. The migration introduces a new authentication gateway, restructures cloud resource allocation, and updates container base images to Node 20.

**Target:** Q4 delivery with phased rollout across enterprise customers first, SaaS second.
**Budget Impact:** Estimated $12k/month increase in compute due to new RDS instances and expanded EKS node pools. ROI projected at 3x within two quarters based on reduced operational overhead.

## Strategic Alignment

This initiative unlocks value by consolidating three separate auth services into one platform gateway. The competitive landscape demands we move the needle on self-hosted deployment times (currently 4h average, target 45min). De-risk the migration by maintaining backward-compatible API contracts throughout the phased rollout. North star metric: time-to-first-value for enterprise customers under 1 hour.

## Authentication Gateway Migration

### New JWT Verification Module

```typescript
import { createHash } from 'crypto';
import { jwtVerify, createRemoteJWKSet } from 'jose';

const JWKS = createRemoteJWKSet(new URL(`${AUTH_ISSUER}/.well-known/jwks.json`));

export async function verifyToken(token: string): Promise<TokenPayload> {
  const { payload } = await jwtVerify(token, JWKS, {
    issuer: AUTH_ISSUER,
    audience: 'anaconda-platform',
  });
  const sessionHash = createHash('sha256').update(payload.sid!).digest('hex');
  return { ...payload, sessionHash };
}
```

### Session Rotation Implementation

```typescript
export async function rotateSession(req: Request): Promise<Session> {
  const oldToken = req.headers.authorization?.replace('Bearer ', '');
  const verified = await verifyToken(oldToken!);
  // Invalidate old session, issue new refresh token
  await sessionStore.revoke(verified.sessionHash);
  return sessionStore.create({ userId: verified.sub, scopes: verified.scopes });
}
```

## Compliance & Audit Requirements

Per GDPR Art. 17 (Right to Erasure), the platform must support complete data subject deletion within 30 days. All authentication events are logged to the immutable audit trail (SOC2 CC-6.1 control). PCI Req 8.2.4 mandates session timeout at 15 minutes of inactivity for payment-adjacent services.

Data retention policy: authentication logs retained 90 days (HIPAA safe harbor), platform usage telemetry retained 1 year with pseudonymization after 30 days per CCPA requirements.

## Helm Values & KOTS Configuration

### values.yaml Changes

```yaml
# values.yaml diff
auth:
  gateway:
    enabled: true
    replicas: 3
    image:
      repository: registry.anaconda.com/platform/auth-gateway
      tag: "3.0.0"
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"

kots:
  config:
    auth_provider: "oidc"
    license_type: "enterprise"
    airgap_bundle_url: ""
```

### KOTS App Configuration

```yaml
# kots-app.yaml
apiVersion: kots.io/v1beta1
kind: Config
metadata:
  name: anaconda-platform
spec:
  groups:
    - name: auth_settings
      title: Authentication
      items:
        - name: oidc_issuer
          type: text
          title: OIDC Issuer URL
        - name: oidc_client_id
          type: text
          title: Client ID
```

## Cloud Infrastructure (AWS CDK)

### New RDS Instance for Session Store

```typescript
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as rds from 'aws-cdk-lib/aws-rds';
import * as ec2 from 'aws-cdk-lib/aws-ec2';

const sessionDb = new rds.DatabaseInstance(this, 'SessionStore', {
  engine: rds.DatabaseInstanceEngine.postgres({ version: rds.PostgresEngineVersion.VER_15 }),
  instanceType: ec2.InstanceType.of(ec2.InstanceClass.R6G, ec2.InstanceSize.LARGE),
  allocatedStorage: 100,
  multiAz: true,
  deletionProtection: true,
});

const migrationBucket = new s3.Bucket(this, 'MigrationArtifacts', {
  versioned: true,
  encryption: s3.BucketEncryption.S3_MANAGED,
  lifecycleRules: [{ expiration: Duration.days(90) }],
});
```

## Container Image Updates

### Dockerfile Base Image Change

```dockerfile
FROM docker.io/library/node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --production

FROM docker.io/library/node:20-alpine AS runtime
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 8080
CMD ["node", "server.js"]
```

### Dependency Updates (package.json)

```json
{
  "dependencies": {
    "jose": "^5.2.0",
    "pg": "^8.11.0",
    "@aws-sdk/client-secrets-manager": "^3.500.0",
    "express": "^4.18.0",
    "helmet": "^7.1.0"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "supertest": "^6.3.0"
  }
}
```

## Performance-Critical Path: Session Validation

```typescript
// Hot path: called on every authenticated request
export async function validateSession(sessions: Session[], userId: string): Promise<Session | null> {
  // N+1 pattern: each session triggers a DB lookup for revocation status
  for (const session of sessions) {
    const revoked = await db.query('SELECT revoked FROM sessions WHERE hash = $1', [session.hash]);
    if (!revoked.rows[0]?.revoked) {
      // Per-iteration allocation inside the loop
      const metadata = new Map<string, string>();
      metadata.set('lastValidated', new Date().toISOString());
      metadata.set('userId', userId);
      return { ...session, metadata: Object.fromEntries(metadata) };
    }
  }
  return null;
}
```

## Shared Platform API Contract Changes

### Breaking Changes to /api/v2/platform/auth (shared/ directory)

```yaml
# shared/api-contracts/platform-auth.openapi.yaml
openapi: 3.0.3
info:
  title: Platform Auth API
  version: 3.0.0
paths:
  /api/v2/platform/auth/verify:
    post:
      summary: Verify platform token (BREAKING - new request schema)
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/VerifyRequest'
  /api/v2/platform/auth/rotate:
    post:
      summary: Rotate session (NEW endpoint)
```

This shared API contract is consumed by 4 downstream teams: data-platform, model-serving, notebook-service, and package-management. All teams must update their clients before the v3.0 cutover.

## Test Coverage Gap

Source files modified in this migration:
- `src/auth/gateway.ts` (new)
- `src/auth/session.ts` (new)
- `src/auth/verify.ts` (modified)
- `src/infra/rds-stack.ts` (new)
- `src/middleware/validate.ts` (modified)

No corresponding test files created yet. Test plan deferred to sprint 2.

## Deployment Timeline

- Week 1-2: Enterprise self-hosted customers (air-gapped bundle generation)
- Week 3: SaaS staging environment
- Week 4: SaaS production (canary 10% -> 50% -> 100%)
- Runway: 6 weeks buffer before Q4 deadline based on current burn rate
