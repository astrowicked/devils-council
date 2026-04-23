---
persona: security-reviewer
artifact_sha256: fixture-for-delegation-test
findings:
  - target: "src/auth/login.ts:42"
    claim: "JWT signature verification is skipped when skipVerify=true is passed - any client can choose not to have its token verified."
    evidence: |
      if (opts.skipVerify) return jwt.decode(token);
    ask: "Delete the skipVerify branch or gate it behind a test-only env flag."
    severity: blocker
    category: auth-bypass
delegation_request:
  persona: security-reviewer
  target: "src/auth/login.ts"
  question: "Enumerate every branch reachable by a caller that sets opts.skipVerify. Cite line numbers."
  context_files: ["src/auth/login.ts", "src/auth/session.ts"]
  sandbox: read-only
  timeout_seconds: 2
---

## Summary

Pre-built draft used by scripts/test-codex-delegation.sh. The 2-second
timeout lets the codex-stub-timeout.sh case finish quickly in CI.
