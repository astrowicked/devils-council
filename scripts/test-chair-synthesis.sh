#!/usr/bin/env bash
# test-chair-synthesis.sh — Phase 5 end-to-end synthesis test.
#
# Does NOT invoke `claude` headlessly. Instead mirrors scripts/test-engine-smoke.sh
# ADD-2 pattern: construct a run directory with synthetic-but-realistic per-persona
# drafts, call the validator binaries directly, then call
# bin/dc-validate-synthesis.sh against a hand-rolled SYNTHESIS.md.draft.
#
# Covers:
#   A. Happy path — valid drafts + stamped ids + valid synthesis draft → exit 0
#   B. Banned-token rejection (CHAIR-04 enforcement)
#   C. ID stability across re-runs (CHAIR-06 integration)
#   D. Unresolvable-id rejection (CHAIR-02 / D-33)
#   E. CHAIR-05 structural — commands/review.md still wires the synthesis-first render
#
# Exits 0 if every assertion passes, 1 otherwise. Target runtime < 30s.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

PREP="$REPO_ROOT/bin/dc-prep.sh"
PVALID="$REPO_ROOT/bin/dc-validate-scorecard.sh"
SVALID="$REPO_ROOT/bin/dc-validate-synthesis.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/contradiction-seed.md"
REVIEW_MD="$REPO_ROOT/commands/review.md"

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

# Preflight
[ -x "$PREP" ]    || { fail "bin/dc-prep.sh missing/not executable"; exit 1; }
[ -x "$PVALID" ]  || { fail "bin/dc-validate-scorecard.sh missing/not executable"; exit 1; }
[ -x "$SVALID" ]  || { fail "bin/dc-validate-synthesis.sh missing/not executable"; exit 1; }
[ -f "$FIXTURE" ] || { fail "tests/fixtures/contradiction-seed.md missing"; exit 1; }
[ -f "$REVIEW_MD" ] || { fail "commands/review.md missing"; exit 1; }
for persona in staff-engineer sre product-manager devils-advocate council-chair; do
  [ -f "$REPO_ROOT/agents/${persona}.md" ] \
    || { fail "agents/${persona}.md missing"; exit 1; }
  [ -f "$REPO_ROOT/persona-metadata/${persona}.yml" ] \
    || { fail "persona-metadata/${persona}.yml missing"; exit 1; }
done

# Sanity — fixture contains evidence lines we'll cite in synthetic drafts.
grep -qF "In-memory state does not survive restart" "$FIXTURE" \
  || { fail "fixture missing SRE evidence line"; exit 1; }
grep -qF "No feature flag" "$FIXTURE" \
  || { fail "fixture missing Staff Eng / PM evidence line"; exit 1; }
grep -qF "Acme Corp" "$FIXTURE" \
  || { fail "fixture missing PM evidence line"; exit 1; }
grep -qF "9am PT" "$FIXTURE" \
  || { fail "fixture missing SRE deploy-window evidence line"; exit 1; }

# ---------------------------------------------------------------------------
# Helper: build a full run dir with 4 stamped scorecards from HEREDOC drafts.
# Echoes the run dir path on stdout; collects it into RUN_DIRS for cleanup.
# ---------------------------------------------------------------------------
build_run_with_four_scorecards() {
  local run_out
  run_out=$("$PREP" "$FIXTURE" 2>&1) || return 1
  local rundir
  rundir=$(printf '%s' "$run_out" | grep '^RUN_DIR=' | tail -1 | sed 's/^RUN_DIR=//')
  [ -n "$rundir" ] && [[ "$rundir" != ERROR:* ]] || return 1
  RUN_DIRS+=("$rundir")

  # Staff Engineer draft — YAGNI lens on the absent feature flag.
  cat > "$rundir/staff-engineer-draft.md" <<'SE_EOF'
---
persona: staff-engineer
run_id: chair-test
findings:
  - id: "sha256:placeholder"
    target: "## Proposal"
    claim: "The limiter has one caller (Acme) and ships as middleware for every tenant; this is speculative generality."
    evidence: |
      No feature flag. No kill switch. No staged rollout.
    ask: "Inline the quota check in the Acme-specific onboarding path; revisit middleware when a second caller appears."
    severity: major
    category: complexity
---

## Summary

Generality without a second caller.
SE_EOF

  # SRE draft — operational-reality lens on same target.
  cat > "$rundir/sre-draft.md" <<'SRE_EOF'
---
persona: sre
run_id: chair-test
findings:
  - id: "sha256:placeholder"
    target: "## Proposal"
    claim: "Shipping unflagged removes the rollback lever; a 9am PT deploy-induced 429 spike takes the demo rehearsal down."
    evidence: |
      No feature flag. No kill switch. No staged rollout.
    ask: "Land behind a per-tenant flag defaulted on; the flag is the rollback path when the token-bucket math is wrong."
    severity: blocker
    category: blast-radius
  - id: "sha256:placeholder"
    target: "## Risks"
    claim: "Deploy-minute state reset will page on-call the week of the demo; there is no runbook."
    evidence: |
      In-memory state does not survive restart; limits reset on deploy.
    ask: "Name the pager rotation that owns the deploy-minute 429 spike and document the error-budget burn."
    severity: major
    category: blast-radius
---

## Summary

Deploy-window operational risk is named but not owned.
SRE_EOF

  # Product Manager draft — stakeholder-alignment lens on same target.
  cat > "$rundir/product-manager-draft.md" <<'PM_EOF'
---
persona: product-manager
run_id: chair-test
findings:
  - id: "sha256:placeholder"
    target: "## Proposal"
    claim: "The Acme demo commitment was signed off on 'ship it on by default'; gating with a flag changes the contract without a re-commit."
    evidence: |
      No feature flag. No kill switch. No staged rollout.
    ask: "If the flag goes in, re-confirm the Acme demo script with their onboarding team before May 8."
    severity: major
    category: business
---

## Summary

Customer-side script drift is the business risk.
PM_EOF

  # Devil's Advocate draft — premise-attack lens on the whole plan.
  cat > "$rundir/devils-advocate-draft.md" <<'DA_EOF'
---
persona: devils-advocate
run_id: chair-test
findings:
  - id: "sha256:placeholder"
    target: "## Proposal"
    claim: "The unexamined premise is 'demo simplicity justifies removing the rollback path'; this trade is not named anywhere in the plan."
    evidence: |
      No feature flag. No kill switch. No staged rollout.
    ask: "Name the trade explicitly and defend it, or pick the other side."
    severity: major
    category: complexity
---

## Summary

The trade-off the plan hides is the one worth arguing about.
DA_EOF

  # Stamp ids via per-persona validator (Plan 05-01 extension).
  "$PVALID" staff-engineer   "$rundir" core:always-on >/dev/null 2>&1 || return 1
  "$PVALID" sre              "$rundir" core:always-on >/dev/null 2>&1 || return 1
  "$PVALID" product-manager  "$rundir" core:always-on >/dev/null 2>&1 || return 1
  "$PVALID" devils-advocate  "$rundir" core:always-on >/dev/null 2>&1 || return 1

  printf '%s\n' "$rundir"
}

# ---------------------------------------------------------------------------
# Case A — Happy path
# ---------------------------------------------------------------------------
echo "--- Case A: happy path ---"

RUN_A=$(build_run_with_four_scorecards) || { fail "A: failed to build run dir"; exit 1; }
pass "A: four scorecards validated + stamped in $RUN_A"

# Extract a valid id per persona for use in the synthetic SYNTHESIS.md.draft.
ID_SE=$(jq -r '.personas_run[] | select(.name=="staff-engineer")   | .findings[0].id' "$RUN_A/MANIFEST.json")
ID_SRE=$(jq -r '.personas_run[] | select(.name=="sre")              | .findings[0].id' "$RUN_A/MANIFEST.json")
ID_PM=$(jq -r '.personas_run[] | select(.name=="product-manager")   | .findings[0].id' "$RUN_A/MANIFEST.json")
ID_DA=$(jq -r '.personas_run[] | select(.name=="devils-advocate")   | .findings[0].id' "$RUN_A/MANIFEST.json")
for id in "$ID_SE" "$ID_SRE" "$ID_PM" "$ID_DA"; do
  case "$id" in
    staff-engineer-*|sre-*|product-manager-*|devils-advocate-*) ;;
    *) fail "A: malformed stamped id: $id"; exit 1 ;;
  esac
done
pass "A: stamped ids conform to <persona>-<8hex> format"

# All four personas targeted "## Proposal" with different severities/framings.
# Candidate set (D-34) contains "## Proposal" (4 personas, >=2 threshold) AND
# "## Risks" becomes a blocker-severity candidate via the SRE blocker finding.
# Write a valid synthesis draft.
cat > "$RUN_A/SYNTHESIS.md.draft" <<DRAFT_A_EOF
## Contradictions

- **Product Manager** (${ID_PM}): «The Acme demo commitment was signed off on 'ship it on by default'; gating with a flag changes the contract without a re-commit.»
  **SRE** (${ID_SRE}): «Shipping unflagged removes the rollback lever; a 9am PT deploy-induced 429 spike takes the demo rehearsal down.»
  *Tension:* PM optimizes for customer-script stability; SRE optimizes for blast-radius. The plan picks PM's side without naming the trade.

## Top-3 Blocking Concerns

1. **SRE** (${ID_SRE}): Shipping unflagged removes the rollback path; blocker-severity on ## Proposal.
2. **Devil's Advocate** (${ID_DA}): Unexamined premise on ## Proposal — demo-simplicity vs operational-safety trade not named.
3. **Staff Engineer** (${ID_SE}): Middleware generality on ## Proposal with only one caller.

## Agreements

- All four personas anchored on the "No feature flag" line in ## Proposal; disagreement is about framing, not about what the text says.

## Raw Scorecards

- [staff-engineer.md](./staff-engineer.md)
- [sre.md](./sre.md)
- [product-manager.md](./product-manager.md)
- [devils-advocate.md](./devils-advocate.md)
DRAFT_A_EOF

"$SVALID" "$RUN_A" >/dev/null 2>&1 || { fail "A: synthesis validator exited non-zero"; exit 1; }
pass "A: synthesis validator exited 0"

[ -f "$RUN_A/SYNTHESIS.md" ]         && pass "A: SYNTHESIS.md created"         || fail "A: SYNTHESIS.md missing"
[ ! -f "$RUN_A/SYNTHESIS.md.draft" ] && pass "A: draft cleaned up"              || fail "A: draft still present"

if jq -e '.synthesis.ran == true and .synthesis.validation.passed == true and .synthesis.contradiction_count >= 1 and .synthesis.top3_count >= 1' "$RUN_A/MANIFEST.json" >/dev/null; then
  pass "A: MANIFEST.synthesis shape correct (ran=true, passed=true, contradictions+top3 >= 1)"
else
  fail "A: MANIFEST.synthesis wrong: $(jq -c '.synthesis' "$RUN_A/MANIFEST.json")"
fi

# CHAIR-02: contradictions section exists + names personas + cites ids + uses verbatim claim quotes.
if grep -q "^## Contradictions$" "$RUN_A/SYNTHESIS.md" \
   && grep -qE "\*\*(Product Manager|SRE|Staff Engineer|Devil's Advocate)\*\*" "$RUN_A/SYNTHESIS.md" \
   && grep -qE "\(($ID_PM|$ID_SRE|$ID_SE|$ID_DA)\)" "$RUN_A/SYNTHESIS.md"; then
  pass "A: CHAIR-02 — Contradictions section names personas and cites resolvable ids"
else
  fail "A: CHAIR-02 — Contradictions structure missing or incomplete"
fi

# CHAIR-03: Top-3 section + persona attribution + id citations.
if grep -q "^## Top-3 Blocking Concerns$" "$RUN_A/SYNTHESIS.md" \
   && grep -qE "\(($ID_SRE|$ID_SE|$ID_PM|$ID_DA)\)" "$RUN_A/SYNTHESIS.md"; then
  pass "A: CHAIR-03 — Top-3 section with persona attribution and id citations"
else
  fail "A: CHAIR-03 — Top-3 structure missing or incomplete"
fi

# CHAIR-04: no banned tokens in final SYNTHESIS.md.
BANNED_HIT=""
for tok in "APPROVE" "REJECT" "overall verdict" "on balance" "recommend approval" "recommend rejection" "5/10" "7/10"; do
  if grep -qiF -- "$tok" "$RUN_A/SYNTHESIS.md"; then
    BANNED_HIT="$tok"
    break
  fi
done
if [ -z "$BANNED_HIT" ]; then
  pass "A: CHAIR-04 — no banned tokens in SYNTHESIS.md"
else
  fail "A: CHAIR-04 — banned token found in SYNTHESIS.md: '$BANNED_HIT'"
fi

# ---------------------------------------------------------------------------
# Case B — Banned-token rejection
# ---------------------------------------------------------------------------
echo "--- Case B: banned-token rejection ---"

# Reuse RUN_A's MANIFEST (still has stamped ids + candidate set) but rewrite the draft.
# First restore the .draft — the successful Case A consumed it.
cat > "$RUN_A/SYNTHESIS.md.draft" <<DRAFT_B_EOF
## Contradictions

- **Product Manager** (${ID_PM}): «The Acme demo commitment was signed off.»
  **SRE** (${ID_SRE}): «Shipping unflagged removes the rollback lever.»
  *Tension:* APPROVE the PM side.

## Top-3 Blocking Concerns

1. **SRE** (${ID_SRE}): blocker.

## Agreements

- None.

## Raw Scorecards

- [staff-engineer.md](./staff-engineer.md)
DRAFT_B_EOF

set +e
"$SVALID" "$RUN_A" >/dev/null 2>&1
RC_B=$?
set -e

if [ "$RC_B" -ne 0 ] && [ -f "$RUN_A/SYNTHESIS.md.invalid" ]; then
  pass "B: banned-token draft rejected (exit $RC_B, .invalid created)"
else
  fail "B: expected rejection, got rc=$RC_B, .invalid present=$([ -f "$RUN_A/SYNTHESIS.md.invalid" ] && echo yes || echo no)"
fi

if jq -e '.synthesis.validation.passed == false and (any(.synthesis.validation.errors[]; .check == "banned_token"))' "$RUN_A/MANIFEST.json" >/dev/null; then
  pass "B: MANIFEST.synthesis.validation.errors[] contains banned_token check"
else
  fail "B: banned_token error not recorded in MANIFEST"
fi

# Cleanup for next case.
rm -f "$RUN_A/SYNTHESIS.md.invalid"

# ---------------------------------------------------------------------------
# Case C — ID stability across re-runs (CHAIR-06 integration)
# ---------------------------------------------------------------------------
echo "--- Case C: ID stability across re-runs (CHAIR-06) ---"

RUN_C=$(build_run_with_four_scorecards) || { fail "C: failed to build second run dir"; exit 1; }

# Collect all ids from RUN_A and RUN_C, sort, compare.
IDS_A=$(jq -r '[.personas_run[].findings[]?.id] | sort | .[]' "$RUN_A/MANIFEST.json")
IDS_C=$(jq -r '[.personas_run[].findings[]?.id] | sort | .[]' "$RUN_C/MANIFEST.json")

if [ "$IDS_A" = "$IDS_C" ] && [ -n "$IDS_A" ]; then
  pass "C: CHAIR-06 — all stamped ids identical across two runs of the same fixture"
else
  fail "C: CHAIR-06 — ids diverge between runs. Run A: $IDS_A  Run C: $IDS_C"
fi

# ---------------------------------------------------------------------------
# Case D — Unresolvable-id rejection
# ---------------------------------------------------------------------------
echo "--- Case D: unresolvable-id rejection ---"

cat > "$RUN_A/SYNTHESIS.md.draft" <<DRAFT_D_EOF
## Contradictions

- **Product Manager** (product-manager-deadbeef): «invented claim one.»
  **SRE** (sre-deadbee1): «invented claim two.»
  *Tension:* neither id exists in MANIFEST.

## Top-3 Blocking Concerns

1. **SRE** (${ID_SRE}): real id on ## Proposal.

## Agreements

- None.

## Raw Scorecards

- [staff-engineer.md](./staff-engineer.md)
DRAFT_D_EOF

set +e
"$SVALID" "$RUN_A" >/dev/null 2>&1
RC_D=$?
set -e

if [ "$RC_D" -ne 0 ]; then
  pass "D: unresolvable-id draft rejected (exit $RC_D)"
else
  fail "D: expected rejection for fabricated ids, got exit 0"
fi

if jq -e '.synthesis.validation.passed == false and (any(.synthesis.validation.errors[]; .check == "contradiction_id_not_resolvable"))' "$RUN_A/MANIFEST.json" >/dev/null; then
  pass "D: MANIFEST records contradiction_id_not_resolvable"
else
  fail "D: contradiction_id_not_resolvable not recorded: $(jq -c '.synthesis.validation.errors' "$RUN_A/MANIFEST.json")"
fi

rm -f "$RUN_A/SYNTHESIS.md.invalid"

# ---------------------------------------------------------------------------
# Case E — CHAIR-05 structural (commands/review.md wires synthesis-first render)
# ---------------------------------------------------------------------------
echo "--- Case E: CHAIR-05 structural (review.md render wiring) ---"

if grep -q "^## Spawn the Council Chair$"                      "$REVIEW_MD" \
   && grep -q "^## Validate synthesis and render synthesis-first$" "$REVIEW_MD" \
   && grep -qE "^## Render all four scorecards( inline| \(severity-tier transform)" "$REVIEW_MD"; then
  pass "E: all three Phase 5 sections present in commands/review.md"
else
  fail "E: one or more Phase 5 sections missing from commands/review.md"
fi

# Ordering check: Spawn -> Validate -> Render.
# Phase 7 Plan 07 replaces "## Render all four scorecards inline" with
# "## Render all four scorecards (severity-tier transform — D-72 / D-73)"
# per D-72; accept either header shape.
if awk '
  /^## Spawn the Council Chair$/                      {s=NR}
  /^## Validate synthesis and render synthesis-first$/{v=NR}
  /^## Render all four scorecards( inline| \(severity-tier transform)/ {r=NR}
  END { exit !(s && v && r && s < v && v < r) }
' "$REVIEW_MD"; then
  pass "E: Phase 5 section order correct (Spawn -> Validate -> Render)"
else
  fail "E: Phase 5 section ordering wrong in commands/review.md"
fi

if grep -q "dc-validate-synthesis.sh" "$REVIEW_MD"; then
  pass "E: review.md invokes dc-validate-synthesis.sh"
else
  fail "E: review.md does not invoke dc-validate-synthesis.sh"
fi

# ---------------------------------------------------------------------------
# Summary + exit
# ---------------------------------------------------------------------------
echo ""
if [ "$FAIL" -ne 0 ]; then
  printf 'CHAIR SYNTHESIS TEST: FAILED\n' >&2
  exit 1
fi
printf 'CHAIR SYNTHESIS TEST: PASSED (cases A-E)\n'
exit 0
