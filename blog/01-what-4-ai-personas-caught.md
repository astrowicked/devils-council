# I Let 4 AI Personas Rip Apart My Plans Before I Code — Here's What They Caught

Every plan has blind spots. You wrote it, so you can't see them. Your team reviewer is busy. The PR review catches syntax, not architecture. And by the time production reveals the flaw, you've already built on top of it.

I built [devils-council](https://github.com/astrowicked/devils-council) to fix this. Before any plan becomes code, four AI personas — a Staff Engineer, SRE, Product Manager, and Devil's Advocate — independently critique it in parallel. Each persona has a distinct concern and a distinct failure mode they're looking for. A synthesis step surfaces contradictions between them.

**Average time per review: 48 seconds.**

Here are two real catches from production use.

---

## Catch #1: The 173-Workspace Outage That Didn't Happen

I was extracting our Terraform Cloud bootstrap config into a dedicated repo. The plan was straightforward: 3-day migration, Day 2 is the cutover.

The wrinkle: the shared agent token is a **write-only API field** (non-importable). You can't move it between Terraform state files. You have to create a new one during migration.

My plan said:
1. Apply new workspace (creates new token, writes to Vault)
2. Remove old token from old workspace
3. Done

Two personas independently found the same gap:

**SRE:**
> Between "new token written to Vault" and "old token destroyed" there is no verification that agents have picked up the new token. ESO sync + pod restart + agent reconnection is not instantaneous. A gap between token invalidation and agent pickup = org-wide outage for 173 workspaces.

**Devil's Advocate:**
> What happens if the new token is invalid? What if ESO takes 5 minutes to sync? What's the abort criteria?

The fix was obvious once stated:

```
1. Apply (new token in Vault)
2. Verify ESO ExternalSecret has synced
3. Trigger rolling restart of agent pods
4. Wait for 4/4 agents to show "idle" in TFC API
5. Only THEN remove old token
6. Abort: if <4 agents within 15 minutes, restore old token
```

**What would have happened without the review:** A "hope it works" gap during cutover. Best case: 5-15 minutes of queued CI jobs. Worst case: 173 workspaces unable to run until manual intervention, with no documented rollback path.

---

## Catch #2: A CI Design Disproven From Both Directions Simultaneously

A monorepo needed to know which apps were affected by workspace package changes. The plan's "Key Insight" was:

> When a workspace package changes, `pnpm-lock.yaml` changes. Use the lockfile as the CI trigger signal.

Sounds reasonable. An entire CI architecture was designed around it.

**Devil's Advocate found false negatives:**
> `workspace:*` resolves via symlinks. Editing source files in a workspace package does NOT change `pnpm-lock.yaml`. The thing you most want to detect produces no signal.

**SRE found false positives:**
> The lockfile changes for unrelated reasons: dependency resolution shifts, pnpm version bumps, hoisting changes. The signal fires on noise.

The Chair's synthesis:
> These are complementary failure modes that together invalidate the lockfile-as-signal premise from both directions. The plan simultaneously misses real changes and triggers on noise.

**What replaced it:** `pnpm nx show projects --affected` — 40 lines that understand the actual dependency graph. The original custom implementation would have been 3,291 lines that didn't work.

---

## How It Works

```bash
# Install (OpenCode — 10 seconds)
echo '{"plugin":["devils-council-opencode"]}' > .opencode/opencode.json

# Run on your plan
/devils-council:review path/to/PLAN.md

# Or try the built-in demo (no project needed)
/devils-council:demo
```

Four personas run in parallel. Each produces a structured scorecard with severity-rated findings. A Council Chair synthesizes contradictions without collapsing them into a scalar pass/fail. You get:

- **Staff Engineer:** over-engineering, wrong abstractions, YAGNI
- **SRE:** operational gaps, hand-wavy mitigations, missing runbooks
- **Product Manager:** scope creep, no business case, missing success criteria
- **Devil's Advocate:** circular reasoning, unstated assumptions, false confidence

Additional bench personas (Security, FinOps, Performance) activate automatically on structural signals — Helm changes wake the Dual-Deploy reviewer, AWS imports wake FinOps.

---

## The Pattern It Catches Most

**Circular risk mitigations.** In every third plan I review, the risk table looks like this:

| Risk | Mitigation |
|------|-----------|
| Consumer lag | "Auto-scaling handles this" |
| Render failure | "Circuit breaker handles this" |
| Cost overrun | "Rate limiting prevents this" |

The Devil's Advocate persona exists to ask: "How does auto-scaling handle this? What triggers it? What's the scaling lag? What happens to messages during the scale-up?" — and find that the answer is "I haven't thought about it yet, I just wrote something that sounds right."

---

## Try It

- **GitHub:** [astrowicked/devils-council](https://github.com/astrowicked/devils-council)
- **npm:** `devils-council-opencode`
- **Works with:** OpenCode, Claude Code
- **Demo:** `/devils-council:demo` (30 seconds, no project setup)
- **CI:** [GitHub Action](https://github.com/astrowicked/devils-council-action) posts findings on PRs automatically

MIT licensed. One maintainer. Built because I kept shipping plans with obvious-in-hindsight gaps.
