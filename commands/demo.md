---
name: demo
description: "Run a devils-council review against a built-in flawed plan to see the plugin in action. No project setup required — demonstrates all persona types finding real issues in 60 seconds."
argument-hint: "[--quiet]"
allowed-tools: [Bash, Read, Write, Agent]
---

## Overview

This command runs a full council review against a **deliberately flawed** notification service plan bundled with the plugin. It demonstrates how each persona catches different categories of issues:

- **Staff Engineer** → over-engineering (Task 2's template A/B testing framework for a notification service)
- **SRE** → operational gaps (no runbook, no rollback plan, "auto-scaling" as a non-mitigation)
- **Product Manager** → missing business justification (multi-region active-active for a notification service?)
- **Devil's Advocate** → circular reasoning in risk mitigations ("the circuit breaker handles this")

## Execution

Copy the demo plan to a temp location and run the review:

!`set -e
DEMO_PLAN="${CLAUDE_PLUGIN_ROOT}/templates/demo-plan.md"
if [ ! -f "$DEMO_PLAN" ]; then
  echo "ERROR: Demo plan not found at $DEMO_PLAN" >&2
  exit 2
fi
DEMO_DIR="/tmp/devils-council-demo-$$"
mkdir -p "$DEMO_DIR"
cp "$DEMO_PLAN" "$DEMO_DIR/PLAN.md"
echo "DEMO_ARTIFACT=$DEMO_DIR/PLAN.md"
echo ""
echo "=== Devils Council Demo ==="
echo "Reviewing a deliberately flawed notification service plan..."
echo "The plan contains: over-engineering, circular risk mitigations,"
echo "missing operational details, and unjustified architectural scope."
echo ""
echo "Watch how each persona catches different issues."
echo ""`

## Route to review

Now invoke the full `/devils-council:review` command against the demo plan.
Pass the artifact path from above as the argument:

Run `/devils-council:review $DEMO_DIR/PLAN.md --type=plan`

When the review completes, print a summary for the user:

```
=== Demo Complete ===

The council found issues that would have shipped without review:
- Staff Engineer caught over-engineering (template A/B framework, multi-region for notifications)
- SRE caught hand-wavy mitigations ("auto-scaling is configured" isn't a real answer)
- Product Manager caught scope creep with no business case
- Devil's Advocate caught circular reasoning in the risk table

To run this on YOUR plans:
  /devils-council:review path/to/your/PLAN.md
  /devils-council:on-plan <phase-number>     (for GSD projects)
  /devils-council:on-code <phase-number>     (for code diffs)

Output lives in .council/<timestamp>-<slug>/ with per-persona scorecards + SYNTHESIS.md
```

## Cleanup

!`rm -rf "$DEMO_DIR" 2>/dev/null || true`
