---
persona: air-gap-reviewer
artifact_sha256: 02517281e3dfe34ff8d6abbeb0cdca019ff2bbae839d63f766e354e327db88e3
findings:
- target: Dockerfile:1
  claim: The Dockerfile pulls `node:20-alpine` from `docker.io` by tag, not digest. An enterprise customer behind an egress firewall cannot reach Docker Hub, and the tag-based reference means even a pre-populated
    registry mirror cannot guarantee the same image bits across rebuilds.
  evidence: 'FROM docker.io/library/node:20-alpine AS builder

    '
  ask: Pin the base image by digest and source it from the customer's registry mirror variable. The line should read `FROM ${REGISTRY_MIRROR}/library/node@sha256:<pinned-digest> AS builder`, where REGISTRY_MIRROR
    defaults to the value specified in the KOTS airgap bundle config or the Helm values `image.registry` override.
  severity: blocker
  category: air-gap
  id: air-gap-reviewer-c0467fd0
- target: Dockerfile:4
  claim: The `npm ci` step inside the Dockerfile fetches all dependencies from `registry.npmjs.org` at build time. When the image is built inside the customer's air-gapped environment (which the plan's
    Week 1-2 timeline explicitly targets), DNS for `registry.npmjs.org` does not resolve and the build hangs or fails.
  evidence: 'RUN npm ci --production

    '
  ask: Either vendor `node_modules` into the build context (pre-fetched in the airgap bundle), or configure an `.npmrc` with a `registry=` pointing at the customer's internal npm mirror. The KOTS airgap
    bundle generation step must include a `npm pack` or tarball cache that the Dockerfile `COPY`s in before running `npm ci --offline`.
  severity: blocker
  category: air-gap
  id: air-gap-reviewer-b20080ac
- target: src/auth/gateway.ts:4
  claim: '`createRemoteJWKSet` makes an HTTPS GET to `${AUTH_ISSUER}/.well-known/jwks.json` on every token verification (or on first call with internal cache). If the OIDC issuer is external to the cluster
    (e.g., Okta, Auth0, Azure AD), the air-gapped customer''s egress firewall blocks the request and every authenticated API call fails with a network timeout.'
  evidence: 'const JWKS = createRemoteJWKSet(new URL(`${AUTH_ISSUER}/.well-known/jwks.json`));

    '
  ask: 'Support a local JWKS mode: allow the customer to supply a static JWKS file or a cluster-internal issuer URL. Add a config field (e.g., `auth.gateway.jwksMode: local | remote`) and when `local`,
    load keys from a mounted ConfigMap or Secret rather than fetching over the network. The KOTS config already has `oidc_issuer` -- gate the remote fetch behind a reachability check or explicit opt-in.'
  severity: blocker
  category: air-gap
  id: air-gap-reviewer-ed545814
- target: package.json dependencies
  claim: All five runtime dependencies use caret ranges (`^5.2.0`, `^8.11.0`, `^3.500.0`, etc.). A reproducible air-gapped build requires exact, locked versions. If a lockfile is not committed alongside
    this package.json, the `npm ci` in the Dockerfile will attempt to resolve the latest matching version from the public registry, which is unreachable.
  evidence: '"@aws-sdk/client-secrets-manager": "^3.500.0",

    '
  ask: Commit a `package-lock.json` with integrity hashes and ensure the airgap bundle includes a tarball cache matching those exact versions. The caret ranges are fine for development, but the Dockerfile
    build path must use `npm ci --offline` against a pre-populated cache to guarantee reproducibility without network access.
  severity: major
  category: air-gap
  id: air-gap-reviewer-faf285ce
dropped_findings: []
---

## Summary

Three blocker-severity air-gap failures and one major. The Dockerfile references `docker.io` by tag (unreachable and non-reproducible in a mirrored environment), runs `npm ci` against the public npm registry during build (fails when DNS does not resolve `registry.npmjs.org`), and the authentication gateway unconditionally fetches JWKS keys over HTTPS from a potentially external issuer (hangs every authenticated request behind an egress firewall). The caret-range dependencies compound the npm problem by making builds non-deterministic even if a partial mirror exists.

The plan explicitly targets Week 1-2 delivery to "Enterprise self-hosted customers (air-gapped bundle generation)" but none of the implementation artifacts shown here can build or run without outbound internet access. The KOTS config has an `airgap_bundle_url` field, but nothing in the Dockerfile, the npm install path, or the JWKS initialization code actually uses an offline fallback.
