#!/usr/bin/env bash
# dc-telemetry.sh <RUN_DIR> --runtime=<opencode|claude-code> [--dry-run]
#
# Fire-and-forget telemetry emitter for /devils-council:review. Reads a
# council run directory (containing MANIFEST.json) and POSTs a
# `review.completed` event to a configurable endpoint. Designed to be safe
# to invoke from a markdown command file: privacy-first, default-off, never
# blocks the parent flow.
#
# Usage:
#   DC_TELEMETRY=true ./bin/dc-telemetry.sh <RUN_DIR> --runtime=claude-code
#   DC_TELEMETRY=true ./bin/dc-telemetry.sh <RUN_DIR> --runtime=opencode --dry-run
#
# Exit codes: always 0. Silent on every failure path by design
# (fire-and-forget; D-HP-02 / D-FAIL-01).
#
# Environment:
#   DO_NOT_TRACK             If "1", exit immediately (W3C DNT honored before
#                            any other side effect). Highest precedence.
#   DC_TELEMETRY             Must be exact string "true" to opt in (D-OPT-A).
#   DC_TELEMETRY_ENDPOINT    Optional override; must be https:// (CORR-03 /
#                            SSRF allowlist). Defaults to the production
#                            endpoint below.
#   CLAUDE_PLUGIN_ROOT       For --runtime=claude-code: directory containing
#                            `.claude-plugin/plugin.json` (CORR-04).
#
# Decision anchors: D-HP-01..04, D-OPT-A, D-OPT-B, D-FAIL-01,
#                   CORR-02 (no verdict), CORR-03 (https-only + skip non-github),
#                   CORR-04 (per-runtime client_version), CORR-05 (portable date).

# --- 1. DNT short-circuit FIRST (D-OPT-B step 1) -----------------------------
# Must precede `set -euo pipefail` and any other read so the script truly does
# nothing under DO_NOT_TRACK=1.
[ "${DO_NOT_TRACK:-}" = "1" ] && exit 0

# --- 2. Opt-in gate SECOND (D-OPT-A) -----------------------------------------
# String equality only; "1" / "yes" / "on" are NOT accepted, per D-OPT-A.
[ "${DC_TELEMETRY:-}" != "true" ] && exit 0

set -euo pipefail

# --- 3. Path derivation (CORR-04 OpenCode dev/prod fallback needs REPO_ROOT) -
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- 4. Arg parse ------------------------------------------------------------
RUNTIME=""
RUN_DIR=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --runtime=opencode|--runtime=claude-code)
      RUNTIME="${1#--runtime=}"
      shift
      ;;
    --runtime=*)
      # Closed enum: unknown runtime value silently exits 0 (D-HP-04 /
      # command-injection mitigation — never propagate attacker-controlled
      # values into downstream logic).
      exit 0
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --*|-*)
      # Unknown flags silently exit 0 (fire-and-forget).
      exit 0
      ;;
    *)
      if [ -z "$RUN_DIR" ]; then
        RUN_DIR="$1"
        shift
      else
        # Extra positional args silently exit 0.
        exit 0
      fi
      ;;
  esac
done

# --- 5. Validate required args (silent on every failure) ---------------------
[ -n "$RUN_DIR" ] && [ -n "$RUNTIME" ] || exit 0
[ -d "$RUN_DIR" ] || exit 0
[ -f "$RUN_DIR/MANIFEST.json" ] || exit 0
MANIFEST="$RUN_DIR/MANIFEST.json"

# --- 6. Endpoint resolution with https-only allowlist (CORR-03) --------------
ENDPOINT="${DC_TELEMETRY_ENDPOINT:-https://dc-telemetry.pub.andyjwoodard.net/v1/events}"
case "$ENDPOINT" in
  https://*) : ;;
  *) exit 0 ;;
esac

# ============================================================================
# Helper functions — used by both dry-run (foreground) and production (forked)
# paths. Pure functions: take no implicit state beyond their `local` reads of
# the caller's already-set vars (RUNTIME, REPO_ROOT, MANIFEST, etc.).
# ============================================================================

# detect_github_owner_repo <remote_url>
# Echoes "owner/repo" to stdout on a github match, empty on any non-github.
# Server-shape sanity: exactly one "/", non-empty owner + repo.
detect_github_owner_repo() {
  local remote="${1:-}"
  local or=""
  case "$remote" in
    git@github.com:*)
      or="${remote#git@github.com:}"
      or="${or%.git}"
      ;;
    https://github.com/*)
      or="${remote#https://github.com/}"
      or="${or%.git}"
      ;;
    *)
      return 0
      ;;
  esac
  # Server-shape sanity check: exactly one "/", neither side empty.
  case "$or" in
    */*)
      local owner="${or%%/*}"
      local repo="${or#*/}"
      case "$repo" in */*) return 0 ;; esac  # more than one /
      [ -n "$owner" ] && [ -n "$repo" ] && printf '%s' "$or"
      ;;
  esac
  return 0
}

# resolve_client_version — echoes a semver string ("unknown" on any miss).
# claude-code: ${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json
# opencode:    dev tree (.opencode/package.json) → flattened-package (package.json) → unknown
resolve_client_version() {
  local ver_file=""
  case "$RUNTIME" in
    claude-code)
      ver_file="${CLAUDE_PLUGIN_ROOT:-}/.claude-plugin/plugin.json"
      ;;
    opencode)
      if [ -f "${REPO_ROOT}/.opencode/package.json" ]; then
        ver_file="${REPO_ROOT}/.opencode/package.json"
      else
        ver_file="${REPO_ROOT}/package.json"
      fi
      ;;
  esac
  if [ -n "$ver_file" ] && [ -f "$ver_file" ]; then
    jq -r '.version // "unknown"' "$ver_file" 2>/dev/null || printf 'unknown'
  else
    printf 'unknown'
  fi
}

# compute_duration_s — echoes integer seconds since MANIFEST.started_at (or 0).
# Portable across BSD (macOS) `date -j -f` and GNU `date -d` (CORR-05).
compute_duration_s() {
  local started
  started=$(jq -r '.started_at // empty' "$MANIFEST" 2>/dev/null || true)
  if [ -z "$started" ]; then
    printf '0'
    return 0
  fi
  local started_epoch now_epoch dur
  started_epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$started" "+%s" 2>/dev/null \
                  || date -u -d "$started" "+%s" 2>/dev/null \
                  || echo 0)
  now_epoch=$(date -u +%s)
  dur=$(( now_epoch - started_epoch ))
  [ "$dur" -ge 0 ] || dur=0
  printf '%s' "$dur"
}

# build_payload — emits a single-line JSON envelope matching
# action.yml:769-789 (CORR-02: no `verdict` key on wire).
# Reads: RUNTIME, OWNER_REPO, CLIENT_VERSION, DURATION_S,
#        BLOCKER_COUNT, MAJOR_COUNT, MINOR_COUNT, NIT_COUNT,
#        FINDINGS_TOTAL, FINDINGS_DROPPED, TRIGGERED_BENCH_JSON.
build_payload() {
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq -n -c \
    --arg owner_repo "$OWNER_REPO" \
    --arg ts "$ts" \
    --arg runtime "$RUNTIME" \
    --arg client_version "$CLIENT_VERSION" \
    --argjson blocker "$BLOCKER_COUNT" \
    --argjson major "$MAJOR_COUNT" \
    --argjson minor "$MINOR_COUNT" \
    --argjson nit "$NIT_COUNT" \
    --argjson findings_total "$FINDINGS_TOTAL" \
    --argjson findings_dropped "$FINDINGS_DROPPED" \
    --argjson duration_s "$DURATION_S" \
    --argjson triggered_bench "$TRIGGERED_BENCH_JSON" \
    '{
      event_type: "review.completed",
      owner_repo: $owner_repo,
      payload: {
        schema_version: 1,
        ts: $ts,
        source: "plugin",
        runtime: $runtime,
        client_version: $client_version,
        provider: null,
        model: null,
        blocker_count: $blocker,
        major_count: $major,
        minor_count: $minor,
        nit_count: $nit,
        findings_total: $findings_total,
        findings_dropped: $findings_dropped,
        duration_s: $duration_s,
        triggered_bench: $triggered_bench
      }
    }'
}

# aggregate_from_manifest — sets BLOCKER/MAJOR/MINOR/NIT_COUNT,
# FINDINGS_TOTAL, FINDINGS_DROPPED, TRIGGERED_BENCH_JSON from MANIFEST.json.
# Defensive: all jq queries default-or-zero on missing fields.
aggregate_from_manifest() {
  BLOCKER_COUNT=$(jq '[.personas_run[]?.findings[]? | select(.severity=="blocker")] | length' "$MANIFEST" 2>/dev/null || echo 0)
  MAJOR_COUNT=$(jq   '[.personas_run[]?.findings[]? | select(.severity=="major")]   | length' "$MANIFEST" 2>/dev/null || echo 0)
  MINOR_COUNT=$(jq   '[.personas_run[]?.findings[]? | select(.severity=="minor")]   | length' "$MANIFEST" 2>/dev/null || echo 0)
  NIT_COUNT=$(jq     '[.personas_run[]?.findings[]? | select(.severity=="nit")]     | length' "$MANIFEST" 2>/dev/null || echo 0)
  FINDINGS_TOTAL=$(jq    '.findings_kept    // 0' "$MANIFEST" 2>/dev/null || echo 0)
  FINDINGS_DROPPED=$(jq  '.findings_dropped // 0' "$MANIFEST" 2>/dev/null || echo 0)
  # TRIGGERED_BENCH — personas with non-empty findings, sorted/unique.
  TRIGGERED_BENCH_JSON=$(jq -c '[.personas_run[]? | select((.findings // []) | length > 0) | .name] | sort | unique' "$MANIFEST" 2>/dev/null || echo '[]')
}

# ============================================================================
# Branch on --dry-run.
# ============================================================================

if [ "$DRY_RUN" = "1" ]; then
  # Foreground compute + print + exit. No fork; no network.
  REMOTE=$(git remote get-url origin 2>/dev/null || true)
  OWNER_REPO=$(detect_github_owner_repo "$REMOTE")
  [ -z "$OWNER_REPO" ] && exit 0

  aggregate_from_manifest
  CLIENT_VERSION=$(resolve_client_version)
  DURATION_S=$(compute_duration_s)
  PAYLOAD=$(build_payload)

  printf 'dry-run: runtime=%s\n' "$RUNTIME"
  printf 'dry-run: run_dir=%s\n' "$RUN_DIR"
  printf 'dry-run: endpoint=%s\n' "$ENDPOINT"
  printf 'dry-run: owner_repo=%s\n' "$OWNER_REPO"
  printf 'dry-run: client_version=%s\n' "$CLIENT_VERSION"
  printf 'dry-run: duration_s=%s\n' "$DURATION_S"
  printf 'dry-run: payload=%s\n' "$PAYLOAD"
  exit 0
fi

# ============================================================================
# Production POST — backgrounded, disowned. Foreground returns immediately.
# All non-trivial work (git, jq, date, curl) happens INSIDE the fork so the
# parent shell sees ~5-10ms total before continuing the review flow (D-HP-02).
# ============================================================================
(
  REMOTE=$(git remote get-url origin 2>/dev/null || true)
  OWNER_REPO=$(detect_github_owner_repo "$REMOTE")
  [ -z "$OWNER_REPO" ] && exit 0

  aggregate_from_manifest
  CLIENT_VERSION=$(resolve_client_version)
  DURATION_S=$(compute_duration_s)
  PAYLOAD=$(build_payload)

  curl --max-time 3 --connect-timeout 2 --silent --show-error \
       -X POST -H 'Content-Type: application/json' \
       --data-binary "$PAYLOAD" "$ENDPOINT" >/dev/null 2>&1 || true
) & disown

exit 0
