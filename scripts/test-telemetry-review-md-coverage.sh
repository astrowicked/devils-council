#!/usr/bin/env bash
# Guard: both runtime review.md files must invoke bin/dc-telemetry.sh.
# CONTEXT.md CORR-01 — the two files are NOT shared; both must be edited.
# Catches Pitfall 1: silent single-runtime regression when a future
# contributor edits only one file.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

fail=0

# Each row: <file-path>:<runtime-flag-value>:<plugin-root-var>
CASES=(
  "commands/review.md:claude-code:CLAUDE_PLUGIN_ROOT"
  ".opencode/commands/review.md:opencode:DC_ROOT"
)

for row in "${CASES[@]}"; do
  file="${row%%:*}"; rest="${row#*:}"
  runtime="${rest%%:*}"; var="${rest#*:}"
  full="$REPO_ROOT/$file"
  if [ ! -f "$full" ]; then
    echo "FAIL: $file missing"; fail=1; continue
  fi
  # BSD/GNU portable: use `-e` so `--runtime=...` is not parsed as a flag.
  if ! grep -F -e "\${${var}}/bin/dc-telemetry.sh" "$full" >/dev/null; then
    echo "FAIL: $file does not invoke \${${var}}/bin/dc-telemetry.sh"; fail=1
  fi
  if ! grep -F -e "--runtime=${runtime}" "$full" >/dev/null; then
    echo "FAIL: $file missing --runtime=${runtime}"; fail=1
  fi
  if ! grep -F -e "& disown" "$full" >/dev/null; then
    echo "FAIL: $file missing '& disown' (foreground-blocking risk)"; fail=1
  fi
done

# Cross-guard: assert the dc-telemetry.sh invocation appears in EXACTLY 2 review.md files.
count=$(grep -l 'dc-telemetry.sh' \
          "$REPO_ROOT/commands/review.md" \
          "$REPO_ROOT/.opencode/commands/review.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$count" != "2" ]; then
  echo "FAIL: dc-telemetry.sh invocation found in $count review.md files (expected 2)"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: dc-telemetry.sh invocation present in both review.md files with correct runtime + & disown"
else
  exit 1
fi
