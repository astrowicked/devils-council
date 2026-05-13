#!/usr/bin/env bash
# scripts/test-opencode.sh — OpenCode plugin validation test script.
#
# Validates the OpenCode plugin path: TypeScript unit tests, build script,
# agent structure, package.json shape, and dual-runtime coexistence.
#
# Phase 6 OC-CI-01: CI gate for the OpenCode runtime.
#
# Exit codes:
#   0 — all assertions passed
#   1 — one or more assertions failed

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

FAIL=0
PASS_COUNT=0
pass() { printf 'PASS: %s\n' "$*"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }

# ---- Section 1: TypeScript unit tests ----
echo "=== Section 1: TypeScript unit tests ==="

if [ ! -f .opencode/plugins/signals.test.ts ] || [ ! -f .opencode/plugins/speckit-hook.test.ts ]; then
  fail "S1: Test files missing (.opencode/plugins/signals.test.ts or speckit-hook.test.ts)"
else
  TS_OUT=$(mktemp)
  trap 'rm -f "$TS_OUT"' EXIT
  set +e
  npx tsx --test .opencode/plugins/signals.test.ts .opencode/plugins/speckit-hook.test.ts > "$TS_OUT" 2>&1
  TS_EXIT=$?
  set -e
  if [ "$TS_EXIT" -eq 0 ]; then
    # Count tests from output (Node test runner format: "# tests N")
    TEST_COUNT=$(grep -oE '# tests [0-9]+' "$TS_OUT" | grep -oE '[0-9]+' | tail -1 || echo "?")
    pass "S1: TypeScript tests passed ($TEST_COUNT tests)"
  else
    fail "S1: TypeScript tests failed (exit $TS_EXIT)"
    # Show last 20 lines for diagnostics
    tail -20 "$TS_OUT" >&2
  fi
fi

# ---- Section 2: Build script + agent validation ----
echo ""
echo "=== Section 2: Build script + agent validation ==="

if [ ! -f .opencode/build.sh ]; then
  fail "S2: .opencode/build.sh not found"
else
  set +e
  BUILD_OUT=$(bash .opencode/build.sh 2>&1)
  BUILD_EXIT=$?
  set -e
  if [ "$BUILD_EXIT" -eq 0 ]; then
    pass "S2a: build.sh exited 0"
  else
    fail "S2a: build.sh failed (exit $BUILD_EXIT)"
    echo "$BUILD_OUT" | tail -10 >&2
  fi

  # Validate each produced agent in .opencode/agents/
  AGENT_DIR="$REPO_ROOT/.opencode/agents"
  if [ ! -d "$AGENT_DIR" ]; then
    fail "S2b: .opencode/agents/ directory missing after build"
  else
    AGENT_COUNT=0
    for agent_file in "$AGENT_DIR"/*.md; do
      [ -f "$agent_file" ] || continue
      AGENT_COUNT=$((AGENT_COUNT+1))
      agent_name=$(basename "$agent_file")

      # Check frontmatter exists (starts with ---)
      if ! head -1 "$agent_file" | grep -q '^---$'; then
        fail "S2b: $agent_name — missing YAML frontmatter opening"
        continue
      fi

      # Check closing --- exists
      if ! sed -n '2,$p' "$agent_file" | grep -q '^---$'; then
        fail "S2b: $agent_name — missing YAML frontmatter closing"
        continue
      fi

      # Extract frontmatter and validate with python3 (lighter than yq dependency)
      FM=$(awk 'BEGIN{c=0} /^---$/{c++;next} c==1{print} c>=2{exit}' "$agent_file")

      # Check mode: subagent
      if ! echo "$FM" | grep -q 'mode:.*subagent'; then
        fail "S2b: $agent_name — missing 'mode: subagent' in frontmatter"
        continue
      fi

      # Check does NOT contain $RUN_DIR (literal unexpanded variable)
      if grep -q '\$RUN_DIR' "$agent_file"; then
        fail "S2b: $agent_name — contains unexpanded \$RUN_DIR reference"
        continue
      fi

      # Check does NOT contain delegation_request
      if grep -q 'delegation_request' "$agent_file"; then
        fail "S2b: $agent_name — contains 'delegation_request' (Claude Code only)"
        continue
      fi

      # Check file has at least 20 lines (real persona body)
      LINE_COUNT=$(wc -l < "$agent_file" | tr -d ' ')
      if [ "$LINE_COUNT" -lt 20 ]; then
        fail "S2b: $agent_name — only $LINE_COUNT lines (expected >=20)"
        continue
      fi
    done

    if [ "$AGENT_COUNT" -eq 0 ]; then
      fail "S2b: No .md files found in .opencode/agents/"
    else
      pass "S2b: $AGENT_COUNT agents validated (frontmatter, mode, no \$RUN_DIR, no delegation_request)"
    fi
  fi
fi

# ---- Section 3: package.json validation ----
echo ""
echo "=== Section 3: package.json validation ==="

OC_PKG="$REPO_ROOT/.opencode/package.json"
if [ ! -f "$OC_PKG" ]; then
  fail "S3: .opencode/package.json not found"
else
  # Check name field
  if jq -e '.name == "devils-council-opencode"' "$OC_PKG" > /dev/null 2>&1; then
    pass "S3a: package.json name is 'devils-council-opencode'"
  else
    fail "S3a: package.json name is not 'devils-council-opencode'"
  fi

  # Check files array exists
  if jq -e '.files | type == "array" and length > 0' "$OC_PKG" > /dev/null 2>&1; then
    pass "S3b: package.json has non-empty 'files' array"
  else
    fail "S3b: package.json missing or empty 'files' array"
  fi

  # Check peerDependencies exist
  if jq -e '.peerDependencies | type == "object" and length > 0' "$OC_PKG" > /dev/null 2>&1; then
    pass "S3c: package.json has peerDependencies"
  else
    fail "S3c: package.json missing peerDependencies"
  fi

  # Check main field points to an existing file
  MAIN_FILE=$(jq -r '.main // empty' "$OC_PKG")
  if [ -n "$MAIN_FILE" ] && [ -f "$REPO_ROOT/.opencode/$MAIN_FILE" ]; then
    pass "S3d: package.json 'main' ($MAIN_FILE) exists"
  else
    fail "S3d: package.json 'main' ($MAIN_FILE) does not exist at .opencode/$MAIN_FILE"
  fi
fi

# ---- Section 4: Coexistence assertion ----
echo ""
echo "=== Section 4: Coexistence assertion ==="

if [ -f "$REPO_ROOT/.claude-plugin/plugin.json" ] && [ -f "$OC_PKG" ]; then
  CC_NAME=$(jq -r '.name' "$REPO_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo "")
  OC_NAME=$(jq -r '.name' "$OC_PKG" 2>/dev/null || echo "")
  if [ "$CC_NAME" != "$OC_NAME" ]; then
    pass "S4a: Both plugin formats exist with distinct names (CC='$CC_NAME', OC='$OC_NAME')"
  else
    fail "S4a: Name collision — both plugins use name '$CC_NAME'"
  fi
else
  if [ ! -f "$REPO_ROOT/.claude-plugin/plugin.json" ]; then
    fail "S4a: .claude-plugin/plugin.json missing"
  fi
  if [ ! -f "$OC_PKG" ]; then
    fail "S4a: .opencode/package.json missing"
  fi
fi

# ---- Summary ----
echo ""
echo "==============================="
printf "Results: %d PASS, %d FAIL\n" "$PASS_COUNT" "$((FAIL > 0 ? 1 : 0))"
echo "==============================="

exit "$FAIL"
