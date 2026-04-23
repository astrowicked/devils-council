#!/usr/bin/env bash
# dc-budget-plan.sh <run-dir> [--only=<csv>] [--exclude=<csv>] [--cap-usd=<N>] [--config=<path>]
#
# Reads:
#   <run-dir>/MANIFEST.json   (.triggered_personas, .trigger_reasons)
#   config.json               (.budget — cap_usd, per_persona_estimate_usd, bench_priority_order)
#
# Writes into <run-dir>/MANIFEST.json:
#   .budget = {cap_usd, per_persona_estimate_usd, max_spawnable_bench,
#              spawned_bench_count, skipped_personas, actual_cost_usd: null,
#              over_budget, errors}
#   .personas_skipped = [{persona, reason: "budget_cap"|"excluded_by_flag"}]
#
# Emits to stdout:
#   SPAWN_BENCH=slug1,slug2,...      (comma-separated; may be empty)
#   ERRORS=0                          (or N when over-budget pre-spawn error raised)
#
# Exit code 0 on success (even when over_budget=true); 2 on usage error.
#
# D-56: pre-spawn only. Never kills a running Agent() — just narrows the
# candidate set BEFORE the conductor spawns the parallel turn.
# D-58: --exclude wins over --only for the same persona. --cap-usd overrides config.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

err() { printf 'dc-budget-plan: ERROR: %s\n' "$*" >&2; }

RUN_DIR=""
ONLY_CSV=""
EXCLUDE_CSV=""
CAP_USD_OVERRIDE=""
CONFIG_PATH="${REPO_ROOT}/config.json"

while [ $# -gt 0 ]; do
  case "$1" in
    --only=*)    ONLY_CSV="${1#--only=}"; shift ;;
    --exclude=*) EXCLUDE_CSV="${1#--exclude=}"; shift ;;
    --cap-usd=*) CAP_USD_OVERRIDE="${1#--cap-usd=}"; shift ;;
    --config=*)  CONFIG_PATH="${1#--config=}"; shift ;;
    --help|-h)   echo "usage: dc-budget-plan.sh <run-dir> [--only=a,b] [--exclude=a,b] [--cap-usd=N] [--config=path]"; exit 0 ;;
    --*)         err "unknown flag: $1"; exit 2 ;;
    *)
      if [ -z "$RUN_DIR" ]; then RUN_DIR="$1"; shift
      else err "unexpected positional: $1"; exit 2
      fi
      ;;
  esac
done

# --cap-usd is validated BEFORE checking RUN_DIR existence so malformed
# caps fail fast regardless of the target dir (per T-06-04 mitigation).
if [ -n "$CAP_USD_OVERRIDE" ]; then
  if ! printf '%s' "$CAP_USD_OVERRIDE" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
    err "--cap-usd requires a positive decimal number (got: '$CAP_USD_OVERRIDE'); no sentinel values (per D-58)"
    exit 2
  fi
fi

[ -n "$RUN_DIR" ]                || { err "run-dir required"; exit 2; }
[ -f "$RUN_DIR/MANIFEST.json" ]  || { err "MANIFEST.json not found"; exit 2; }
[ -f "$CONFIG_PATH" ]            || { err "config.json not found: $CONFIG_PATH"; exit 2; }
command -v jq >/dev/null 2>&1    || { err "jq required"; exit 2; }

MANIFEST="$RUN_DIR/MANIFEST.json"

# Load budget config (defaults match D-57 if config is minimal)
CAP_USD=$(jq -r '.budget.cap_usd // 0.50' "$CONFIG_PATH")
PER_PERSONA_USD=$(jq -r '.budget.per_persona_estimate_usd // 0.08' "$CONFIG_PATH")
PRIORITY_ORDER_JSON=$(jq -c '.budget.bench_priority_order // ["security-reviewer","dual-deploy-reviewer","finops-auditor","air-gap-reviewer"]' "$CONFIG_PATH")

# Apply --cap-usd override (already validated above)
if [ -n "$CAP_USD_OVERRIDE" ]; then
  CAP_USD="$CAP_USD_OVERRIDE"
fi

# Extract triggered bench personas from classifier result
TRIGGERED_JSON=$(jq -c '.triggered_personas // []' "$MANIFEST")

# Apply --only filter (D-58: narrows bench candidates; --only is set semantics)
CANDIDATE_JSON="$TRIGGERED_JSON"
if [ -n "$ONLY_CSV" ]; then
  ONLY_JSON=$(printf '%s' "$ONLY_CSV" | jq -R 'split(",") | map(. | gsub("\\s"; ""))')
  CANDIDATE_JSON=$(jq -n --argjson triggered "$CANDIDATE_JSON" --argjson only "$ONLY_JSON" '
    $triggered | map(select(. as $p | $only | index($p)))
  ')
fi

# Apply --exclude filter (D-58: wins over --only for same persona)
EXCLUDE_JSON='[]'
if [ -n "$EXCLUDE_CSV" ]; then
  EXCLUDE_JSON=$(printf '%s' "$EXCLUDE_CSV" | jq -R 'split(",") | map(. | gsub("\\s"; ""))')
  CANDIDATE_JSON=$(jq -n --argjson candidates "$CANDIDATE_JSON" --argjson exclude "$EXCLUDE_JSON" '
    $candidates | map(select(. as $p | $exclude | index($p) | not))
  ')
fi

# Build the --only set (may be empty array) for later skip reasoning
ONLY_JSON_FOR_SKIP='[]'
if [ -n "$ONLY_CSV" ]; then
  ONLY_JSON_FOR_SKIP=$(printf '%s' "$ONLY_CSV" | jq -R 'split(",") | map(. | gsub("\\s"; ""))')
fi

# Compute max_spawnable = floor(cap_usd / per_persona_estimate_usd)
MAX_SPAWNABLE=$(awk -v cap="$CAP_USD" -v per="$PER_PERSONA_USD" 'BEGIN { if (per <= 0) { print 0 } else { print int(cap / per) } }')
[ "$MAX_SPAWNABLE" -lt 0 ] && MAX_SPAWNABLE=0

# Order candidates by priority order; personas NOT in priority order sort last (stable)
ORDERED_JSON=$(jq -n --argjson candidates "$CANDIDATE_JSON" --argjson priority "$PRIORITY_ORDER_JSON" '
  ($priority | map(select(. as $p | $candidates | index($p)))) +
  ($candidates | map(select(. as $p | $priority | index($p) | not)))
')

CANDIDATE_COUNT=$(printf '%s' "$ORDERED_JSON" | jq 'length')
ESTIMATED_USD=$(awk -v n="$CANDIDATE_COUNT" -v per="$PER_PERSONA_USD" 'BEGIN { printf("%.4f", n * per) }')
OVER_BUDGET=false
ERRORS_JSON='[]'
if [ "$CANDIDATE_COUNT" -gt "$MAX_SPAWNABLE" ]; then
  OVER_BUDGET=true
  # --cap-usd override with over-budget produces a structural error pre-spawn per D-58
  if [ -n "$CAP_USD_OVERRIDE" ]; then
    ERRORS_JSON=$(jq -n --argjson req "$CANDIDATE_COUNT" --argjson allowed "$MAX_SPAWNABLE" \
      --arg cap "$CAP_USD" --arg est "$ESTIMATED_USD" '
      [{code: "cap_exceeded", requested_personas: $req, allowed: $allowed, cap_usd: ($cap|tonumber), estimate_usd: ($est|tonumber)}]
    ')
  fi
fi

# Select the first MAX_SPAWNABLE personas from the ordered list
SPAWN_JSON=$(jq -n --argjson ordered "$ORDERED_JSON" --argjson n "$MAX_SPAWNABLE" '$ordered[0:$n]')
SPAWN_COUNT=$(printf '%s' "$SPAWN_JSON" | jq 'length')
SPAWN_CSV=$(printf '%s' "$SPAWN_JSON" | jq -r 'join(",")')

# Build personas_skipped: classify every triggered persona that didn't make SPAWN_JSON
# Order: spawn > excluded_by_flag (via --exclude or not in --only) > budget_cap
SKIPPED_JSON=$(jq -n \
  --argjson triggered "$TRIGGERED_JSON" \
  --argjson spawn "$SPAWN_JSON" \
  --argjson onl "$ONLY_JSON_FOR_SKIP" \
  --argjson exc "$EXCLUDE_JSON" '
  $triggered | map(. as $p |
    if ($spawn | index($p)) then empty
    elif ($exc | index($p)) then {persona: $p, reason: "excluded_by_flag"}
    elif ($onl | length) > 0 and ($onl | index($p) | not) then {persona: $p, reason: "excluded_by_flag"}
    else {persona: $p, reason: "budget_cap"}
    end
  )
')

# Merge into MANIFEST
TMP_MF=$(mktemp)
jq --argjson cap "$CAP_USD" \
   --argjson per "$PER_PERSONA_USD" \
   --argjson maxs "$MAX_SPAWNABLE" \
   --argjson spawn_count "$SPAWN_COUNT" \
   --argjson skipped "$SKIPPED_JSON" \
   --argjson over "$OVER_BUDGET" \
   --argjson errors "$ERRORS_JSON" '
  .budget = {
    cap_usd: $cap,
    per_persona_estimate_usd: $per,
    max_spawnable_bench: $maxs,
    spawned_bench_count: $spawn_count,
    skipped_personas: [$skipped[].persona],
    actual_cost_usd: null,
    over_budget: $over,
    errors: $errors
  }
  | .personas_skipped = $skipped
' "$MANIFEST" > "$TMP_MF" && mv "$TMP_MF" "$MANIFEST"

# Emit plan to stdout
printf 'SPAWN_BENCH=%s\n' "$SPAWN_CSV"
printf 'ERRORS=%s\n' "$(printf '%s' "$ERRORS_JSON" | jq 'length')"
exit 0
