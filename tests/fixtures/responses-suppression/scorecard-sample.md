---
persona: staff-engineer
findings:
  - target: section-scope
    claim: Scope boundary with downstream services is not defined explicitly.
    evidence: "section-scope sample artifact line"
    ask: Add an explicit list of downstream services affected.
    severity: major
    category: operational
  - target: section-rollback
    claim: No rollback step is present for a multi-service migration.
    evidence: "section-rollback sample artifact line"
    ask: Name the exact CLI command that reverts the change.
    severity: blocker
    category: operational
---

## Summary

Two concerns raised.
