#!/usr/bin/env bash
# test-persona-voice.sh — CORE-05 blinded-reader harness for devils-council.
#
# Reads the four validated scorecards from a completed /devils-council:review
# run directory, strips the `persona:` frontmatter field from each, randomizes
# the order into A/B/C/D slots, prompts the user to label each, grades against
# ground truth, and appends the result to tests/fixtures/voice-test-results.json.
#
# Exit codes:
#   0 — user labeled all four correctly (4/4)
#   1 — user labeled fewer than four correctly, OR usage/preflight error
#
# Per Phase 4 D-26: Phase 4 ships only when this script scores 4/4 on TWO
# fixtures (plan-sample.md + diff-sample.patch) — 8/8 total across both runs.
# Enforcement is performed by Andy at /gsd-verify-work time, not by CI
# (research open question #1 — this script is local-interactive only).
#
# macOS bash 3.2 compatible: no associative arrays, no bash 4+ features.
# BSD/GNU portable: portable randomizer only (awk+rand+sort), no
# GNU-only array-read builtins.
#
# Usage:
#   scripts/test-persona-voice.sh <fixture-path> <run-dir>
#
#   <fixture-path> — path to the artifact that was reviewed (for result log only)
#   <run-dir>      — .council/<ts>-<slug>/ directory that contains the four
#                    validated scorecards (one per persona)

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
RESULTS="$REPO_ROOT/tests/fixtures/voice-test-results.json"

pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; }

usage() {
  cat >&2 <<'USAGE'
Usage: scripts/test-persona-voice.sh <fixture-path> <run-dir>

  <fixture-path>  Path to the artifact that was reviewed. Used only in the
                  result log (not re-read by this script).
  <run-dir>       Path to the .council/<ts>-<slug>/ directory containing the
                  four validated scorecards (staff-engineer.md, sre.md,
                  product-manager.md, devils-advocate.md).

This script does NOT run /devils-council:review itself. Run the slash command
interactively in a Claude Code session first; then pass the resulting run
directory to this script.

Per CORE-05 / D-26: Phase 4 ships when this script scores 4/4 on BOTH
tests/fixtures/plan-sample.md AND tests/fixtures/diff-sample.patch (8/8 total).
USAGE
}

if [ "$#" -ne 2 ]; then
  usage
  exit 1
fi

FIXTURE="$1"
RUN_DIR="$2"

# Preflight — all four scorecards must exist and be non-empty.
PERSONAS=(staff-engineer sre product-manager devils-advocate)
for p in "${PERSONAS[@]}"; do
  if [ ! -s "$RUN_DIR/$p.md" ]; then
    fail "missing or empty scorecard: $RUN_DIR/$p.md"
    fail "is this a completed /devils-council:review run directory?"
    exit 1
  fi
done

# Results log must exist (initialized as [] at plan time); bootstrap if absent.
if [ ! -f "$RESULTS" ]; then
  printf '[]\n' > "$RESULTS"
fi

# jq required.
command -v jq >/dev/null 2>&1 || { fail "jq required"; exit 1; }

# ---------------------------------------------------------------------------
# Step 1-2 (D-25 steps 1-2): read four scorecards, strip `persona:` field.
# ---------------------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for p in "${PERSONAS[@]}"; do
  # Strip the single `persona: <slug>` line from the YAML frontmatter.
  # The field is always the first frontmatter line per Phase 3 D-12 convention.
  # State machine: track frontmatter boundary (first two `---` lines); while
  # inside the frontmatter, skip any line matching ^persona:.
  awk '
    BEGIN { in_fm = 0; fm_count = 0 }
    /^---[[:space:]]*$/ {
      fm_count++
      if (fm_count == 1) { in_fm = 1; print; next }
      if (fm_count == 2) { in_fm = 0; print; next }
    }
    in_fm && /^persona:[[:space:]]/ { next }
    { print }
  ' "$RUN_DIR/$p.md" > "$TMP/$p.stripped"
done

# ---------------------------------------------------------------------------
# Step 3 (D-25 steps 3-4): randomize order into A/B/C/D slots (portable).
# ---------------------------------------------------------------------------
# Portable randomizer: seed awk, tag each persona with rand(), sort, strip tag.
# Works on BSD + GNU identically. Avoids GNU-only randomizing builtins.
SHUFFLED_RAW="$(
  printf '%s\n' "${PERSONAS[@]}" \
    | awk 'BEGIN { srand() } { printf "%.17f\t%s\n", rand(), $0 }' \
    | sort \
    | cut -f2-
)"

# Parse into indexed array (bash 3.2 compatible — uses while-read loop).
SHUFFLED=()
while IFS= read -r line; do
  [ -n "$line" ] && SHUFFLED+=("$line")
done <<< "$SHUFFLED_RAW"

# Defensive: randomizer must yield exactly 4 personas.
if [ "${#SHUFFLED[@]}" -ne 4 ]; then
  fail "randomizer produced ${#SHUFFLED[@]} personas, expected 4"
  exit 1
fi

LABELS=(A B C D)
GROUND_TRUTH=()
for i in 0 1 2 3; do
  GROUND_TRUTH[$i]="${SHUFFLED[$i]}"
done

# ---------------------------------------------------------------------------
# Step 4 (D-25 step 4): print scorecards labeled A/B/C/D.
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "CORE-05 Blinded-Reader Test"
echo "Fixture: $FIXTURE"
echo "Run dir: $RUN_DIR"
echo "============================================================"
echo ""
echo "Read each scorecard below. Then attribute it to one of:"
echo "  staff-engineer | sre | product-manager | devils-advocate"
echo ""

for i in 0 1 2 3; do
  label="${LABELS[$i]}"
  slug="${SHUFFLED[$i]}"
  echo "========================================"
  echo "===== SCORECARD $label ====="
  echo "========================================"
  cat "$TMP/$slug.stripped"
  echo ""
  echo ""
done

# ---------------------------------------------------------------------------
# Step 5 (D-25 step 5): prompt user to label each.
# ---------------------------------------------------------------------------
echo "============================================================"
echo "Enter your guess for each scorecard."
echo "Valid answers: staff-engineer | sre | product-manager | devils-advocate"
echo "============================================================"

GUESSES=()
for i in 0 1 2 3; do
  label="${LABELS[$i]}"
  while true; do
    read -rp "Scorecard $label is: " guess
    case "$guess" in
      staff-engineer|sre|product-manager|devils-advocate)
        GUESSES[$i]="$guess"
        break
        ;;
      *)
        echo "  invalid — must be one of: staff-engineer, sre, product-manager, devils-advocate"
        ;;
    esac
  done
done

# ---------------------------------------------------------------------------
# Step 6 (D-25 step 6): score + print result.
# ---------------------------------------------------------------------------
CORRECT=0
MISTAKES_JSON='[]'
PERSONA_LABELS_JSON='{}'

# Build mistakes[] and persona_labels{} via jq, bash-3.2-compatible loop.
for i in 0 1 2 3; do
  label="${LABELS[$i]}"
  guessed="${GUESSES[$i]}"
  actual="${GROUND_TRUTH[$i]}"

  if [ "$guessed" = "$actual" ]; then
    CORRECT=$((CORRECT + 1))
    is_correct=true
  else
    is_correct=false
    MISTAKES_JSON=$(jq --arg label "$label" --arg g "$guessed" --arg a "$actual" \
      '. + [{label: $label, guessed: $g, actual: $a}]' <<< "$MISTAKES_JSON")
  fi

  PERSONA_LABELS_JSON=$(jq \
    --arg label "$label" --arg g "$guessed" --arg a "$actual" --argjson c "$is_correct" \
    '. + {($label): {guessed: $g, actual: $a, correct: $c}}' <<< "$PERSONA_LABELS_JSON")
done

echo ""
echo "============================================================"
echo "Score: $CORRECT / 4"
echo "============================================================"
if [ "$CORRECT" -eq 4 ]; then
  pass "CORE-05 blinded-reader: 4/4 on $FIXTURE"
else
  fail "CORE-05 blinded-reader: $CORRECT/4 on $FIXTURE"
  echo "Mistakes:"
  jq -r '.[] | "  \(.label): guessed=\(.guessed), actual=\(.actual)"' <<< "$MISTAKES_JSON"
fi

# ---------------------------------------------------------------------------
# Step 7 (D-25 step 7): append result to JSON log.
# ---------------------------------------------------------------------------
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

TMP_RESULTS="$(mktemp)"
jq \
  --arg ts "$NOW" \
  --arg fx "$FIXTURE" \
  --arg rd "$RUN_DIR" \
  --argjson sc "$CORRECT" \
  --argjson total 4 \
  --argjson labels "$PERSONA_LABELS_JSON" \
  --argjson mistakes "$MISTAKES_JSON" \
  '. + [{
    timestamp: $ts,
    fixture: $fx,
    run_dir: $rd,
    score: $sc,
    total: $total,
    persona_labels: $labels,
    mistakes: $mistakes
  }]' \
  "$RESULTS" > "$TMP_RESULTS"
mv "$TMP_RESULTS" "$RESULTS"

echo "Result appended to: $RESULTS"

# ---------------------------------------------------------------------------
# Exit per ship-gate contract.
# D-26: phase gate — exit 0 only on 4/4.
# ---------------------------------------------------------------------------
[ "$CORRECT" -eq 4 ] || exit 1
exit 0
