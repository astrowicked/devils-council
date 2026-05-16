# Case Study: Signal Invalidated From Both Directions

> A CI architecture plan whose core premise was disproven by two personas finding complementary failure modes — false positives AND false negatives simultaneously — making the entire design unfounded.

## The Plan (excerpt)

A monorepo needed a CI gate to detect which apps were affected by workspace package changes. The plan's **"Key Insight"** was:

> "When a workspace package changes, `pnpm-lock.yaml` changes. We use the lockfile as the CI trigger signal — if it changed, rebuild affected apps."

The plan built an entire CI architecture around this premise: path filters on `pnpm-lock.yaml`, per-app workflow triggers, and a custom impact-detection gate.

## What the Council Found

### Devil's Advocate: The signal has FALSE NEGATIVES

> **Finding (BLOCKER):** `workspace:*` resolves via symlinks during install. Editing source files in a workspace package does NOT change `pnpm-lock.yaml`. Source edits are **invisible** to the lockfile. The "Key Insight" is factually incorrect — the thing you most want to detect (code changes) produces no signal.

### SRE: The signal has FALSE POSITIVES

> **Finding (BLOCKER):** The lockfile changes for reasons unrelated to your packages: dependency resolution shifts, pnpm version bumps, hoisting algorithm changes. The signal fires on **noise** — unrelated changes trigger unnecessary rebuilds.

### The contradiction the Chair surfaced

> These are complementary failure modes that together invalidate the lockfile-as-signal premise from both directions. The plan simultaneously:
> - Misses real changes (false negatives from source edits)  
> - Triggers on noise (false positives from unrelated dep changes)
>
> The "Key insight" underpinning the entire CI triggering narrative is unfounded.

## What replaced it

The plan was rewritten to use `nx affected` (which understands the actual dependency graph) instead of lockfile heuristics. The custom 3,291-line impact gate was replaced with a 40-line Nx affected check.

## Impact

This would have shipped a CI system that:
- **Silently skipped testing** when workspace package source code changed (the exact scenario it was built to catch)
- **Burned CI minutes** on unrelated lockfile changes
- Created false confidence that "if CI passes, packages are tested"

**Time to find:** 48 seconds  
**Alternative discovery method:** Weeks of "why didn't CI catch this regression?" debugging after a broken package shipped.
