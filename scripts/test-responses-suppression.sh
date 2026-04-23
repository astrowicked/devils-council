#!/usr/bin/env bash
# scripts/test-responses-suppression.sh — RESP-01 + RESP-03 two-run test.
#
# Phase 7 Plan 06.
#
# Run 1: no responses.md present → bootstrap created; suppressed_findings == [].
# Annotation: copy responses-pre-run2.md with Run 1's stamped IDs substituted.
# Run 2: same draft → same stamped IDs (RESP-03 D-38 stable hash) → suppressed_findings
#        contains exactly the dismissed ID; accepted ID is NOT in suppressed_findings.
# Cleanup: restore any user-authored .council/responses.md.
#
# Exits 0 on all-pass, 1 otherwise. Target runtime: < 15s.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

FAIL=0
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }

RUN_DIRS=()
RESP_BAK=""
CREATED_RESP=0
cleanup() {
  for d in "${RUN_DIRS[@]:-}"; do
    [ -n "${d:-}" ] && rm -rf "$d" 2>/dev/null || true
  done
  # Restore pre-existing responses.md we backed up, if any.
  if [ -n "$RESP_BAK" ] && [ -f "$RESP_BAK" ]; then
    mkdir -p .council 2>/dev/null || true
    mv "$RESP_BAK" .council/responses.md 2>/dev/null || true
  elif [ "$CREATED_RESP" = "1" ]; then
    rm -f .council/responses.md 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Back up any existing responses.md so we don't clobber user state.
if [ -f .council/responses.md ]; then
  RESP_BAK=$(mktemp)
  cp .council/responses.md "$RESP_BAK"
  rm -f .council/responses.md
fi

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

# Phase 5 D-38 finding-ID computation — mirrors bin/dc-validate-scorecard.sh
# stamp_id (persona+target+claim, evidence EXCLUDED, canon = trim+ws-collapse+lower).
stamp_id() {
  local persona="$1" target="$2" claim="$3"
  python3 - "$persona" "$target" "$claim" <<'PYEOF'
import sys, hashlib, re
def canon(s): return re.sub(r'\s+', ' ', str(s or '').strip().lower())
persona, target, claim = sys.argv[1], sys.argv[2], sys.argv[3]
payload = f"{canon(persona)}|{canon(target)}|{canon(claim)}".encode('utf-8')
print(f"{canon(persona)}-{hashlib.sha256(payload).hexdigest()[:8]}")
PYEOF
}

build_run() {
  local rundir="$1"
  mkdir -p "$rundir"
  # INPUT.md must contain the verbatim evidence strings from scorecard-sample.md.
  cat > "$rundir/INPUT.md" <<'INPUT'
# Sample Plan

section-scope sample artifact line
section-rollback sample artifact line
INPUT
  local sha
  sha=$(sha256_of "$rundir/INPUT.md")
  jq -n \
    --arg ap "tests/fixtures/responses-suppression/sample-input" \
    --arg sha "$sha" \
    --arg type "plan" '{
      artifact_path: $ap, sha256: $sha, detected_type: $type,
      personas_run: [{name: "staff-engineer", trigger_reason: "core:always-on", outcome: "pending"}],
      validation: []
    }' > "$rundir/MANIFEST.json"
  cp tests/fixtures/responses-suppression/scorecard-sample.md "$rundir/staff-engineer-draft.md"
  if ! bin/dc-validate-scorecard.sh staff-engineer "$rundir" core:always-on \
       > "$rundir/validator.out" 2>&1; then
    cat "$rundir/validator.out" >&2
    return 1
  fi
}

# ---- Run 1 ----
RUN1=$(mktemp -d)
RUN_DIRS+=("$RUN1")
build_run "$RUN1" || { fail "Run 1 validator failed"; exit 1; }

# Capture run-1 IDs deterministically (test mirrors stamp_id; compare with what
# validator actually wrote into MANIFEST.personas_run[0].findings[].id).
RUN1_DISMISS_ID=$(stamp_id staff-engineer section-scope "Scope boundary with downstream services is not defined explicitly.")
RUN1_ACCEPT_ID=$(stamp_id staff-engineer section-rollback "No rollback step is present for a multi-service migration.")

# Sanity: validator wrote the ids we expect (test isn't drifting from implementation).
RUN1_FIRST_ACTUAL=$(jq -r '.personas_run[0].findings[0].id' "$RUN1/MANIFEST.json")
[ "$RUN1_FIRST_ACTUAL" = "$RUN1_DISMISS_ID" ] \
  && pass "Run 1 validator stamped id matches stamp_id mirror ($RUN1_DISMISS_ID)" \
  || fail "Run 1 id drift — mirror=$RUN1_DISMISS_ID actual=$RUN1_FIRST_ACTUAL"

# Run 1: no responses.md present → expect bootstrap + empty suppressed_findings.
CREATED_RESP=1
SUP1=$(bin/dc-apply-responses.sh "$RUN1" | tail -1)
[ "$SUP1" = "SUPPRESSED_IDS=" ] \
  && pass "Run 1 emitted empty SUPPRESSED_IDS" \
  || fail "Run 1 stdout unexpected: $SUP1"
[ -f .council/responses.md ] \
  && pass "Run 1 bootstrapped .council/responses.md" \
  || fail "Run 1 bootstrap missing"

jq -e '.suppressed_findings == []' "$RUN1/MANIFEST.json" >/dev/null \
  && pass "Run 1 MANIFEST.suppressed_findings == []" \
  || fail "Run 1 MANIFEST.suppressed_findings is not an empty array"

# ---- Annotation ----
sed -e "s/__DISMISSED_ID__/$RUN1_DISMISS_ID/" \
    -e "s/__ACCEPTED_ID__/$RUN1_ACCEPT_ID/" \
    tests/fixtures/responses-suppression/responses-pre-run2.md \
    > .council/responses.md

# ---- Run 2 ----
RUN2=$(mktemp -d)
RUN_DIRS+=("$RUN2")
build_run "$RUN2" || { fail "Run 2 validator failed"; exit 1; }

# RESP-03 / D-38 stability — Run 2's first-finding id must equal Run 1's.
RUN2_FIRST_ID=$(jq -r '.personas_run[0].findings[0].id' "$RUN2/MANIFEST.json")
[ "$RUN2_FIRST_ID" = "$RUN1_DISMISS_ID" ] \
  && pass "RESP-03 — finding IDs byte-identical across runs ($RUN2_FIRST_ID)" \
  || fail "RESP-03 — finding IDs differ: run1=$RUN1_DISMISS_ID, run2=$RUN2_FIRST_ID"

SUP2=$(bin/dc-apply-responses.sh "$RUN2" | tail -1)
[ "$SUP2" = "SUPPRESSED_IDS=$RUN1_DISMISS_ID" ] \
  && pass "Run 2 emitted SUPPRESSED_IDS=$RUN1_DISMISS_ID" \
  || fail "Run 2 stdout unexpected: $SUP2"

jq -e --arg id "$RUN1_DISMISS_ID" '
  .suppressed_findings
  | length == 1
    and (.[0].finding_id == $id)
    and (.[0].status == "dismissed")
    and (.[0].persona == "staff-engineer")
    and (.[0].target == "section-scope")
    and (.[0].reason | type == "string" and length > 0)
    and (.[0].dismissed_at == "2026-04-23")
' "$RUN2/MANIFEST.json" >/dev/null \
  && pass "Run 2 MANIFEST.suppressed_findings shape correct (single dismissed entry w/ persona+target+reason+dismissed_at)" \
  || fail "Run 2 MANIFEST.suppressed_findings shape unexpected: $(jq -c '.suppressed_findings' "$RUN2/MANIFEST.json")"

# Accepted ID must NOT be in suppressed_findings (research §4.5: accepted does not suppress).
jq -e --arg id "$RUN1_ACCEPT_ID" \
  '.suppressed_findings | map(.finding_id) | index($id) == null' \
  "$RUN2/MANIFEST.json" >/dev/null \
  && pass "accepted-status finding is NOT suppressed (research §4.5)" \
  || fail "accepted-status finding was incorrectly suppressed"

[ "$FAIL" -ne 0 ] && exit 1
echo "RESP-01 + RESP-03 SUPPRESSION TEST: PASSED"
exit 0
