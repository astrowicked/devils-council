---
description: |
  Run devils-council review against a GSD phase's committed code diffs.
  
  USE THIS WHEN: You've completed implementation for a phase and want adversarial review of the actual code changes (not planning docs).
  
  HOW IT WORKS:
  1. Resolves the phase-start commit via `git log --diff-filter=A` against the phase's first PLAN file
  2. Produces a diff from anchor..HEAD
  3. Routes through /devils-council:review as a code-diff artifact
  
  FLAGS:
  - --from <ref>: Explicit base ref (required when .planning/ is gitignored, or when using --dir)
  - --dir <path>: Git directory to diff. USE THIS FOR MULTI-REPO WORKSPACES where code lives in a sub-repo (e.g., infra/, services/) separate from the .planning/ root.
  
  MULTI-REPO WORKSPACES:
  If your workspace has sub-repos (e.g., root only tracks .planning/, code is in infra/):
    /devils-council:on-code 4 --dir ./infra --from origin/main
  Run once per sub-repo that has changes. The root repo diff will only contain .planning/ docs — that's not what you want to review.
  
  COMMON ERRORS:
  - "artifact > 100KB" → Exclude generated files: use --dir to target only the source sub-repo, or manually build a filtered diff and use /devils-council:review <file> --type=code-diff
  - "No phase-start anchor found" → .planning/ is gitignored or you're in --dir mode. Provide --from <ref> explicitly.
  - "python3 with ast/json/re/hashlib required" → System Python missing. Install Python 3.9+ or ensure python3 is on PATH.
---

## Parse arguments

!`set -e
PHASE_NUM=""
FROM_REF=""
GIT_DIR=""
next_is_from=0
next_is_dir=0
for arg in $ARGUMENTS; do
  if [ "$next_is_from" = "1" ]; then
    FROM_REF="$arg"
    next_is_from=0
    continue
  fi
  if [ "$next_is_dir" = "1" ]; then
    GIT_DIR="$arg"
    next_is_dir=0
    continue
  fi
  case "$arg" in
    --from=*) FROM_REF="${arg#--from=}" ;;
    --from)   next_is_from=1 ;;
    --dir=*)  GIT_DIR="${arg#--dir=}" ;;
    --dir)    next_is_dir=1 ;;
    -*)
      echo "ERROR: unknown flag: $arg" >&2
      echo "Usage: /devils-council:on-code <phase-number> [--from <git-ref>] [--dir <path>]" >&2
      echo "" >&2
      echo "For multi-repo workspaces where code lives in a sub-repo:" >&2
      echo "  /devils-council:on-code 4 --dir ./infra --from origin/main" >&2
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
    echo "Usage: /devils-council:on-code <phase-number> [--from <git-ref>] [--dir <path>]" >&2
    exit 2
    ;;
esac
# Validate --dir if provided
if [ -n "$GIT_DIR" ]; then
  if [ ! -d "$GIT_DIR" ]; then
    echo "ERROR: --dir path does not exist: $GIT_DIR" >&2
    exit 2
  fi
  if ! git -C "$GIT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    echo "ERROR: --dir path is not a git repository: $GIT_DIR" >&2
    echo "Hint: --dir must point to a directory containing a .git folder (a sub-repo root)." >&2
    exit 2
  fi
  # --dir mode requires --from (sub-repo has no .planning/ to resolve anchor from)
  if [ -z "$FROM_REF" ]; then
    echo "ERROR: --dir requires --from <ref> (sub-repo has no .planning/ to auto-resolve anchor)." >&2
    echo "" >&2
    echo "Common usage:" >&2
    echo "  /devils-council:on-code $PHASE_NUM --dir $GIT_DIR --from origin/main" >&2
    echo "" >&2
    echo "Use the branch point your feature diverged from (usually origin/main or origin/develop)." >&2
    exit 2
  fi
fi
PADDED=$(printf '%02d' "$PHASE_NUM")
printf 'PHASE_NUM=%s\n' "$PHASE_NUM"
printf 'PADDED=%s\n' "$PADDED"
printf 'FROM_REF=%s\n' "$FROM_REF"
printf 'GIT_DIR=%s\n' "$GIT_DIR"`

## Resolve phase-start commit anchor

!`set -e
# Re-parse args within this block (each shell-injection runs in its own subshell).
PHASE_NUM=""
FROM_REF=""
GIT_DIR=""
next_is_from=0
next_is_dir=0
for arg in $ARGUMENTS; do
  if [ "$next_is_from" = "1" ]; then FROM_REF="$arg"; next_is_from=0; continue; fi
  if [ "$next_is_dir" = "1" ]; then GIT_DIR="$arg"; next_is_dir=0; continue; fi
  case "$arg" in
    --from=*) FROM_REF="${arg#--from=}" ;;
    --from)   next_is_from=1 ;;
    --dir=*)  GIT_DIR="${arg#--dir=}" ;;
    --dir)    next_is_dir=1 ;;
    -*)       exit 2 ;;
    *)        [ -z "$PHASE_NUM" ] && PHASE_NUM="$arg" ;;
  esac
done
case "$PHASE_NUM" in ''|*[!0-9]*) exit 2 ;; esac
PADDED=$(printf '%02d' "$PHASE_NUM")

# Determine which git command prefix to use
GIT_CMD="git"
if [ -n "$GIT_DIR" ]; then
  GIT_CMD="git -C $GIT_DIR"
fi

if [ -n "$GIT_DIR" ]; then
  # --dir mode: anchor comes from --from (validated in parse step)
  ANCHOR=$($GIT_CMD rev-parse --verify "${FROM_REF}^{commit}" 2>/dev/null || true)
  if [ -z "$ANCHOR" ]; then
    echo "ERROR: --from ref '$FROM_REF' not found in repo at '$GIT_DIR'." >&2
    echo "Check that '$FROM_REF' exists: git -C $GIT_DIR branch -a | grep $FROM_REF" >&2
    exit 2
  fi
else
  # Standard mode: resolve from .planning/ PLAN file commit history
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
      echo "ERROR: No phase-start anchor found for phase ${PHASE_NUM}." >&2
      echo "" >&2
      echo "This happens when:" >&2
      echo "  - .planning/ is gitignored (commit_docs=false)" >&2
      echo "  - Code lives in a different repo than .planning/ (multi-repo workspace)" >&2
      echo "" >&2
      echo "Solutions:" >&2
      echo "  1. Provide --from <ref>:  /devils-council:on-code $PHASE_NUM --from origin/main" >&2
      echo "  2. For sub-repos:         /devils-council:on-code $PHASE_NUM --dir ./infra --from origin/main" >&2
      exit 2
    fi
  fi
fi
printf 'ANCHOR=%s\n' "$ANCHOR"`

## Produce diff

!`set -e
PHASE_NUM=""
FROM_REF=""
GIT_DIR=""
next_is_from=0
next_is_dir=0
for arg in $ARGUMENTS; do
  if [ "$next_is_from" = "1" ]; then FROM_REF="$arg"; next_is_from=0; continue; fi
  if [ "$next_is_dir" = "1" ]; then GIT_DIR="$arg"; next_is_dir=0; continue; fi
  case "$arg" in
    --from=*) FROM_REF="${arg#--from=}" ;;
    --from)   next_is_from=1 ;;
    --dir=*)  GIT_DIR="${arg#--dir=}" ;;
    --dir)    next_is_dir=1 ;;
    -*)       exit 2 ;;
    *)        [ -z "$PHASE_NUM" ] && PHASE_NUM="$arg" ;;
  esac
done
case "$PHASE_NUM" in ''|*[!0-9]*) exit 2 ;; esac
PADDED=$(printf '%02d' "$PHASE_NUM")

# Determine git command prefix
GIT_CMD="git"
if [ -n "$GIT_DIR" ]; then
  GIT_CMD="git -C $GIT_DIR"
fi

# Re-resolve anchor (same logic as previous block)
if [ -n "$GIT_DIR" ]; then
  ANCHOR=$($GIT_CMD rev-parse --verify "${FROM_REF}^{commit}" 2>/dev/null || exit 2)
else
  ANCHOR=$(git log --diff-filter=A --pretty=format:%H -- ".planning/phases/${PADDED}-*/${PADDED}-01-PLAN.md" 2>/dev/null | tail -1 || true)
  if [ -z "$ANCHOR" ] && [ -n "$FROM_REF" ]; then
    if git rev-parse --verify "${FROM_REF}^{commit}" >/dev/null 2>&1; then
      ANCHOR=$(git rev-parse --verify "${FROM_REF}^{commit}")
    else
      exit 2
    fi
  fi
fi
[ -z "$ANCHOR" ] && exit 2

DIFF_FILE=$(mktemp -t dc-on-code-XXXXXX).patch
$GIT_CMD diff "${ANCHOR}..HEAD" > "$DIFF_FILE"
SIZE=$(wc -c < "$DIFF_FILE" | awk '{print $1}')
printf 'DIFF_FILE=%s\n' "$DIFF_FILE"
printf 'DIFF_BYTES=%s\n' "$SIZE"
if [ "$SIZE" -gt 102400 ]; then
  printf 'WARNING: Diff is %s bytes (>100KB). dc-prep.sh will reject it.\n' "$SIZE" >&2
  printf 'Tip: Filter the diff to source code only. Example:\n' >&2
  printf '  %s diff %s..HEAD -- "src/**" "lib/**" > /tmp/filtered.patch\n' "$GIT_CMD" "${ANCHOR:0:12}" >&2
  printf '  /devils-council:review /tmp/filtered.patch --type=code-diff\n' >&2
fi`

## Dispatch

If `DIFF_BYTES=0`, the diff range is empty. Emit: `Phase ${PHASE_NUM} has no code changes since anchor ${ANCHOR:0:12}.` and STOP.

If `DIFF_BYTES` exceeds 100KB (102400 bytes), the diff is too large for dc-prep.sh. Do NOT invoke /devils-council:review — it will fail at the size guard. Instead, advise the user:

> The diff is ${DIFF_BYTES} bytes (exceeds 100KB limit). To review, filter to source code only:
>
> ```bash
> git [-C <dir>] diff <anchor>..HEAD -- "src/**" "lib/**" "*.py" > /tmp/filtered.patch
> ```
>
> Then invoke directly: `/devils-council:review /tmp/filtered.patch --type=code-diff`

Otherwise, invoke:

    /devils-council:review <DIFF_FILE> --type=code-diff

where `<DIFF_FILE>` is the path from the shell output. After the review completes, print the run-dir path under `.council/` so the user can dig follow-up questions.

This command is a thin wrapper — all reviewer logic lives in `/devils-council:review`. This file has ZERO awareness of GSD internals beyond the path convention `.planning/phases/<NN>-<slug>/<NN>-01-PLAN.md` and the `git log --diff-filter=A` anchor recipe.
