# Case Study: 3,291 Lines to Solve a Solved Problem

> A custom CI impact gate that grew to 3,291 lines of code — to solve a problem that standard monorepo tooling (Nx) handles in 40 lines. All three personas converged on the same diagnosis from different angles.

## The Plan (excerpt)

A frontend monorepo needed to determine which apps were affected by a PR before running expensive build/test pipelines. The existing solution was a custom "impact gate" that:

- Parsed `pnpm-lock.yaml` with a custom lockfile parser
- Built a dependency graph from the parsed lockfile
- Compared changed file paths against the graph
- Emitted per-app affected/not-affected decisions
- Required manual configuration updates for each new app onboarded

The plan proposed extending this system with additional path-matching rules, a new `libs/` directory concept, and more workflow YAML per app.

## What the Council Found

### Staff Engineer: Wrong abstraction boundary

> **Finding (BLOCKER):** 3,291 lines of custom impact-gate tooling exist because `libs/` was chosen over `packages/` — a decision that diverges from organizational convention (Nx workspaces) without a documented ADR. The entire custom CI infrastructure compensates for a standard-tooling-solvable problem.

### SRE: Silent single point of failure

> **Finding (BLOCKER):** The lockfile parser is a silent-failure single point of failure. A pnpm version upgrade will silently produce incorrect impact decisions — false negatives shipping untested code, or false positives blocking all PRs — with no schema-version assertion, no alerting, and no documented rollback mechanism.

### Product Manager: No maintenance ownership

> **Finding (BLOCKER):** All app teams depend on this tooling with no CODEOWNERS entry, no on-call designation, and no contract for resolution time when breakage blocks CI. Who gets paged when this breaks at 2am before a release?

### The comparison table the plan claimed:

| | Custom Impact Gate | Nx Affected |
|---|---|---|
| Lines of code | 3,291 | ~40 |
| Maintenance owner | "Upstream OSS" (false — it's internal) | Nx maintainers (actually true) |
| New app onboarding | Manual workflow YAML + config | Automatic (Nx project graph) |
| pnpm version coupling | Direct parser dependency | None (uses project graph) |

## What replaced it

The custom impact gate was removed. Replaced with:
```yaml
AFFECTED=$(pnpm nx show projects --affected --base="$NX_BASE" --head=HEAD --json)
```

40 lines. Zero custom parsers. Automatic app discovery. Maintained by the Nx team.

## Impact

Without the council review, the team would have continued extending a 3,291-line custom system that:
- Was already fragile (pnpm version coupling)
- Had no owner (maintenance orphan)
- Solved a problem that standard tooling handles better
- Would have grown further with each new app

**Time to find:** 48 seconds  
**Lines of code eventually deleted:** 3,291  
**Maintenance burden eliminated:** Infinite (custom parser tracking pnpm internals forever)
