---
persona: sre
run_id: chair-test
findings:
- id: sre-d06ae968
  target: '## Proposal'
  claim: Shipping unflagged removes the rollback lever; a 9am PT deploy-induced 429 spike takes the demo rehearsal down.
  evidence: 'No feature flag. No kill switch. No staged rollout.

    '
  ask: Land behind a per-tenant flag defaulted on; the flag is the rollback path when the token-bucket math is wrong.
  severity: blocker
  category: blast-radius
- id: sre-19e6b287
  target: '## Risks'
  claim: Deploy-minute state reset will page on-call the week of the demo; there is no runbook.
  evidence: 'In-memory state does not survive restart; limits reset on deploy.

    '
  ask: Name the pager rotation that owns the deploy-minute 429 spike and document the error-budget burn.
  severity: major
  category: blast-radius
dropped_findings: []
---

## Summary

Deploy-window operational risk is named but not owned.
