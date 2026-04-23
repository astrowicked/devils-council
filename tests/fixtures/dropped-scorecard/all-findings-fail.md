---
persona: staff-engineer
findings:
  - target: section-approach
    claim: Please consider whether the rotation playbook includes pre-flight health checks.
    evidence: Rotate TLS certs on edge load balancers
    ask: Consider adding a rollback step.
    severity: blocker
    category: simplicity
  - target: section-risks
    claim: Rollback plan missing.
    evidence: This exact string does not appear anywhere in INPUT.md for deliberate mismatch.
    ask: Add a rollback section that names the exact CLI command to revert.
    severity: major
    category: operational
  - target: section-rollout
    claim: Team should think about the blast radius before enabling globally.
    evidence: Rotate TLS certs on edge load balancers
    ask: Think about staging a 5% canary first.
    severity: minor
    category: operational
---

## Summary

Three concerns raised. See findings above.
