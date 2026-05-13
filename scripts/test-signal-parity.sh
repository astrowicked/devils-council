#!/usr/bin/env bash
# scripts/test-signal-parity.sh — Cross-runtime signal classifier parity test.
#
# Verifies Python (lib/classify.py) and TypeScript (.opencode/plugins/signals.ts)
# classifiers produce equivalent triggered_personas for shared fixture inputs.
#
# Phase 6 OC-CI-01: Regression gate for classifier drift between runtimes.
#
# Exit codes:
#   0 — classifiers agree on shared personas for all fixtures
#   1 — divergence detected on shared persona set

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

# Cleanup temp files on exit
TMPFILES=()
cleanup() { rm -f "${TMPFILES[@]+"${TMPFILES[@]}"}" 2>/dev/null; true; }
trap cleanup EXIT

# --- Prerequisite checks ---

HAS_PYTHON=false
if [ -f lib/classify.py ] && [ -f bin/dc-classify.sh ] && [ -f lib/signals.json ]; then
  if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml, ast, json, re' 2>/dev/null; then
    HAS_PYTHON=true
  fi
fi

HAS_TS=false
if [ -f .opencode/plugins/signals.ts ] && command -v npx >/dev/null 2>&1; then
  HAS_TS=true
fi

if [ "$HAS_PYTHON" = false ] && [ "$HAS_TS" = false ]; then
  echo "ERROR: Neither Python nor TypeScript classifier is available"
  exit 1
fi

if [ "$HAS_PYTHON" = false ]; then
  skip "Python classifier not available (lib/classify.py, bin/dc-classify.sh, or python3 missing)"
  echo ""
  echo "Results: $PASS_COUNT PASS, $SKIP_COUNT SKIP"
  exit 0
fi

if [ "$HAS_TS" = false ]; then
  skip "TypeScript classifier not available (.opencode/plugins/signals.ts or npx missing)"
  echo ""
  echo "Results: $PASS_COUNT PASS, $SKIP_COUNT SKIP"
  exit 0
fi

# --- Shared personas (those that BOTH classifiers can detect) ---
# TS detects: security-reviewer, finops-auditor, air-gap-reviewer, performance-reviewer
# Python detects personas via signals.json: security-reviewer, finops-auditor, air-gap-reviewer,
#   dual-deploy-reviewer, performance-reviewer, and others
# Parity comparison only covers personas both CAN detect.
SHARED_PERSONAS="security-reviewer finops-auditor air-gap-reviewer"

# --- Helper: run Python classifier and extract triggered_personas ---
run_python() {
  local fixture="$1"
  local hint="$2"
  local manifest
  manifest=$(mktemp)
  TMPFILES+=("$manifest")
  echo '{}' > "$manifest"
  python3 lib/classify.py "$fixture" lib/signals.json "$hint" --artifact-type plan 2>/dev/null | \
    jq -r '.triggered_personas[]' | sort
}

# --- Helper: run TypeScript classifier and extract triggered_personas ---
run_typescript() {
  local fixture="$1"
  local hint="$2"
  npx tsx -e "
import { classify } from './.opencode/plugins/signals.ts';
import { readFileSync } from 'fs';
const text = readFileSync('$fixture', 'utf8');
const r = classify(text, '$hint');
r.triggered_personas.sort().forEach(p => console.log(p));
" 2>/dev/null
}

# --- Helper: filter to shared personas only ---
filter_shared() {
  local input="$1"
  local result=""
  for persona in $SHARED_PERSONAS; do
    if echo "$input" | grep -qx "$persona"; then
      result="$result$persona"$'\n'
    fi
  done
  echo "$result" | sort | sed '/^$/d'
}

# --- Fixtures to test ---
FIXTURES=(
  ".opencode/test-fixtures/aws-plan.md"
  ".opencode/test-fixtures/simple-refactor.md"
)

echo "=== Signal Classifier Parity Test ==="
echo "Comparing Python (lib/classify.py) vs TypeScript (.opencode/plugins/signals.ts)"
echo "Shared personas checked: $SHARED_PERSONAS"
echo ""

for fixture in "${FIXTURES[@]}"; do
  if [ ! -f "$fixture" ]; then
    fail "Fixture not found: $fixture"
    continue
  fi

  fixture_name=$(basename "$fixture")
  echo "--- Fixture: $fixture_name ---"

  # Run both classifiers
  PY_RAW=$(run_python "$fixture" "$fixture_name")
  TS_RAW=$(run_typescript "$fixture" "$fixture_name")

  # Filter to shared personas
  PY_SHARED=$(filter_shared "$PY_RAW")
  TS_SHARED=$(filter_shared "$TS_RAW")

  # Report full output (informational)
  echo "  Python (all): $(echo "$PY_RAW" | tr '\n' ' ')"
  echo "  TS (all):     $(echo "$TS_RAW" | tr '\n' ' ')"
  echo "  Python (shared): $(echo "$PY_SHARED" | tr '\n' ' ')"
  echo "  TS (shared):     $(echo "$TS_SHARED" | tr '\n' ' ')"

  # Compare shared persona sets
  if [ "$PY_SHARED" = "$TS_SHARED" ]; then
    if [ -z "$PY_SHARED" ]; then
      pass "$fixture_name: both classifiers agree — zero shared personas triggered"
    else
      pass "$fixture_name: shared persona sets match"
    fi
  else
    fail "$fixture_name: shared persona DIVERGENCE"
    echo "    Python shared: [$(echo "$PY_SHARED" | tr '\n' ', ' | sed 's/, $//')]" >&2
    echo "    TS shared:     [$(echo "$TS_SHARED" | tr '\n' ', ' | sed 's/, $//')]" >&2
  fi

  # Document expected runtime-specific divergence (informational, not a failure)
  PY_ONLY=$(comm -23 <(echo "$PY_RAW" | sort) <(echo "$TS_RAW" | sort) 2>/dev/null | sed '/^$/d' || true)
  TS_ONLY=$(comm -13 <(echo "$PY_RAW" | sort) <(echo "$TS_RAW" | sort) 2>/dev/null | sed '/^$/d' || true)
  if [ -n "$PY_ONLY" ] || [ -n "$TS_ONLY" ]; then
    echo "  [INFO] Expected divergence (runtime-specific detectors):"
    [ -n "$PY_ONLY" ] && echo "    Python-only: $(echo "$PY_ONLY" | tr '\n' ' ')"
    [ -n "$TS_ONLY" ] && echo "    TS-only:     $(echo "$TS_ONLY" | tr '\n' ' ')"
  fi
  echo ""
done

# ---- Summary ----
echo "==============================="
printf "Results: %d PASS, %d FAIL, %d SKIP\n" "$PASS_COUNT" "$((FAIL > 0 ? 1 : 0))" "$SKIP_COUNT"
echo "==============================="

exit "$FAIL"
