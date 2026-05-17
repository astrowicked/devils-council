---
persona: dual-deploy-reviewer
artifact_sha256: 02517281e3dfe34ff8d6abbeb0cdca019ff2bbae839d63f766e354e327db88e3
findings:
- target: values.yaml:auth.gateway.image.repository
  claim: The image `registry.anaconda.com/platform/auth-gateway` is a hard-coded internet-reachable registry. A self-hosted air-gapped KOTS install cannot pull from `registry.anaconda.com` — there is no
    Helm value for an image pull override prefix (e.g., `global.imageRegistry`) and no KOTS config item that rewrites the repository to a customer-provided private registry or the KOTS-proxied airgap registry.
    The pod will sit in ImagePullBackOff on every air-gapped install.
  evidence: 'repository: registry.anaconda.com/platform/auth-gateway

    '
  ask: Add a `global.imageRegistry` value (defaulting to `registry.anaconda.com`) that all image repository fields template from, e.g., `{{ .Values.global.imageRegistry }}/platform/auth-gateway`. Then surface
    that value in the KOTS Config spec so the KOTS admin console can override it with the private registry endpoint during air-gapped installs. Without this, the Week 1-2 enterprise rollout fails on air-gapped
    customers.
  severity: blocker
  category: dual-deploy
  id: dual-deploy-reviewer-8ca84a07
- target: src/auth/verify.ts (JWT verification)
  claim: The `createRemoteJWKSet` call fetches keys from `AUTH_ISSUER/.well-known/jwks.json` over HTTPS at runtime. In SaaS, this hits the shared auth provider on the public internet. In a self-hosted air-gapped
    environment there is no outbound internet — this call will time out and every token verification fails. There is no Helm value for a local JWKS endpoint, no KOTS config field to provide a static JWKS
    file, and no fallback to a pre-baked key set.
  evidence: 'const JWKS = createRemoteJWKSet(new URL(`${AUTH_ISSUER}/.well-known/jwks.json`));

    '
  ask: Add a Helm value `auth.gateway.jwksMode` with options `remote` (default for SaaS) and `local`. When `local`, load a static JWKS JSON file mounted from a ConfigMap or Secret that the KOTS config provisions.
    Add a KOTS config item `jwks_static_keys` of type `textarea` so the admin can paste their IdP's public keys. Test both modes in CI — one with a mock HTTP JWKS endpoint, one with a file-mounted key set.
  severity: blocker
  category: saas-only-assumption
  id: dual-deploy-reviewer-097ae8f8
- target: CDK RDS session store
  claim: The session store is an AWS RDS instance created via CDK. Self-hosted customers do not run CDK and do not have RDS — they run their own PostgreSQL. But neither the Helm values nor the KOTS config
    expose a `sessionStore.host`, `sessionStore.port`, or `sessionStore.existingSecret` field. The auth-gateway code uses `pg` to connect, but there is no documented way for a self-hosted install to point
    that connection at their own database. The chart will render with an empty or missing DB connection string.
  evidence: 'const sessionDb = new rds.DatabaseInstance(this, ''SessionStore'', {

    '
  ask: 'Add Helm values `auth.gateway.sessionStore.host`, `auth.gateway.sessionStore.port`, `auth.gateway.sessionStore.existingSecret` (name of a K8s Secret with `password` key). Default `host` to `postgresql.{{
    .Release.Namespace }}.svc.cluster.local` for self-hosted. Add matching KOTS config items (`session_db_host`, `session_db_port`, `session_db_password` with `type: password`). The CDK stack is SaaS-only
    infrastructure; the chart must not assume its existence.'
  severity: blocker
  category: dual-deploy
  id: dual-deploy-reviewer-8b7ef6b6
- target: KOTS Config spec
  claim: 'The KOTS config exposes `oidc_issuer` and `oidc_client_id` but the Helm `values.yaml` has `kots.config.auth_provider: "oidc"` with no template wiring shown. If the chart templates never read `kots.config.oidc_issuer`
    and instead hard-code `AUTH_ISSUER` from a SaaS environment variable, the KOTS config fields become dead knobs — a customer fills them in, the admin console shows green, but the auth gateway ignores
    them and uses a SaaS-only issuer URL. This is the exact support ticket pattern: settings that do nothing.'
  evidence: "- name: oidc_issuer\n    type: text\n    title: OIDC Issuer URL\n"
  ask: 'Show the template wiring: the Deployment env var `AUTH_ISSUER` must be set to `{{ repl ConfigOption "oidc_issuer" }}` in the KOTS HelmChart resource''s `optionalValues` or in the chart''s `_helpers.tpl`.
    Add a `required` annotation or a KOTS config `validation` block that fails the preflight if `oidc_issuer` is empty. If the SaaS deploy never reads these KOTS fields, gate them with `when: ''{{repl eq
    (LicenseFieldValue "deployment_mode") "self-hosted"}}''` so they only appear in the self-hosted admin console.'
  severity: major
  category: kots-dead-knob
  id: dual-deploy-reviewer-420f2063
- target: package.json dependency
  claim: The auth-gateway has a hard dependency on `@aws-sdk/client-secrets-manager`. In a self-hosted on-prem install (no AWS), importing this package and calling Secrets Manager will throw at runtime
    because no AWS credentials exist. There is no conditional import, no Helm value to select a secrets backend (e.g., Vault, K8s Secrets, env vars), and the KOTS config does not surface a secrets provider
    choice.
  evidence: '"@aws-sdk/client-secrets-manager": "^3.500.0"

    '
  ask: Introduce a Helm value `auth.gateway.secretsBackend` with enum `aws-sm | k8s-secret | env`. Gate the AWS SDK import behind a runtime check of `SECRETS_BACKEND` env var. For self-hosted KOTS installs,
    default to `k8s-secret` and mount credentials from a K8s Secret specified by `auth.gateway.sessionStore.existingSecret`. The `@aws-sdk/client-secrets-manager` package should be an optional peer dep
    or lazily loaded — it is dead weight (and a startup-crash risk if it auto-initializes) on non-AWS installs.
  severity: major
  category: saas-only-assumption
  id: dual-deploy-reviewer-5ec535f5
dropped_findings: []
---

## Summary

Five dual-deploy breaks are cited. Three are blockers: the image registry has no
override for air-gapped pulls, the JWKS fetch assumes outbound internet, and the
session store DB has no Helm/KOTS path for customer-provided PostgreSQL. Two are
major: the KOTS config fields for OIDC have no visible template wiring (dead-knob
risk), and the hard `@aws-sdk/client-secrets-manager` dependency crashes on
non-AWS self-hosted installs. The plan rolls enterprise self-hosted customers
first (Week 1-2) but as written, none of the three blockers have a self-hosted
fallback — those installs will not start.
