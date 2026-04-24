---
name: dig
description: "Ask a follow-up question scoped to ONE persona's scorecard from a prior review run. Spawns a single Agent() call with the persona's scorecard preloaded as <previous-scorecard> context. Does NOT re-review the underlying artifact — use /devils-council:review for that. Ephemeral: writes nothing to MANIFEST or the run dir."
argument-hint: "<persona> <run-id|latest> [question...]"
allowed-tools: [Bash, Read, Agent]
---

## Parse and validate arguments

!`set -e
# $ARGUMENTS: "<persona> <run-id|latest> [question...]"
PERSONA=$(printf '%s' "$ARGUMENTS" | awk '{print $1}')
RUN_ID=$(printf '%s' "$ARGUMENTS" | awk '{print $2}')
# Everything from field 3 onward is the question.
QUESTION=$(printf '%s' "$ARGUMENTS" | awk '{for(i=3;i<=NF;i++){printf "%s",$i; if(i<NF)printf " "}}')

if [ -z "$PERSONA" ] || [ -z "$RUN_ID" ]; then
  echo "ERROR: /devils-council:dig requires <persona> and <run-id>." >&2
  echo "Usage: /devils-council:dig <persona> <run-id|latest> [question]" >&2
  exit 2
fi

# Persona validation: lowercase letters + hyphens only (matches existing agents/*.md slug pattern).
# Regex [a-z][a-z-]* rejects uppercase, digits, dots, slashes, and all shell metachars.
if ! printf '%s' "$PERSONA" | grep -qE '^[a-z][a-z-]*$'; then
  echo "ERROR: persona must match [a-z][a-z-]* (e.g., staff-engineer, security-reviewer). Got: '$PERSONA'" >&2
  echo "Available personas:" >&2
  if [ -d "${CLAUDE_PLUGIN_ROOT:-.}/agents" ]; then
    (cd "${CLAUDE_PLUGIN_ROOT:-.}/agents" && ls -1 *.md 2>/dev/null | grep -v -iE '^README' | sed 's/\.md$//' | sed 's/^/  /') >&2
  fi
  exit 2
fi

# Run-id path-traversal defense (T-08-04): reject slashes, '..', and leading '.' BEFORE any filesystem access.
# Patterns: */* rejects any slash; *..* rejects parent-dir refs; .* rejects hidden/relative names.
case "$RUN_ID" in
  */*|*..*|.*)
    echo "ERROR: run-id must be full directory name under .council/ (or the sentinel \`latest\`). No slashes, no '..', no leading '.'. Got: '$RUN_ID'" >&2
    exit 2
    ;;
esac

printf 'PERSONA=%s\n' "$PERSONA"
printf 'RUN_ID_INPUT=%s\n' "$RUN_ID"
printf 'QUESTION=%s\n' "$QUESTION"`

## Resolve run-id (handle `latest` sentinel)

!`set -e
PERSONA=$(printf '%s' "$ARGUMENTS" | awk '{print $1}')
RUN_ID=$(printf '%s' "$ARGUMENTS" | awk '{print $2}')
# Re-apply path-traversal defense (belt-and-suspenders; each shell block is independent).
case "$RUN_ID" in */*|*..*|.*) exit 2 ;; esac

if [ ! -d .council ]; then
  echo "ERROR: no .council/ directory — no prior runs to dig into." >&2
  exit 2
fi

if [ "$RUN_ID" = "latest" ]; then
  # Portable newest-subdir resolution across macOS (BSD) and Linux (GNU).
  # `ls -td */` lists only directories (trailing slash), newest first.
  # responses.md is a FILE (not matched by */), so it is excluded automatically.
  RESOLVED=$(cd .council && ls -td */ 2>/dev/null | head -1 | sed 's:/$::')
  if [ -z "$RESOLVED" ]; then
    echo "ERROR: no run dirs found under .council/ (only .council/responses.md may exist)." >&2
    exit 2
  fi
  RUN_ID="$RESOLVED"
fi

if [ ! -d ".council/$RUN_ID" ]; then
  echo "ERROR: .council/$RUN_ID is not a directory." >&2
  echo "run-id must be full directory name under .council/ (or the sentinel \`latest\`)." >&2
  echo "Available run dirs:" >&2
  (cd .council && ls -td */ 2>/dev/null | head -5 | sed 's:/$::' | sed 's/^/  /') >&2
  exit 2
fi

# Validate persona scorecard exists in run dir.
if [ ! -f ".council/$RUN_ID/$PERSONA.md" ]; then
  echo "ERROR: .council/$RUN_ID/$PERSONA.md does not exist." >&2
  echo "Available scorecards in this run:" >&2
  (cd ".council/$RUN_ID" && ls -1 *.md 2>/dev/null | grep -v -E '^(INPUT|MANIFEST|SYNTHESIS)\.md$' | sed 's/\.md$//' | sed 's/^/  /') >&2
  exit 2
fi

printf 'RUN_ID=%s\n' "$RUN_ID"
printf 'SCORECARD_PATH=%s\n' ".council/$RUN_ID/$PERSONA.md"`

## Load scorecard content

!`set -e
PERSONA=$(printf '%s' "$ARGUMENTS" | awk '{print $1}')
RUN_ID_RAW=$(printf '%s' "$ARGUMENTS" | awk '{print $2}')
case "$RUN_ID_RAW" in */*|*..*|.*) exit 2 ;; esac
case "$PERSONA" in *[!a-z-]*|'') exit 2 ;; esac

if [ "$RUN_ID_RAW" = "latest" ]; then
  RUN_ID=$(cd .council && ls -td */ 2>/dev/null | head -1 | sed 's:/$::')
else
  RUN_ID="$RUN_ID_RAW"
fi

# Emit the scorecard path for reference; the Agent spawn below embeds full content.
# Quoted variables — no word-splitting or glob expansion on untrusted input.
echo "--- scorecard: .council/$RUN_ID/$PERSONA.md ---"
cat ".council/$RUN_ID/$PERSONA.md"
echo "--- end scorecard ---"`

## Spawn follow-up agent

Use the `Agent` tool with:
- `subagent_type`: the persona slug from `$ARGUMENTS` (field 1), e.g., `staff-engineer`, `security-reviewer`. The slug must have passed the `[a-z][a-z-]*` regex validation above.
- `prompt`: the exact template below, substituting the scorecard content loaded above for `<SCORECARD_CONTENT>` and the user's question for `<USER_QUESTION>`.

### Agent prompt template

```
<previous-scorecard persona="<PERSONA>" run-id="<RUN_ID>">
<SCORECARD_CONTENT>
</previous-scorecard>

<user-question>
<USER_QUESTION>
</user-question>

Elaborate on your prior scorecard above. Justify, extend, or provide rationale for the findings. Use finding IDs (format: <persona-slug>-<8hex>, from the scorecard frontmatter) when referencing specific findings.

Do NOT re-critique the underlying artifact — the review is complete; this is follow-up on your prior output only. If the user asks about the artifact itself (not your findings), respond: "That would require a fresh review. Run /devils-council:review <artifact> to re-examine."
```

### Render

Render the Agent's response inline. Do NOT:
- Create a new `.council/<ts>-<slug>/` run dir
- Write to `MANIFEST.json` in the existing run dir
- Spawn additional agents (Council Chair, validator, prep)
- Modify `.council/responses.md`

Dig is purely ephemeral Q&A. Per D-78: "one Agent() call, no fan-out, no Chair, no MANIFEST writes." The command writes nothing to MANIFEST; the scorecard preload is the only state touched, and it is read-only.

## Explicitly NOT in this flow

- **No Council Chair synthesis.** Dig is single-persona by design. For multi-persona Q&A, re-run `/devils-council:review`.
- **No re-validation.** The scorecard was validated when it was written (Phase 3 `bin/dc-validate-scorecard.sh`). Dig reads it as-is.
- **No artifact re-read.** Dig does not read `.council/<run-id>/INPUT.md`. The persona's prior findings are the sole context. This is why dig is cheap: one Agent() call with a bounded context, no fan-out.
- **No new run dir.** Dig is ephemeral — the Agent's response renders inline and is not archived to `.council/`.
- **No MANIFEST writes.** Dig never touches `.council/<run-id>/MANIFEST.json`. The ephemeral invariant is verified structurally by `scripts/test-dig-spawn.sh`.
