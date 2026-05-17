---
persona: security-reviewer
artifact_sha256: 02517281e3dfe34ff8d6abbeb0cdca019ff2bbae839d63f766e354e327db88e3
findings:
- target: src/auth/session.ts (rotateSession)
  claim: 'The `oldToken!` non-null assertion lies to the compiler: `req.headers.authorization?.replace(''Bearer '', '''')` evaluates to `undefined` when the header is missing (the `?.` short-circuits),
    then `!` asserts it is defined. `verifyToken(undefined as unknown as string)` reaches `jwtVerify` with a non-string argument. Depending on `jose`''s internal coercion path, this is either a 500 crash
    (DoS) or — if `jose` toString-coerces and finds a match in the JWKS cache — a forged empty-token verification.'
  evidence: 'const oldToken = req.headers.authorization?.replace(''Bearer '', '''');

    const verified = await verifyToken(oldToken!);

    '
  ask: 'Guard before the call: `if (!oldToken) return res.status(401).end();`. Remove the `!` assertion entirely — it masks the exact class of bug it exists to flag.'
  severity: blocker
  category: auth-bypass
  id: security-reviewer-82638c3c
- target: src/auth/verify.ts (verifyToken)
  claim: The `payload.sid!` assertion trusts the JWT issuer to always include a `sid` claim. A valid JWT without `sid` (the claim is optional per RFC 7519) passes `undefined` into `createHash('sha256').update(undefined!)`.
    Node's `Hash.update` calls `toString()` on non-Buffer inputs, hashing the literal string `'undefined'` — so every token without a `sid` claim maps to the same session hash. An attacker who obtains any
    valid JWT lacking `sid` can collide with (and revoke) other sid-less sessions.
  evidence: 'const sessionHash = createHash(''sha256'').update(payload.sid!).digest(''hex'');

    '
  ask: 'Validate `payload.sid` exists and is a non-empty string before hashing: `if (typeof payload.sid !== ''string'' || !payload.sid) throw new AuthError(''missing sid claim'');`. Remove the `!`.'
  severity: major
  category: session-collision
  id: security-reviewer-25f86117
- target: src/middleware/validate.ts (validateSession)
  claim: The `sessions` array length is unbounded. If the caller derives it from user-controlled input (e.g., multiple session cookies or a JSON array in a header), an attacker can submit thousands of entries.
    Each triggers an awaited DB round-trip (`await db.query(...)` inside a `for` loop), so 10k entries = 10k serial queries — a trivial denial-of-service amplification against the session store with a single
    HTTP request.
  evidence: "for (const session of sessions) {\n  const revoked = await db.query('SELECT revoked FROM sessions WHERE hash = $1', [session.hash]);\n"
  ask: 'Cap `sessions.length` (e.g., `sessions.slice(0, 5)`) before entering the loop. Better: batch the revocation check into a single `WHERE hash = ANY($1)` query so the DB cost is O(1) regardless of
    input size.'
  severity: major
  category: denial-of-service
  id: security-reviewer-4c1fd795
- target: KOTS config (auth_settings group)
  claim: The KOTS config defines `oidc_client_id` but has no `oidc_client_secret` item. For a confidential OIDC client (server-side token exchange), the secret must be stored somewhere. Its absence from
    the admin-facing config panel means either (a) it is hardcoded in the image — leaked on every `docker inspect` — or (b) the gateway uses a public-client flow, which cannot authenticate the relying party
    and allows any origin to exchange auth codes.
  evidence: "- name: oidc_client_id\n    type: text\n    title: Client ID\n"
  ask: 'Add an `oidc_client_secret` item with `type: password` and wire it into the auth-gateway pod as a Secret mount. If PKCE-only public-client flow is intentional, document the threat model for token
    replay without client authentication.'
  severity: major
  category: secret-management
  id: security-reviewer-f09b57f4
- target: src/infra/rds-stack.ts (MigrationArtifacts bucket)
  claim: The migration-artifacts bucket uses `S3_MANAGED` encryption — AWS holds the only key and there is no key policy you control. If migration artifacts contain session tokens, old auth secrets, or
    PII being moved between systems, no one can independently rotate or revoke the encryption key. The bucket also has no `blockPublicAccess` set, relying on the account-level default which may not exist
    in all enterprise deployment accounts.
  evidence: 'encryption: s3.BucketEncryption.S3_MANAGED,

    '
  ask: 'Switch to `BucketEncryption.KMS` with a dedicated CMK so the key can be rotated or destroyed independently. Add `blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL` explicitly — do not rely on account
    defaults that vary across customer AWS accounts in self-hosted deployments.'
  severity: minor
  category: data-exposure
  id: security-reviewer-df3c5826
dropped_findings: []
---

## Summary

The artifact's authentication gateway code has two non-null assertion
bugs that cross the trust boundary between untrusted HTTP input and the
crypto verification layer. The `oldToken!` path is a blocker: a missing
Authorization header reaches `jwtVerify` with `undefined`, and the
outcome depends on a library's internal coercion behavior — not on an
explicit validator the author controls. The `payload.sid!` path creates a
deterministic session-hash collision for any valid JWT that omits the
optional `sid` claim. A third finding targets a denial-of-service
amplification in the session-validation hot path where an attacker
controls the iteration count of serial DB queries. Two infrastructure
findings (missing OIDC client secret config, S3 encryption key
governance) round out the review but are lower severity because
exploitation requires additional access beyond a single HTTP request.
