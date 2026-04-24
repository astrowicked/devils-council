#!/usr/bin/env bash
# dc-gsd-wrap.sh — PostToolUse hook wrapper for GSD agent completions.
# Reads hook JSON from stdin. Gates on userConfig + GSD presence.
# Emits a one-line pointer to stdout per D-75 (does NOT invoke the slash command
# directly; hooks cannot dispatch slash commands — see RESEARCH.md Pitfall 7).
#
# Args: $1 = kind ("plan-checker" or "code-reviewer")
# Exit codes: 0 always (non-zero from a PostToolUse hook would break the user's turn)
set -euo pipefail

KIND="${1:-unknown}"

# Gate 1 — userConfig opt-in (GSDI-03). Default false.
# Claude Code exports CLAUDE_PLUGIN_OPTION_<UPPER_KEY>=<value> for every userConfig entry.
# Absent key = unset; treat as "false".
if [ "${CLAUDE_PLUGIN_OPTION_GSD_INTEGRATION:-false}" != "true" ]; then
  exit 0
fi

# Gate 2 — GSD presence (GSDI-04). Never fire if both agents absent.
if [ ! -f "$HOME/.claude/agents/gsd-plan-checker.md" ] \
   && [ ! -f "$HOME/.claude/agents/gsd-code-reviewer.md" ]; then
  exit 0
fi

# Read hook stdin JSON once (non-fatal if empty / malformed).
HOOK_JSON="$(cat || true)"
[ -z "$HOOK_JSON" ] && exit 0

# Extract prompt field (empty-string on absence — never fatal).
PROMPT="$(printf '%s' "$HOOK_JSON" | jq -r '.tool_input.prompt // ""' 2>/dev/null || printf '')"

ARTIFACT=""
case "$KIND" in
  plan-checker)
    # gsd-plan-checker's prompt lists PLAN.md files inside <files_to_read>.
    # Match .planning/phases/NN-<slug>/NN-NN-PLAN.md (GSD convention).
    ARTIFACT="$(printf '%s' "$PROMPT" | grep -oE '\.planning/phases/[0-9]{2}-[^/[:space:]]+/[0-9]{2}-[0-9]{2}-PLAN\.md' | head -1 || true)"
    ;;
  code-reviewer)
    # gsd-code-reviewer's prompt has YAML files: list. First file path wins.
    # Fallback: first relative path that looks like a source file.
    ARTIFACT="$(printf '%s' "$PROMPT" | awk '/^files:/{flag=1;next}/^[a-z_-]+:/{flag=0}flag && /^- /{sub(/^- /,""); print; exit}' || true)"
    ;;
  *)
    exit 0
    ;;
esac

# Extraction failure → exit silently. Never break the user's GSD flow.
[ -z "$ARTIFACT" ] && exit 0

# Emit pointer (D-75 semantic). Stdout is displayed to the user alongside the GSD agent's output.
printf '\n[devils-council: GSD %s completed; run `/devils-council:review %s` for adversarial critique]\n' "$KIND" "$ARTIFACT"

exit 0
