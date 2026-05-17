---
persona: devils-advocate
run_id: chair-test
findings:
- id: devils-advocate-48c858f7
  target: '## Proposal'
  claim: The unexamined premise is 'demo simplicity justifies removing the rollback path'; this trade is not named anywhere in the plan.
  evidence: 'No feature flag. No kill switch. No staged rollout.

    '
  ask: Name the trade explicitly and defend it, or pick the other side.
  severity: major
  category: complexity
dropped_findings: []
---

## Summary

The trade-off the plan hides is the one worth arguing about.
