#!/usr/bin/env bash
# dc-validate-synthesis.sh <run-dir>
#
# Conductor-side synthesis validator for the devils-council review engine.
# Runs AFTER the Council Chair subagent writes <run-dir>/SYNTHESIS.md.draft
# and BEFORE the conductor renders final output.
#
# Checks (per D-45):
#   (1) Required sections present (per persona-metadata/council-chair.yml
#       required_sections; or required_sections_no_survivors if all four
#       critic personas failed — per D-43).
#   (2) Every `## Contradictions` entry cites >= min_contradiction_anchors
#       finding IDs, all resolvable in MANIFEST.personas_run[].findings[].id.
#   (3) Every `## Top-3 Blocking Concerns` entry cites >= 1 resolvable ID
#       AND the cited finding's target is in the D-34 candidate set (blockers
#       union targets-raised-by->=2-personas).
#   (4) No `banned_tokens` from the sidecar appear anywhere in the draft
#       body (case-insensitive substring; word-boundary guard for "5/10"
#       and "7/10" to avoid false positives on fraction prose).
#
# On pass: mv draft -> SYNTHESIS.md; write MANIFEST.synthesis {ran: true,
# validation.passed: true, ...}. Exit 0.
# On fail: mv draft -> SYNTHESIS.md.invalid; write MANIFEST.synthesis
# {ran: false, validation.passed: false, validation.errors: [...]}.
# Exit 1.
#
# SINGLE-PASS by design (ENGN-07 + D-15). Never re-invokes the Chair.
#
# Exit codes:
#   0 — draft passed validation, final SYNTHESIS.md written
#   1 — draft failed validation, .invalid written, MANIFEST records errors
#   2 — usage / missing input (run dir, draft, manifest, sidecar)

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

err()  { printf 'dc-validate-synthesis: ERROR: %s\n' "$*" >&2; }
warn() { printf 'dc-validate-synthesis: WARN: %s\n'  "$*" >&2; }

usage() {
  cat >&2 <<'USAGE'
dc-validate-synthesis.sh <run-dir>

  <run-dir>   run directory containing SYNTHESIS.md.draft + MANIFEST.json

Exit codes:
  0 — draft passed validation, final SYNTHESIS.md written
  1 — draft failed validation, MANIFEST records errors
  2 — usage / missing input
USAGE
}

# --- 1. argument parse ---
if [ $# -ne 1 ]; then
  usage
  exit 2
fi

RUN_DIR="$1"
DRAFT="$RUN_DIR/SYNTHESIS.md.draft"
FINAL="$RUN_DIR/SYNTHESIS.md"
INVALID="$RUN_DIR/SYNTHESIS.md.invalid"
MANIFEST="$RUN_DIR/MANIFEST.json"
SIDECAR="$REPO_ROOT/persona-metadata/council-chair.yml"

[ -d "$RUN_DIR" ]  || { err "run dir not found: $RUN_DIR";                exit 2; }
[ -f "$DRAFT" ]    || { err "synthesis draft not found: $DRAFT";          exit 2; }
[ -f "$MANIFEST" ] || { err "MANIFEST.json not found: $MANIFEST";         exit 2; }
[ -f "$SIDECAR" ]  || { err "council-chair sidecar missing: $SIDECAR";    exit 2; }

# --- 2. tool availability ---
if ! command -v jq >/dev/null 2>&1; then
  err "jq required; brew install jq / apt-get install jq"
  exit 2
fi
if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' >/dev/null 2>&1; then
  err "python3 with PyYAML required; pip3 install pyyaml"
  exit 2
fi

# --- 3. temp workspace ---
TMPDIR_RUN=$(mktemp -d -t dc-validate-synth.XXXXXX)
trap 'rm -rf "$TMPDIR_RUN"' EXIT

# --- 4. extract stamped IDs + candidate set from MANIFEST.personas_run[].findings[] ---
# Stamped IDs: the universe of resolvable ids.
STAMPED_IDS_FILE="$TMPDIR_RUN/stamped-ids"
jq -r '[.personas_run[]? | select(.findings?) | .findings[]?.id // empty] | .[]' \
  "$MANIFEST" > "$STAMPED_IDS_FILE" || true

# Survivor count (personas with findings[] present, irrespective of length) —
# drives the D-43 zero-survivors edge case. A failed-stub persona has no findings[].
SURVIVOR_COUNT=$(jq '[.personas_run[]? | select(.findings?)] | length' "$MANIFEST")

# D-34 candidate set: {f.target | f.severity=="blocker"} ∪ {t | target raised by >=2 distinct personas}
CANDIDATE_TARGETS_FILE="$TMPDIR_RUN/candidate-targets"
jq -r '
  [.personas_run[]? | select(.findings?) | .name as $p | .findings[]? | {persona: $p, target, severity}]
  as $all
  | (
      ([$all[] | select(.severity == "blocker") | .target])
      +
      ([$all
        | group_by(.target)
        | map(select((map(.persona) | unique | length) >= 2))
        | .[] | .[0].target])
    )
  | unique | .[]
' "$MANIFEST" > "$CANDIDATE_TARGETS_FILE" || true

# Missing personas: names with outcome failed_missing_draft or failed_validator_error.
MISSING_PERSONAS_JSON=$(jq -c '
  [.personas_run[]? | select(.outcome == "failed_missing_draft" or .outcome == "failed_validator_error") | .name]
' "$MANIFEST")

export STAMPED_IDS_FILE CANDIDATE_TARGETS_FILE SURVIVOR_COUNT
