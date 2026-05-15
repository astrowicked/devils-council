---
description: "Run a devils-council review against a built-in flawed plan — see all personas in action in 60 seconds, no project setup needed."
---

Run a full adversarial review against the devils-council demo plan. This is a deliberately flawed notification service plan that demonstrates how each persona catches different categories of issues.

First, locate the demo plan. Check these paths in order:
1. `node_modules/devils-council-opencode/templates/demo-plan.md`
2. `~/.config/opencode/node_modules/devils-council-opencode/templates/demo-plan.md`
3. Use `find / -path "*/devils-council-opencode/templates/demo-plan.md" -maxdepth 6 2>/dev/null | head -1`

Read the demo plan file, then invoke `@council-review` against its full content.

After the review completes, print:

```
=== Demo Complete ===

To run this on YOUR plans:
  /devils-council-demo          (this command)
  @council-review <artifact>    (paste plan inline)

Output: .council/<timestamp>-<slug>/ with per-persona scorecards + SYNTHESIS.md
```
