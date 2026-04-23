#!/usr/bin/env bash
# scripts/test-coexistence.sh — HARD-05 static collision-check.
#
# Asserts devils-council's plugin surface does not collide with installed
# Superpowers OR GSD artifacts at standard paths. Does NOT install anything;
# does NOT run `claude` headlessly. Expected runtime: <2s.
#
# Environments:
#   1. CI (GitHub Actions): Superpowers + GSD absent — A3/A5 SKIP, others run.
#   2. Andy's dev machine: all three present; full cross-check runs.
#   3. End-user install: typically devils-council + Superpowers; A5 may SKIP.
#
# Exit codes:
#   0 — all applicable assertions passed (SKIP counts as pass)
#   1 — collision detected (real failure)
#   2 — usage error / malformed devils-council plugin.json

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

FAIL=0
PASS_COUNT=0
SKIP_COUNT=0
pass() { printf 'PASS: %s\n' "$*"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }
skip() { printf 'SKIP: %s\n' "$*"; SKIP_COUNT=$((SKIP_COUNT+1)); }

# ---- A1: devils-council plugin name is not reserved ----
if [ ! -f .claude-plugin/plugin.json ]; then
  echo "USAGE ERROR: .claude-plugin/plugin.json missing; cannot run coexistence check" >&2
  exit 2
fi
DC_NAME=$(jq -r '.name // empty' .claude-plugin/plugin.json)
case "$DC_NAME" in
  claude-code-plugins|claude-plugins-official|anthropic-marketplace|anthropic-plugins)
    fail "A1: plugin name '$DC_NAME' is RESERVED by Anthropic (publish will fail)" ;;
  devils-council)
    pass "A1: plugin name 'devils-council' is non-reserved" ;;
  "")
    fail "A1: plugin.json .name is missing or empty" ;;
  *)
    fail "A1: plugin name '$DC_NAME' is unexpected — update this test if rename was intentional" ;;
esac

# ---- A2: no .mcp.json at repo root (PLUG-05 v1 scope) ----
if [ -f "$REPO_ROOT/.mcp.json" ]; then
  fail "A2: v1 scope forbids MCP server; remove .mcp.json or amend PLUG-05"
else
  pass "A2: no .mcp.json (PLUG-05 v1 scope holds)"
fi

# ---- A3: no command filename collision with Superpowers ----
SP_CACHE="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
if [ -d "$SP_CACHE" ]; then
  # Pick the highest-versioned directory (Superpowers versions are SemVer tags).
  SP_VER=$(ls "$SP_CACHE" 2>/dev/null | sort -V | tail -n1 || true)
  SP_CMDS=""
  if [ -n "$SP_VER" ]; then
    SP_CMDS="$SP_CACHE/$SP_VER/commands"
  fi
  if [ -n "$SP_CMDS" ] && [ -d "$SP_CMDS" ]; then
    COLLISIONS=0
    for cmd in "$REPO_ROOT"/commands/*.md; do
      [ -f "$cmd" ] || continue
      base=$(basename "$cmd")
      if [ -f "$SP_CMDS/$base" ]; then
        fail "A3: command filename collision: $base exists in both plugins"
        COLLISIONS=$((COLLISIONS+1))
      fi
    done
    [ "$COLLISIONS" -eq 0 ] && pass "A3: no command filename collision with Superpowers ($SP_VER)"
  else
    skip "A3: Superpowers cache found but no commands/ subdir (version $SP_VER?)"
  fi
else
  skip "A3: Superpowers not installed at $SP_CACHE — skipped"
fi

# ---- A4: hook-matcher structural validity ----
if [ -f hooks/hooks.json ]; then
  HOOK_CMD=$(jq -r '.hooks.PreToolUse[0].hooks[0].command // empty' hooks/hooks.json)
  if [ -z "$HOOK_CMD" ]; then
    fail "A4: hooks/hooks.json PreToolUse[0].hooks[0].command is missing"
  elif echo "$HOOK_CMD" | grep -q 'validate-personas.sh'; then
    if [ -x "$REPO_ROOT/scripts/validate-personas.sh" ]; then
      pass "A4: hook PreToolUse matcher references scripts/validate-personas.sh (exists + executable)"
    else
      fail "A4: hook references validate-personas.sh but the script is missing or non-executable"
    fi
  else
    pass "A4: hook PreToolUse command is non-empty: $(echo "$HOOK_CMD" | head -c 60)..."
  fi
else
  fail "A4: hooks/hooks.json missing"
fi

# ---- A5: no devils-council agent uses reserved 'gsd-' prefix ----
GSD_HOOKS="$HOME/.claude/hooks"
GSD_PRESENT=0
if [ -d "$GSD_HOOKS" ]; then
  if ls "$GSD_HOOKS"/gsd-*.sh >/dev/null 2>&1 || ls "$GSD_HOOKS"/gsd-*.js >/dev/null 2>&1; then
    GSD_PRESENT=1
  fi
fi
if [ "$GSD_PRESENT" -eq 1 ]; then
  PREFIX_FAILS=0
  for agent in "$REPO_ROOT"/agents/*.md; do
    [ -f "$agent" ] || continue
    base=$(basename "$agent")
    case "$base" in
      gsd-*)
        fail "A5: agent file '$base' uses reserved 'gsd-' prefix (collides with GSD user-scope agents)"
        PREFIX_FAILS=$((PREFIX_FAILS+1))
        ;;
    esac
  done
  [ "$PREFIX_FAILS" -eq 0 ] && pass "A5: no devils-council agent uses reserved 'gsd-' prefix (GSD present)"
else
  skip "A5: GSD not detected at $GSD_HOOKS — gsd- prefix check skipped"
fi

# ---- A6: no duplicate agent basenames within devils-council ----
DUPES=""
if [ -d "$REPO_ROOT/agents" ]; then
  DUPES=$(ls "$REPO_ROOT"/agents/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | sort | uniq -d || true)
fi
if [ -n "$DUPES" ]; then
  fail "A6: duplicate agent basenames detected: $DUPES"
else
  pass "A6: no duplicate agent basenames in devils-council/agents/"
fi

# ---- Summary ----
echo "---"
echo "Coexistence check: $PASS_COUNT passed, $SKIP_COUNT skipped, $FAIL failed"

[ "$FAIL" -ne 0 ] && exit 1
echo "HARD-05 COEXISTENCE TEST: PASSED"
exit 0
