---
persona: compliance-reviewer
artifact_sha256: 02517281e3dfe34ff8d6abbeb0cdca019ff2bbae839d63f766e354e327db88e3
findings:
- target: RDS SessionStore CDK construct
  claim: The RDS session store accumulates session records indefinitely with no TTL, purge job, or lifecycle policy — GDPR Art. 5(1)(e) requires personal data (session identifiers tied to userId/sub) be
    stored no longer than necessary. The session hash is derived from a user's SID and the store links to userId via the scopes grant, making these personal data under GDPR.
  evidence: "const sessionDb = new rds.DatabaseInstance(this, 'SessionStore', {\n  engine: rds.DatabaseInstanceEngine.postgres({ version: rds.PostgresEngineVersion.VER_15 }),\n  instanceType: ec2.InstanceType.of(ec2.InstanceClass.R6G,\
    \ ec2.InstanceSize.LARGE),\n  allocatedStorage: 100,\n  multiAz: true,\n  deletionProtection: true,\n});\n"
  ask: Define a retention TTL for session records (e.g., 90 days post-revocation) and implement a scheduled purge — either via pg_cron inside the RDS instance or an external Lambda. The document's own compliance
    section claims a 90-day retention for auth logs but does not apply any equivalent lifecycle to the session store itself.
  severity: blocker
  category: data-retention
  id: compliance-reviewer-9f0d3b6a
- target: RDS SessionStore CDK construct — encryption
  claim: The RDS instance does not set storageEncrypted or encryptionKey, which means encryption at rest defaults to disabled in CDK unless the account has opt-in defaults. GDPR Art. 5(1)(f) requires appropriate
    technical measures to protect personal data at rest. Session records contain userId mappings and OAuth scopes.
  evidence: "const sessionDb = new rds.DatabaseInstance(this, 'SessionStore', {\n  engine: rds.DatabaseInstanceEngine.postgres({ version: rds.PostgresEngineVersion.VER_15 }),\n  instanceType: ec2.InstanceType.of(ec2.InstanceClass.R6G,\
    \ ec2.InstanceSize.LARGE),\n  allocatedStorage: 100,\n  multiAz: true,\n  deletionProtection: true,\n});\n"
  ask: 'Add storageEncrypted: true and specify a KMS key via encryptionKey so that encryption is explicit rather than dependent on account-level defaults. KMS-managed keys also provide an audit trail of
    decryption events via CloudTrail, which supports PCI DSS Req 10 access-tracking requirements.'
  severity: major
  category: encryption-at-rest
  id: compliance-reviewer-e45b5585
- target: validateSession function
  claim: The session validation hot path — called on every authenticated request — performs no audit logging of who validated which session or when. HIPAA 164.312(b) requires systems containing ePHI to
    record and examine activity. If this platform handles health data (the compliance section invokes HIPAA safe harbor), every access-control decision must be logged with actor identity.
  evidence: "// Hot path: called on every authenticated request\nexport async function validateSession(sessions: Session[], userId: string): Promise<Session | null> {\n  // N+1 pattern: each session triggers\
    \ a DB lookup for revocation status\n  for (const session of sessions) {\n    const revoked = await db.query('SELECT revoked FROM sessions WHERE hash = $1', [session.hash]);\n"
  ask: Emit an audit event from validateSession that records the userId, session hash, validation outcome (granted/denied), and timestamp. Route these events to the immutable audit trail the compliance
    section claims exists — but which has no implementation anywhere in this artifact.
  severity: major
  category: audit-controls
  id: compliance-reviewer-572cf255
- target: Compliance & Audit Requirements section — session timeout
  claim: The document asserts PCI Req 8.2.4 mandates 15-minute session timeout for payment-adjacent services, but no timeout enforcement appears in the session rotation code, the validateSession function,
    or the Helm values. The control is cited without implementation — an auditor will flag this as a compensating-control gap.
  evidence: 'PCI Req 8.2.4 mandates session timeout at 15 minutes of inactivity for payment-adjacent services.

    '
  ask: 'Implement idle-timeout logic in the session validation path: compare lastActivity timestamp against a 15-minute threshold and force re-authentication when exceeded. Expose the timeout duration as
    a Helm value (e.g., auth.gateway.sessionTimeoutMinutes) so self-hosted customers can tune it to their PCI scope.'
  severity: major
  category: session-management
  id: compliance-reviewer-580ac627
- target: Compliance & Audit Requirements section — immutable audit trail
  claim: The document states 'All authentication events are logged to the immutable audit trail (SOC2 CC-6.1 control)' but no logging implementation, log destination, or tamper-protection mechanism appears
    anywhere in the artifact. SOC2 CC6.1 requires logical access controls restricting who can modify or delete audit records — you cannot claim the control is met by naming it without showing the implementation.
  evidence: 'All authentication events are logged to the immutable audit trail (SOC2 CC-6.1 control).

    '
  ask: 'Show the audit-log implementation: where events are emitted (middleware? gateway?), where they land (CloudWatch Logs with resource policy? S3 with Object Lock? a dedicated audit RDS table with revoke-only
    grants?), and how tamper-protection is enforced. Without this, the SOC2 CC6.1 citation is an assertion, not a control.'
  severity: blocker
  category: audit-controls
  id: compliance-reviewer-16e1b616
dropped_findings: []
---

## Summary

Two blocker findings and three major findings. The session store lacks both a data retention lifecycle (GDPR Art. 5(1)(e) — session records tied to user identifiers accumulate without a purge schedule) and an implemented audit trail (SOC2 CC6.1 — the document asserts immutable logging but ships zero logging code). The major findings address missing encryption-at-rest declaration on the RDS instance (GDPR Art. 5(1)(f)), absent audit events in the session-validation hot path (HIPAA 164.312(b)), and a PCI Req 8.2.4 session-timeout claim with no enforcement logic. The compliance section name-drops four frameworks but substantiates none of them with implementation — it is waving its hands at controls it has not actually built.
