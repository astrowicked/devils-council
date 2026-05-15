# Case Study: The Threat Model Said It Was There

> A self-service provisioning plan whose threat model claimed input validation existed — but no plan task actually implemented it. The Devil's Advocate caught the gap between claimed and actual security posture.

## The Plan (excerpt)

An infrastructure self-service platform allowed engineers to provision cloud resources via a GitHub Actions workflow. The plan included a threat model section:

> **Threat:** Arbitrary resource type injection via workflow_dispatch input  
> **Mitigation:** "Input validation with allowed-list check prevents unauthorized resource types"

The plan then defined 6 tasks: Terraform modules, workflow file, state management, IAM roles, Slack notifications, and cleanup automation.

## What the Council Found

### Devil's Advocate + SRE (independently):

> **Finding (BLOCKER):** The threat model claims `resource_type` validation exists, but no task in the plan implements it. The workflow accepts a freeform string input from `workflow_dispatch` and passes it directly to Terraform module selection. There is no validation step, no enum constraint, and no allowed-list check anywhere in the implementation tasks.

### Staff Engineer (supporting):

> **Finding (HIGH):** The workflow template exposes all 6 resource types in the dispatch UI, but only 1 (EC2) has a working Terraform module. An engineer selecting "RDS" will get a cryptic Terraform error, not a helpful "not yet available" message.

### The fixes applied:

1. Added explicit `allowed_types=("ec2")` validation step at workflow start — fail fast with clear error
2. Scoped the workflow_dispatch enum to only EC2 (not all 6 types)
3. Added `concurrency` group to prevent parallel provisioning races

## Impact

The original plan would have deployed a self-service tool with:
- A threat model that claims security controls exist (for audit/compliance purposes)
- Zero actual enforcement of those controls
- A direct path from workflow dispatch input to Terraform module selection

This is the worst kind of security gap — one that's **documented as mitigated** when it isn't. An auditor reviewing the threat model would check the box. An attacker (or a curious engineer) would bypass it trivially.

**Time to find:** 48 seconds  
**Compliance impact:** Avoided a false SOC2 control attestation.
