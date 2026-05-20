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
#
# Decision anchors: D-HP-01..04, D-OPT-A, D-OPT-B, D-FAIL-01,
#                   CORR-03 (https-only), CORR-04, CORR-05.
#
# This file (Phase 6 Plan 01) ships ONLY the gating + arg-parse + --dry-run
# layers. Plan 03 will append the payload-assembly + backgrounded curl POST.

# --- 1. DNT short-circuit FIRST (D-OPT-B step 1) -----------------------------
# Must precede `set -euo pipefail` and any other read so the script truly does
# nothing under DO_NOT_TRACK=1. Use ${VAR:-} form so set -u (added below) is
# safe; this read here is technically pre-`set -u` but kept defensive.
[ "${DO_NOT_TRACK:-}" = "1" ] && exit 0

# --- 2. Opt-in gate SECOND (D-OPT-A) -----------------------------------------
# String equality only; "1" / "yes" / "on" are NOT accepted, per D-OPT-A.
[ "${DC_TELEMETRY:-}" != "true" ] && exit 0

set -euo pipefail

# --- 3. Path derivation deferred to Plan 03 ----------------------------------
# Plan 03 will add SCRIPT_DIR/REPO_ROOT derivation (matching bin/dc-prep.sh)
# for package.json lookup. The gating + dry-run subset shipped in Plan 01
# does not need them, and shellcheck SC2034 flags them as unused.

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

# --- 6. Endpoint resolution with https-only allowlist (CORR-03) --------------
ENDPOINT="${DC_TELEMETRY_ENDPOINT:-https://dc-telemetry.pub.andyjwoodard.net/v1/events}"
case "$ENDPOINT" in
  https://*) : ;;
  *) exit 0 ;;
esac

# --- 7. Dry-run print surface (testability — PLUG-04) ------------------------
if [ "$DRY_RUN" = "1" ]; then
  printf 'dry-run: runtime=%s\n' "$RUNTIME"
  printf 'dry-run: run_dir=%s\n' "$RUN_DIR"
  printf 'dry-run: endpoint=%s\n' "$ENDPOINT"
  exit 0
fi

# --- 8. Real POST path lands in Plan 03 --------------------------------------
# Plan 03 replaces this block with: jq payload assembly, git-remote owner_repo
# detection, client_version per-runtime lookup, portable duration_s math, and a
# backgrounded `(curl ... || true) &; disown` invocation. For Plan 01, exit 0
# so the contract surface (gating + dry-run) is testable in isolation.
exit 0
