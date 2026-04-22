#!/usr/bin/env bash
# smoke-codex.sh — End-to-end verification that Codex CLI works on this machine.
#
# Runs the known-good fixture prompt through `codex exec --json --sandbox read-only`
# and asserts the output is parseable JSON (single object or JSONL). This is the
# Phase 1 deliverable that de-risks Codex as a Phase 6 dependency per D-04.
#
# Exit codes:
#   0 — Codex is installed, authed, and produced parseable JSON output
#   1 — any precondition failure, invocation failure, or JSON parse failure
#
# Flags pinned (per STACK.md + D-02):
#   --json                — JSONL output (each line is a JSON object)
#   --sandbox read-only   — no writes, no network (D-02 default)
#   --skip-git-repo-check — fixture prompt is not inside a git repo context
#   --ephemeral           — don't persist session state (clean CI runs)
#   -o <file>             — capture final message to file

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FIXTURE="$SCRIPT_DIR/../tests/fixtures/smoke-prompt.txt"

err() { printf 'smoke-codex: ERROR: %s\n' "$*" >&2; }

# 1. codex binary on PATH
if ! command -v codex >/dev/null 2>&1; then
  err "codex CLI not found on PATH."
  err "Install: \`brew install --cask codex\` (macOS) or \`npm install -g @openai/codex\`"
  exit 1
fi

# 2. Authenticated
if ! codex login status >/dev/null 2>&1; then
  err "codex is not authenticated."
  err "Run \`codex login\` (browser OAuth) or \`echo \$OPENAI_API_KEY | codex login --with-api-key\`"
  exit 1
fi

# 3. Fixture present
if [ ! -f "$FIXTURE" ]; then
  err "fixture not found: $FIXTURE"
  exit 1
fi

# 4. Temp output, cleaned on exit
OUT="$(mktemp -t smoke-codex.XXXXXX)"
trap 'rm -f "$OUT"' EXIT

# 5. Invoke Codex non-interactively, piping the fixture on stdin.
#    `codex exec -` reads the prompt from stdin; flags are applied as documented.
if ! cat "$FIXTURE" | codex exec \
    --json \
    --sandbox read-only \
    --skip-git-repo-check \
    --ephemeral \
    -o "$OUT" \
    - >/dev/null 2>&1; then
  rc=$?
  err "codex exec failed with exit code $rc"
  exit 1
fi

# 6. Output non-empty
if [ ! -s "$OUT" ]; then
  err "codex produced no output (empty file: $OUT)"
  exit 1
fi

# 7. JSON parseability: try whole-file JSON first, fall back to JSONL (one JSON per line).
if ! jq -e . "$OUT" >/dev/null 2>&1; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ! printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
      err "JSON parse failed on line: $line"
      exit 1
    fi
  done < "$OUT"
fi

echo "smoke-codex: OK"
exit 0
