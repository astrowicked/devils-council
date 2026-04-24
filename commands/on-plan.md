---
name: on-plan
description: "Run devils-council review against a GSD phase's PLAN.md file(s). Auto-discovers all plans under .planning/phases/<NN>-*/<NN>-*-PLAN.md and routes each sequentially through /devils-council:review. Phase-num is an integer zero-padded internally."
argument-hint: "<phase-number>"
allowed-tools: [Bash, Read]
---

## Parse phase argument

The user passed a phase number as `$ARGUMENTS`. Validate and zero-pad:

!`set -e
PHASE="${ARGUMENTS:-}"
case "$PHASE" in
  ''|*[!0-9]*)
    echo "ERROR: /devils-council:on-plan requires an integer phase number. Got: '$PHASE'" >&2
    echo "Usage: /devils-council:on-plan <phase-number>" >&2
    exit 2
    ;;
esac
PADDED=$(printf '%02d' "$PHASE")
printf 'PADDED=%s\n' "$PADDED"`

## Discover plan files

!`set -e
PHASE="${ARGUMENTS:-}"
case "$PHASE" in
  ''|*[!0-9]*) exit 2 ;;
esac
PADDED=$(printf '%02d' "$PHASE")
shopt -s nullglob
PLANS=(.planning/phases/${PADDED}-*/${PADDED}-*-PLAN.md)
printf 'PLAN_COUNT=%d\n' "${#PLANS[@]}"
for p in "${PLANS[@]}"; do
  printf 'PLAN=%s\n' "$p"
done`

## Dispatch

Inspect the shell output above.

**If `PLAN_COUNT=0`:** emit exactly this line and STOP:
`No plans found for phase <N>. Expected .planning/phases/<NN>-*/<NN>-*-PLAN.md.`
(substitute the user's `<N>` — the unpadded phase number they passed).

**If `PLAN_COUNT` >= 1:** for each `PLAN=<path>` line above, invoke the slash command:

    /devils-council:review <path>

**Sequentially**, one plan at a time. Do NOT parallelize — each review writes its own `.council/<ts>-<slug>/` run dir; parallel execution would shard output without speedup and make dig follow-up harder.

After all plans reviewed, summarize:
- Number of plans reviewed
- Path of each `.council/<run>/` run dir produced (the most recent N entries under `.council/`)

This command is a thin wrapper — all reviewer logic lives in `/devils-council:review`. This file has ZERO awareness of GSD internals beyond the path convention `.planning/phases/<NN>-<slug>/<NN>-<plan-num>-PLAN.md`.
