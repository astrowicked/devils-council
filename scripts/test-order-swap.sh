#!/usr/bin/env bash
# test-order-swap.sh — CORE-06 order-swap isolation verifier for devils-council.
#
# Proves persona parallel-spawn isolation: asserts that each persona's
# scorecard fingerprint is stable across a canonical-order run and a
# reversed-order run on the same fixture. Per research §Summary #1 + D-28,
# path A (hash-equality relying on sampling determinism) is foreclosed —
# sampling controls are NOT exposed to plugin-authored Agent calls. This
# script implements path B (fingerprint comparison) exclusively.
#
# Fingerprint recipe (research §Pattern 4):
#   sha256(JSON({persona, sorted_tuples: [(target, severity, category)],
#                severity_dist, category_dist, finding_count}))
#   — robust to sampling noise in prose, sensitive to real context-bleed.
#
# Flow:
#   1. Prompt user to run /devils-council:review <fixture> in a live Claude
#      Code session; collect the canonical run-dir path.
#   2. Surgically reverse the persona enumeration in commands/review.md
#      (backed up + trap-protected + sha256-verified restore).
#   3. Prompt user to re-run /devils-council:review <fixture>; collect the
#      reversed run-dir path.
#   4. Restore commands/review.md.
#   5. Compute fingerprints for all 4 personas in both runs.
#   6. Assert per-persona fingerprint equality across runs.
#   7. Append result to tests/fixtures/order-swap-results.json.
#   8. Exit 0 if all four match; exit 1 on any drift or restoration failure.
#
# NOT WIRED INTO CI — requires live Claude Code Agent invocations (cannot be
# faked). macOS bash 3.2 compatible; BSD/GNU portable.
#
# Usage:
#   scripts/test-order-swap.sh <fixture-path>

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
REVIEW_CMD="$REPO_ROOT/commands/review.md"
BACKUP="$REPO_ROOT/commands/review.md.orderswap-backup"
RESULTS="$REPO_ROOT/tests/fixtures/order-swap-results.json"

pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; }
info() { printf 'INFO: %s\n' "$*"; }

usage() {
  cat >&2 <<'USAGE'
Usage: scripts/test-order-swap.sh <fixture-path>

  <fixture-path>  Path to the artifact to be reviewed (e.g.,
                  tests/fixtures/plan-sample.md). The script invokes
                  /devils-council:review on this fixture TWICE via the
                  user's live Claude Code session (once canonical, once
                  reversed-order); the user pastes each resulting run-dir.

Per D-28 (research-resolved): uses fingerprint comparison (path B), not
sha256 hash-equality (path A — foreclosed; sampling controls not exposed).
Per D-26/CORE-06: Phase 4 ships when this script shows per-persona
fingerprint stability across canonical + reversed runs.
USAGE
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

FIXTURE="$1"

# Preflight.
[ -f "$REVIEW_CMD" ]      || { fail "$REVIEW_CMD missing — Plan 05 is a hard dependency"; exit 1; }
[ -f "$FIXTURE" ]         || { fail "fixture not found: $FIXTURE"; exit 1; }
command -v jq >/dev/null 2>&1 || { fail "jq required"; exit 1; }
command -v python3 >/dev/null 2>&1 || { fail "python3 required (for PyYAML fingerprint)"; exit 1; }
python3 -c 'import yaml' 2>/dev/null || { fail "python3 PyYAML required — pip install pyyaml"; exit 1; }

# Results log bootstrap.
if [ ! -f "$RESULTS" ]; then
  printf '[]\n' > "$RESULTS"
fi

# Canonical order (Plan 05's committed order).
CANONICAL_ORDER=(staff-engineer sre product-manager devils-advocate)
REVERSED_ORDER=(devils-advocate product-manager sre staff-engineer)

# Capture pre-edit sha256 of commands/review.md — restoration must match.
if command -v shasum >/dev/null 2>&1; then
  SHA_BEFORE=$(shasum -a 256 "$REVIEW_CMD" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
  SHA_BEFORE=$(sha256sum "$REVIEW_CMD" | awk '{print $1}')
else
  fail "neither shasum nor sha256sum available"; exit 1
fi

# ---------------------------------------------------------------------------
# Triple-layer restoration defense (T-04-42):
#   1. Backup file written to disk before edit.
#   2. trap EXIT restores from backup unconditionally on any exit.
#   3. Explicit restore block at end of happy path + sha256 re-verify.
# ---------------------------------------------------------------------------
restore_review_cmd() {
  if [ -f "$BACKUP" ]; then
    cp -f "$BACKUP" "$REVIEW_CMD"
    rm -f "$BACKUP"
    info "commands/review.md restored from backup"
  fi
}
trap restore_review_cmd EXIT

# Write the backup NOW, before any edit.
cp -f "$REVIEW_CMD" "$BACKUP"

# ---------------------------------------------------------------------------
# Step 1 of 3 — prompt for canonical run.
# ---------------------------------------------------------------------------
cat <<BANNER

============================================================
CORE-06 Order-Swap Isolation Test
Fixture: $FIXTURE
============================================================

Step 1 of 3: CANONICAL run.

In a separate terminal with Claude Code loaded, run:

    /devils-council:review $FIXTURE

When the review completes, paste the run directory path below. The
run directory is the one shown in the review output (under .council/).

BANNER

read -rp "Canonical run-dir: " RUN_CANONICAL
RUN_CANONICAL="${RUN_CANONICAL%/}"  # strip trailing slash

if [ ! -d "$RUN_CANONICAL" ]; then
  fail "canonical run-dir not a directory: $RUN_CANONICAL"
  exit 1
fi
for p in "${CANONICAL_ORDER[@]}"; do
  [ -s "$RUN_CANONICAL/$p.md" ] || { fail "canonical run missing scorecard: $RUN_CANONICAL/$p.md"; exit 1; }
done
pass "canonical run has all four scorecards"

# ---------------------------------------------------------------------------
# Step 2 of 3 — surgical edit to reverse spawn order.
# ---------------------------------------------------------------------------
info "Reversing persona spawn order in $REVIEW_CMD (backup at $BACKUP)"

# Use python3 for the surgical edit — sed/awk across multi-line numbered
# lists is fragile. Match the exact four-line block Plan 05 commits to
# commands/review.md: numbered list, backticks around persona name, arrow,
# backticks around <RUN_DIR>/<persona>-draft.md suffix.
#
# If the match fails (structure drifted), the python script exits non-zero
# and the trap restores the file before we proceed.
python3 - "$REVIEW_CMD" <<'PYEOF'
import re
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

canonical_block = (
    '1. `staff-engineer` -> writes `<RUN_DIR>/staff-engineer-draft.md`\n'
    '2. `sre` -> writes `<RUN_DIR>/sre-draft.md`\n'
    '3. `product-manager` -> writes `<RUN_DIR>/product-manager-draft.md`\n'
    '4. `devils-advocate` -> writes `<RUN_DIR>/devils-advocate-draft.md`'
)
reversed_block = (
    '1. `devils-advocate` -> writes `<RUN_DIR>/devils-advocate-draft.md`\n'
    '2. `product-manager` -> writes `<RUN_DIR>/product-manager-draft.md`\n'
    '3. `sre` -> writes `<RUN_DIR>/sre-draft.md`\n'
    '4. `staff-engineer` -> writes `<RUN_DIR>/staff-engineer-draft.md`'
)

count = content.count(canonical_block)
if count != 1:
    print(f"ERROR: expected exactly 1 match of canonical spawn block, found {count}", file=sys.stderr)
    print("Plan 05's commands/review.md structure has drifted — this script must be updated.", file=sys.stderr)
    sys.exit(1)

new_content = content.replace(canonical_block, reversed_block)
with open(path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("OK: spawn-order block reversed")
PYEOF

# Verify the edit actually changed the file (not a silent no-op).
if command -v shasum >/dev/null 2>&1; then
  SHA_AFTER_EDIT=$(shasum -a 256 "$REVIEW_CMD" | awk '{print $1}')
else
  SHA_AFTER_EDIT=$(sha256sum "$REVIEW_CMD" | awk '{print $1}')
fi
if [ "$SHA_AFTER_EDIT" = "$SHA_BEFORE" ]; then
  fail "commands/review.md unchanged after edit — aborting"
  exit 1
fi
pass "commands/review.md spawn order reversed (sha256 changed)"

# ---------------------------------------------------------------------------
# Step 2 continued — prompt for reversed run.
# ---------------------------------------------------------------------------
cat <<BANNER

Step 2 of 3: REVERSED-ORDER run.

commands/review.md now lists the personas in reversed order:
    1. devils-advocate
    2. product-manager
    3. sre
    4. staff-engineer

In your Claude Code session, you must RELOAD the plugin so the changed
command body is picked up. Either:
  - Run /reload-plugins in your session, OR
  - Exit and restart claude (if /reload-plugins doesn't exist in your version)

Then run:

    /devils-council:review $FIXTURE

When the review completes, paste the run directory path below.

BANNER

read -rp "Reversed run-dir: " RUN_REVERSED
RUN_REVERSED="${RUN_REVERSED%/}"

if [ ! -d "$RUN_REVERSED" ]; then
  fail "reversed run-dir not a directory: $RUN_REVERSED"
  exit 1
fi
if [ "$RUN_REVERSED" = "$RUN_CANONICAL" ]; then
  fail "reversed run-dir must differ from canonical run-dir (did you re-run the review?)"
  exit 1
fi
for p in "${CANONICAL_ORDER[@]}"; do
  [ -s "$RUN_REVERSED/$p.md" ] || { fail "reversed run missing scorecard: $RUN_REVERSED/$p.md"; exit 1; }
done
pass "reversed run has all four scorecards"

# ---------------------------------------------------------------------------
# Step 3 of 3 — explicit restoration + verification.
# ---------------------------------------------------------------------------
info "Step 3 of 3: Restoring commands/review.md to canonical order"
cp -f "$BACKUP" "$REVIEW_CMD"

if command -v shasum >/dev/null 2>&1; then
  SHA_AFTER_RESTORE=$(shasum -a 256 "$REVIEW_CMD" | awk '{print $1}')
else
  SHA_AFTER_RESTORE=$(sha256sum "$REVIEW_CMD" | awk '{print $1}')
fi

if [ "$SHA_AFTER_RESTORE" != "$SHA_BEFORE" ]; then
  fail "commands/review.md NOT restored correctly (sha256 mismatch)"
  fail "  before: $SHA_BEFORE"
  fail "  after:  $SHA_AFTER_RESTORE"
  fail "  backup file $BACKUP retained for manual recovery"
  # Do not remove backup; leave for manual inspection.
  trap - EXIT  # disarm the trap so we don't overwrite with the backup twice
  exit 1
fi
rm -f "$BACKUP"
trap - EXIT  # restoration verified; disarm
pass "commands/review.md restored (sha256 matches pre-edit)"

# ---------------------------------------------------------------------------
# Fingerprint function — path B per D-28 / research §Pattern 4.
# Prints sha256 hex of canonical JSON {persona, sorted_tuples,
# severity_dist, category_dist, finding_count}.
# ---------------------------------------------------------------------------
fingerprint() {
  local run_dir="$1" persona="$2"
  python3 - "$run_dir/$persona.md" "$persona" <<'PYEOF'
import hashlib
import json
import sys
import yaml

path, persona = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Split frontmatter: expect '---\n<yaml>\n---\n<body>'.
parts = content.split('---', 2)
if len(parts) < 3:
    print('ERROR: no frontmatter found', file=sys.stderr)
    sys.exit(1)
fm = yaml.safe_load(parts[1]) or {}

findings = fm.get('findings', []) or []
tuples = sorted([
    (str(f.get('target', '')), str(f.get('severity', '')), str(f.get('category', '')))
    for f in findings
])

sev_dist = {}
cat_dist = {}
for _, sev, cat in tuples:
    sev_dist[sev] = sev_dist.get(sev, 0) + 1
    cat_dist[cat] = cat_dist.get(cat, 0) + 1

payload = json.dumps({
    'persona': persona,
    'sorted_tuples': tuples,
    'severity_dist': sev_dist,
    'category_dist': cat_dist,
    'finding_count': len(findings),
}, sort_keys=True, ensure_ascii=True)

print(hashlib.sha256(payload.encode('utf-8')).hexdigest())
PYEOF
}

info "Computing fingerprints..."
FP_CANONICAL=()   # parallel-indexed to CANONICAL_ORDER
FP_REVERSED=()
for i in 0 1 2 3; do
  p="${CANONICAL_ORDER[$i]}"
  FP_CANONICAL[$i]=$(fingerprint "$RUN_CANONICAL" "$p")
  FP_REVERSED[$i]=$(fingerprint "$RUN_REVERSED" "$p")
done

# ---------------------------------------------------------------------------
# Per-persona comparison + result JSON construction.
# ---------------------------------------------------------------------------
MATCH_JSON='{}'
FP_JSON='{}'
MISMATCHES_JSON='[]'
ALL_MATCH=1

for i in 0 1 2 3; do
  p="${CANONICAL_ORDER[$i]}"
  fp_c="${FP_CANONICAL[$i]}"
  fp_r="${FP_REVERSED[$i]}"

  if [ "$fp_c" = "$fp_r" ]; then
    echo "  $p: MATCH (fp=${fp_c:0:12}...)"
    MATCH_JSON=$(jq --arg p "$p" '. + {($p): true}' <<< "$MATCH_JSON")
  else
    echo "  $p: DRIFT (canonical=${fp_c:0:12}... reversed=${fp_r:0:12}...)"
    MATCH_JSON=$(jq --arg p "$p" '. + {($p): false}' <<< "$MATCH_JSON")
    MISMATCHES_JSON=$(jq --arg p "$p" --arg c "$fp_c" --arg r "$fp_r" \
      '. + [{persona: $p, canonical: $c, reversed: $r}]' <<< "$MISMATCHES_JSON")
    ALL_MATCH=0
  fi

  FP_JSON=$(jq --arg p "$p" --arg c "$fp_c" --arg r "$fp_r" \
    '. + {($p): {canonical: $c, reversed: $r}}' <<< "$FP_JSON")
done

# Build canonical_order + reversed_order JSON arrays.
CAN_ORDER_JSON=$(printf '%s\n' "${CANONICAL_ORDER[@]}" | jq -R . | jq -s .)
REV_ORDER_JSON=$(printf '%s\n' "${REVERSED_ORDER[@]}" | jq -R . | jq -s .)

# ---------------------------------------------------------------------------
# Append result JSON + final summary.
# ---------------------------------------------------------------------------
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if [ "$ALL_MATCH" -eq 1 ]; then
  OUTCOME=pass
else
  OUTCOME=fail
fi

TMP_RESULTS=$(mktemp)
jq \
  --arg ts "$NOW" \
  --arg fx "$FIXTURE" \
  --arg rc "$RUN_CANONICAL" \
  --arg rr "$RUN_REVERSED" \
  --argjson co "$CAN_ORDER_JSON" \
  --argjson ro "$REV_ORDER_JSON" \
  --argjson matches "$MATCH_JSON" \
  --argjson fps "$FP_JSON" \
  --argjson mm "$MISMATCHES_JSON" \
  --arg outcome "$OUTCOME" \
  '. + [{
    timestamp: $ts,
    fixture: $fx,
    canonical_run_dir: $rc,
    reversed_run_dir: $rr,
    canonical_order: $co,
    reversed_order: $ro,
    per_persona_fingerprint_match: $matches,
    fingerprints: $fps,
    mismatches: $mm,
    outcome: $outcome
  }]' \
  "$RESULTS" > "$TMP_RESULTS"
mv "$TMP_RESULTS" "$RESULTS"

echo ""
echo "============================================================"
if [ "$ALL_MATCH" -eq 1 ]; then
  pass "CORE-06 order-swap: all four personas fingerprint-stable on $FIXTURE"
  echo "Result appended to: $RESULTS"
  exit 0
else
  fail "CORE-06 order-swap: fingerprint drift detected — isolation may be broken"
  echo "Mismatches:"
  jq -r '.[] | "  \(.persona): canonical=\(.canonical) reversed=\(.reversed)"' <<< "$MISMATCHES_JSON"
  echo "Result appended to: $RESULTS"
  exit 1
fi
