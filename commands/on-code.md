---
name: on-code
description: "Run devils-council review against a GSD phase's committed diffs. Resolves the phase-start commit via `git log --diff-filter=A` against the phase's first PLAN file, diffs anchor..HEAD, and routes through /devils-council:review as a code-diff artifact. Optional --from <ref> fallback when the phase's planning docs were not committed (commit_docs=false / .planning gitignored projects)."
argument-hint: "<phase-number> [--from <git-ref>]"
allowed-tools: [Bash, Read]
---

## Parse arguments

!`set -e
PHASE_NUM=""
FROM_REF=""
next_is_from=0
for arg in $ARGUMENTS; do
  if [ "$next_is_from" = "1" ]; then
    FROM_REF="$arg"
    next_is_from=0
    continue
  fi
  case "$arg" in
    --from=*) FROM_REF="${arg#--from=}" ;;
    --from)   next_is_from=1 ;;
    -*)
      echo "ERROR: unknown flag: $arg" >&2
      echo "Usage: /devils-council:on-code <phase-number> [--from <git-ref>]" >&2
      exit 2
      ;;
    *)
      if [ -z "$PHASE_NUM" ]; then
        PHASE_NUM="$arg"
      fi
      ;;
  esac
done
case "$PHASE_NUM" in
  ''|*[!0-9]*)
    echo "ERROR: /devils-council:on-code requires an integer phase number. Got: '$PHASE_NUM'" >&2
    echo "Usage: /devils-council:on-code <phase-number> [--from <git-ref>]" >&2
    exit 2
    ;;
esac
PADDED=$(printf '%02d' "$PHASE_NUM")
printf 'PHASE_NUM=%s\n' "$PHASE_NUM"
printf 'PADDED=%s\n' "$PADDED"
printf 'FROM_REF=%s\n' "$FROM_REF"`

## Resolve phase-start commit anchor

!`set -e
# Re-parse args within this block (each shell-injection runs in its own subshell).
PHASE_NUM=""
FROM_REF=""
next_is_from=0
for arg in $ARGUMENTS; do
  if [ "$next_is_from" = "1" ]; then FROM_REF="$arg"; next_is_from=0; continue; fi
  case "$arg" in
    --from=*) FROM_REF="${arg#--from=}" ;;
    --from)   next_is_from=1 ;;
    -*)       exit 2 ;;
    *)        [ -z "$PHASE_NUM" ] && PHASE_NUM="$arg" ;;
  esac
done
case "$PHASE_NUM" in ''|*[!0-9]*) exit 2 ;; esac
PADDED=$(printf '%02d' "$PHASE_NUM")

# --diff-filter=A finds commits that ADDED the file (first occurrence).
# | tail -1 picks the oldest such commit (the one that introduced the phase).
ANCHOR=$(git log --diff-filter=A --pretty=format:%H -- ".planning/phases/${PADDED}-*/${PADDED}-01-PLAN.md" 2>/dev/null | tail -1 || true)

if [ -z "$ANCHOR" ]; then
  if [ -n "$FROM_REF" ]; then
    # Validate --from ref exists via rev-parse --verify (defense-in-depth against
    # arg injection per T-08-02 — rev-parse rejects shell metachars and resolves
    # only valid refs). The "^{commit}" suffix forces commit-object resolution.
    if git rev-parse --verify "${FROM_REF}^{commit}" >/dev/null 2>&1; then
      ANCHOR=$(git rev-parse --verify "${FROM_REF}^{commit}")
    else
      echo "ERROR: --from ref '$FROM_REF' not found in this repository." >&2
      exit 2
    fi
  else
    echo "No phase-start anchor found for phase ${PHASE_NUM}. Use --from <ref> to specify base." >&2
    echo "(This is common when .planning/ is gitignored per commit_docs=false.)" >&2
    exit 2
  fi
fi
printf 'ANCHOR=%s\n' "$ANCHOR"`

## Produce diff

!`set -e
PHASE_NUM=""
FROM_REF=""
next_is_from=0
for arg in $ARGUMENTS; do
  if [ "$next_is_from" = "1" ]; then FROM_REF="$arg"; next_is_from=0; continue; fi
  case "$arg" in
    --from=*) FROM_REF="${arg#--from=}" ;;
    --from)   next_is_from=1 ;;
    -*)       exit 2 ;;
    *)        [ -z "$PHASE_NUM" ] && PHASE_NUM="$arg" ;;
  esac
done
case "$PHASE_NUM" in ''|*[!0-9]*) exit 2 ;; esac
PADDED=$(printf '%02d' "$PHASE_NUM")
ANCHOR=$(git log --diff-filter=A --pretty=format:%H -- ".planning/phases/${PADDED}-*/${PADDED}-01-PLAN.md" 2>/dev/null | tail -1 || true)
if [ -z "$ANCHOR" ] && [ -n "$FROM_REF" ]; then
  if git rev-parse --verify "${FROM_REF}^{commit}" >/dev/null 2>&1; then
    ANCHOR=$(git rev-parse --verify "${FROM_REF}^{commit}")
  else
    exit 2
  fi
fi
[ -z "$ANCHOR" ] && exit 2
DIFF_FILE=$(mktemp -t dc-on-code-XXXXXX).patch
git diff "${ANCHOR}..HEAD" > "$DIFF_FILE"
SIZE=$(wc -c < "$DIFF_FILE" | awk '{print $1}')
printf 'DIFF_FILE=%s\n' "$DIFF_FILE"
printf 'DIFF_BYTES=%s\n' "$SIZE"`

## Dispatch

If `DIFF_BYTES=0`, the diff range is empty. Emit: `Phase ${PHASE_NUM} has no code changes since anchor ${ANCHOR:0:12}.` and STOP.

Otherwise, invoke:

    /devils-council:review <DIFF_FILE> --type=code-diff

where `<DIFF_FILE>` is the path from the shell output. After the review completes, print the run-dir path under `.council/` so the user can dig follow-up questions.

This command is a thin wrapper — all reviewer logic lives in `/devils-council:review`. This file has ZERO awareness of GSD internals beyond the path convention `.planning/phases/<NN>-<slug>/<NN>-01-PLAN.md` and the `git log --diff-filter=A` anchor recipe.
