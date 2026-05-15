# Devils Council — Real-World Catches

These are anonymized case studies from production use of devils-council. Each shows a real architectural flaw, security gap, or design mistake that was caught during plan review — before any code was written.

**Average time to find each issue: 48 seconds** (parallel persona execution).

---

| # | Title | What Was Caught | Personas Involved |
|---|-------|-----------------|-------------------|
| 1 | [The 173-Workspace Outage](./01-173-workspace-outage.md) | Credential migration with no verification gate between "new cred created" and "old cred destroyed" | SRE + Devil's Advocate |
| 2 | [Signal Invalidated From Both Directions](./02-signal-invalidated-both-directions.md) | CI trigger premise disproven: false positives AND false negatives simultaneously | Devil's Advocate + SRE |
| 3 | [Plumbing Without Water](./03-plumbing-without-water.md) | 4 plans build tooling, none prove it works end-to-end | Product Manager + Staff Engineer |
| 4 | [The Threat Model Said It Was There](./04-threat-model-said-it-was-there.md) | Input validation claimed in threat model but never implemented | Devil's Advocate + SRE |
| 5 | [3,291 Lines to Solve a Solved Problem](./05-3291-lines-solved-problem.md) | Custom CI system for something standard tooling handles in 40 lines | Staff Engineer + SRE + PM (convergent) |

---

## Common Patterns

What the council catches repeatedly:

- **Circular risk mitigations** — "How do you handle X?" / "Y handles X" / "How does Y handle X?" / "..." 
- **Plumbing without water** — Infrastructure built but never validated with a real instance
- **Claimed vs actual security posture** — Threat models that say controls exist when they don't
- **Standard tooling avoidance** — Custom systems built when mature OSS solves the problem
- **Missing verification gates** — Steps that assume the previous step succeeded without checking

## Try It Yourself

```bash
# Install (OpenCode)
# Add to opencode.json: { "plugin": ["devils-council-opencode"] }

# Run demo (no project setup needed)
/devils-council:demo

# Review your own plans
/devils-council:review path/to/PLAN.md

# Review code diffs
/devils-council:on-code <phase-number>
```
