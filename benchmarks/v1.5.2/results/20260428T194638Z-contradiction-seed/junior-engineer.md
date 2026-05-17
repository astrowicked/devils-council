---
persona: junior-engineer
run_id: chair-test
findings:
- id: junior-engineer-129847e1
  target: '## Risks'
  claim: I had to re-read the deploy-window risk section three times — it says 'in-memory state does not survive restart' but never explains what happens to requests in flight when the state resets.
  evidence: 'In-memory state does not survive restart; limits reset on deploy.

    '
  ask: Add one sentence explaining what a user sees when the limiter state resets mid-request — do they get a 429 or does the counter just start over?
  severity: minor
  category: comprehension
dropped_findings: []
---

## Summary

The deploy-reset behavior is described but the user-facing consequence is not.
