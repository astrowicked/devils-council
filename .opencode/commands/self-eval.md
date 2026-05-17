---
description: "Run the devils-council self-evaluation benchmark — measures finding recall, precision, and regression against version-pinned baselines."
---

## Resolve paths

!`set -e
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "$CLAUDE_PLUGIN_ROOT/bin" ]; then
  echo "DC_ROOT=$CLAUDE_PLUGIN_ROOT"
elif [ -d "$HOME/.cache/opencode/packages/devils-council-opencode@latest/node_modules/devils-council-opencode/bin" ]; then
  echo "DC_ROOT=$HOME/.cache/opencode/packages/devils-council-opencode@latest/node_modules/devils-council-opencode"
elif [ -d "$HOME/.claude/plugins/devils-council/bin" ]; then
  echo "DC_ROOT=$HOME/.claude/plugins/devils-council"
else
  DC=$(find "$HOME/.cache/opencode" "$HOME/.claude/plugins" -path "*/devils-council*/bin/dc-self-eval.py" 2>/dev/null | head -1)
  if [ -n "$DC" ]; then
    echo "DC_ROOT=$(dirname "$(dirname "$DC")")"
  else
    echo "DC_ROOT=ERROR:not-found"
  fi
fi

if [ -d "benchmarks" ]; then
  echo "BENCH_DIR=benchmarks"
elif [ -d "${DC_ROOT:-}/benchmarks" ]; then
  echo "BENCH_DIR=${DC_ROOT}/benchmarks"
else
  echo "BENCH_DIR=ERROR:not-found"
fi`

If `DC_ROOT=ERROR:not-found`, STOP and tell the user to ensure the plugin is installed.
If `BENCH_DIR=ERROR:not-found`, STOP and tell the user to run from the devils-council repo root.

## Run the benchmark corpus

For each item in `benchmarks/MANIFEST.json`, run the council against it:

!`set -e
if [ -d "benchmarks/corpus" ]; then
  echo "CORPUS_COUNT=$(ls benchmarks/corpus/ | wc -l | tr -d ' ')"
  ls benchmarks/corpus/
fi`

For each corpus file listed above, invoke:

```
/devils-council:review benchmarks/corpus/<filename> --type=<type>
```

Where `<type>` comes from the MANIFEST.json entry for that item (plan, code-diff, or rfc).

Run them sequentially. After ALL reviews complete, run the evaluation:

!`python3 "${DC_ROOT}/bin/dc-self-eval.py" --results-dir .council 2>&1`

## Report results

Print the self-eval output verbatim. If the verdict is PASS or WARN, the benchmark succeeded. If BLOCK, there's a regression that needs investigation.

## Optional flags

If `$ARGUMENTS` contains `--pin <version>`:
!`python3 "${DC_ROOT}/bin/dc-self-eval.py" --pin "$VERSION" 2>&1`

If `$ARGUMENTS` contains `--compare <version>`:
!`python3 "${DC_ROOT}/bin/dc-self-eval.py" --compare "$VERSION" --results-dir .council 2>&1`

If `$ARGUMENTS` contains `--item <id>`:
Only run the council against that single corpus item, then evaluate.
