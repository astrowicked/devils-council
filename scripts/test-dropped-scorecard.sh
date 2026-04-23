#!/usr/bin/env bash
# scripts/test-dropped-scorecard.sh — HARD-02 zero-kept drop verification.
#
# Builds a prebuilt run dir containing:
#   INPUT.md                  — minimal artifact with no banned phrases
#   staff-engineer-draft.md   — draft where every finding fails validation
#   MANIFEST.json             — minimal prep-style init
# Invokes bin/dc-validate-scorecard.sh and asserts:
#   - exit 0
#   - stub <persona>.md written with failure: validation_all_findings_dropped
#   - MANIFEST.validation[0].dropped_from_synthesis == true
#   - MANIFEST.validation[0].findings_kept == 0
#   - MANIFEST.validation[0].findings_dropped == 3
#   - MANIFEST.personas_run[0].outcome == "dropped_from_synthesis"
#
# Exit codes:
#   0 — all assertions passed
#   1 — one or more assertions failed

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

FAIL=0
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }

RUN_DIRS=()
cleanup() {
  for d in "${RUN_DIRS[@]:-}"; do
    [ -n "${d:-}" ] && rm -rf "$d" 2>/dev/null || true
  done
}
trap cleanup EXIT

# Portability: prefer shasum (macOS default), fall back to sha256sum (Linux).
sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

# -----------------------------------------------------------------------------
# Preflight
# -----------------------------------------------------------------------------
VALIDATOR="$REPO_ROOT/bin/dc-validate-scorecard.sh"
FIXTURE_INPUT="$REPO_ROOT/tests/fixtures/dropped-scorecard/INPUT.md"
FIXTURE_DRAFT="$REPO_ROOT/tests/fixtures/dropped-scorecard/all-findings-fail.md"

[ -x "$VALIDATOR" ]       || { fail "bin/dc-validate-scorecard.sh missing or not executable"; exit 1; }
[ -f "$FIXTURE_INPUT" ]   || { fail "tests/fixtures/dropped-scorecard/INPUT.md missing"; exit 1; }
[ -f "$FIXTURE_DRAFT" ]   || { fail "tests/fixtures/dropped-scorecard/all-findings-fail.md missing"; exit 1; }

# -----------------------------------------------------------------------------
# Setup: prebuilt run dir matching bin/dc-prep.sh's MANIFEST schema (minimal).
# -----------------------------------------------------------------------------
RUN_DIR=$(mktemp -d)
RUN_DIRS+=("$RUN_DIR")

cp "$FIXTURE_INPUT" "$RUN_DIR/INPUT.md"
cp "$FIXTURE_DRAFT" "$RUN_DIR/staff-engineer-draft.md"

SHA=$(sha256_of "$RUN_DIR/INPUT.md")
jq -n \
  --arg ap "tests/fixtures/dropped-scorecard/INPUT.md" \
  --arg sha "$SHA" \
  --arg type "plan" '
  {
    artifact_path: $ap,
    sha256: $sha,
    detected_type: $type,
    personas_run: [{name: "staff-engineer", trigger_reason: "core:always-on", outcome: "pending"}],
    validation: []
  }' > "$RUN_DIR/MANIFEST.json"

# -----------------------------------------------------------------------------
# Invoke validator — captures stderr to the run dir for diagnostic fallback.
# -----------------------------------------------------------------------------
if "$VALIDATOR" staff-engineer "$RUN_DIR" core:always-on >"$RUN_DIR/validator.out" 2>&1; then
  pass "validator exited 0"
else
  fail "validator exited non-zero (see $RUN_DIR/validator.out)"
  cat "$RUN_DIR/validator.out" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Assertions
# -----------------------------------------------------------------------------

# 1. Stub file exists.
if [ -f "$RUN_DIR/staff-engineer.md" ]; then
  pass "stub <persona>.md exists"
else
  fail "stub <persona>.md MISSING"
fi

# 2. Draft file removed.
if [ ! -f "$RUN_DIR/staff-engineer-draft.md" ]; then
  pass "draft file removed by validator"
else
  fail "draft file still present (should be deleted)"
fi

# 3-5. Stub frontmatter: failure + findings + dropped_findings.
FM_CHECK_OUT=$(mktemp)
RUN_DIRS+=("$FM_CHECK_OUT")
if python3 - "$RUN_DIR/staff-engineer.md" >"$FM_CHECK_OUT" 2>&1 <<'PYEOF'; then
import sys, yaml
path = sys.argv[1]
raw = open(path, encoding='utf-8').read()
parts = raw.split('---', 2)
if len(parts) < 3:
    print(f'FAIL: {path} has no YAML frontmatter block', file=sys.stderr)
    sys.exit(2)
fm = yaml.safe_load(parts[1]) or {}
failures = []
if fm.get('failure') != 'validation_all_findings_dropped':
    failures.append(f"failure field is {fm.get('failure')!r}, expected 'validation_all_findings_dropped'")
if fm.get('findings') != []:
    failures.append(f"findings is {fm.get('findings')!r}, expected []")
dropped = fm.get('dropped_findings')
if not isinstance(dropped, list) or len(dropped) < 3:
    failures.append(f"dropped_findings has {len(dropped) if isinstance(dropped, list) else 'non-list'} entries, expected >= 3")
if failures:
    for f in failures:
        print(f'FAIL: {f}', file=sys.stderr)
    sys.exit(1)
print('PASS: stub frontmatter (failure + findings + dropped_findings) correct')
PYEOF
  cat "$FM_CHECK_OUT"
else
  cat "$FM_CHECK_OUT" >&2
  FAIL=1
fi

# 6. MANIFEST.validation[0].dropped_from_synthesis == true
if jq -e '.validation[0].dropped_from_synthesis == true' "$RUN_DIR/MANIFEST.json" >/dev/null; then
  pass "MANIFEST.validation[0].dropped_from_synthesis == true"
else
  fail "MANIFEST.validation[0].dropped_from_synthesis is not true"
fi

# 7. MANIFEST.validation[0].findings_kept == 0
if jq -e '.validation[0].findings_kept == 0' "$RUN_DIR/MANIFEST.json" >/dev/null; then
  pass "MANIFEST.validation[0].findings_kept == 0"
else
  fail "MANIFEST.validation[0].findings_kept is not 0"
fi

# 8. MANIFEST.validation[0].findings_dropped == 3
if jq -e '.validation[0].findings_dropped == 3' "$RUN_DIR/MANIFEST.json" >/dev/null; then
  pass "MANIFEST.validation[0].findings_dropped == 3"
else
  fail "MANIFEST.validation[0].findings_dropped is not 3 (got: $(jq -r '.validation[0].findings_dropped' "$RUN_DIR/MANIFEST.json"))"
fi

# 9. MANIFEST.personas_run[0].outcome == "dropped_from_synthesis"
if jq -e '.personas_run[0].outcome == "dropped_from_synthesis"' "$RUN_DIR/MANIFEST.json" >/dev/null; then
  pass "MANIFEST.personas_run[0].outcome == dropped_from_synthesis"
else
  fail "MANIFEST.personas_run[0].outcome is not dropped_from_synthesis (got: $(jq -r '.personas_run[0].outcome' "$RUN_DIR/MANIFEST.json"))"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
if [ "$FAIL" -ne 0 ]; then
  echo "HARD-02 DROPPED-SCORECARD TEST: FAILED" >&2
  exit 1
fi

echo "HARD-02 DROPPED-SCORECARD TEST: PASSED"
exit 0
