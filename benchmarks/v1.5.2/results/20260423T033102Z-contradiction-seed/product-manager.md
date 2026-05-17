---
persona: product-manager
run_id: chair-test
findings:
- id: product-manager-d78ee020
  target: '## Proposal'
  claim: The Acme demo commitment was signed off on 'ship it on by default'; gating with a flag changes the contract without a re-commit.
  evidence: 'No feature flag. No kill switch. No staged rollout.

    '
  ask: If the flag goes in, re-confirm the Acme demo script with their onboarding team before May 8.
  severity: major
  category: business
dropped_findings: []
---

## Summary

Customer-side script drift is the business risk.
