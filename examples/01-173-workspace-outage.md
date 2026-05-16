# Case Study: The 173-Workspace Outage That Didn't Happen

> A credential migration plan that would have caused an org-wide CI/CD outage — caught by SRE and Devil's Advocate personas independently identifying the same gap from different angles.

## The Plan (excerpt)

A Terraform extraction project needed to migrate a shared agent pool token. The plan covered:
- Day 1: Set up new repo, import existing resources
- Day 2: Cutover — create new token, update Vault, remove old workspace state  
- Day 3: Cleanup and documentation

The agent token is **non-importable** (write-only API field), so a new token must be created during migration. 173 CI/CD workspaces depend on this single agent pool.

## What the Council Found

### SRE caught: No verification gate between "new token created" and "old token destroyed"

> **Finding (BLOCKER):** Between "new token written to Vault" and "old token destroyed from old workspace state" there is no verification that agents have picked up the new token. ESO sync + pod restart + agent reconnection is not instantaneous. A gap between token invalidation and agent pickup = org-wide outage for 173 workspaces.

### Devil's Advocate caught: The same gap from a failure-mode perspective

> **Finding (BLOCKER):** The plan acknowledges the token is non-importable but then doesn't define the actual cutover procedure. What happens if the new token is invalid? What if ESO takes 5 minutes to sync? What's the abort criteria?

### The fix applied before execution

```
1. After apply (new token in Vault): verify ESO ExternalSecret has synced
2. Trigger rolling restart of agent pods  
3. Wait for 4/4 agents to show "idle" in TFC agent pool API
4. Only THEN proceed to remove old token
5. Abort: if <4 agents reconnect within 15 minutes, re-apply old workspace to restore old token
```

## Impact

Without the council review, the migration would have proceeded with a "hope it works" gap during the cutover. At best: 5-15 minutes of queued CI jobs. At worst: all 173 workspaces unable to run plans/applies until someone manually intervenes, with no documented rollback path.

**Time to find this issue:** 48 seconds (parallel persona execution)  
**Time it would have taken to debug in production:** Hours, during a high-stress incident with no runbook.
