#!/usr/bin/env bash
# dc-prep.sh <artifact-path> [--type=<code-diff|plan|rfc>] [--type <code-diff|plan|rfc>]
#
# Deterministic prep step for /devils-council:review. Runs via shell-injection
# at prompt-load time. Classifies the artifact, snapshots to INPUT.md, writes
# initial MANIFEST.json, emits `RUN_DIR=<path>` as final stdout line.
#
# Decision anchors: D-02 (hybrid conductor/prep split), D-03 (run dir format),
#                   D-04 (MANIFEST.json init), D-05 (classifier precedence),
#                   D-06 (--type override), D-07 (safe default),
#                   ADD-1 (per-run nonce for XML framing).
#
# Stdout contract:
#   Success: final line is `RUN_DIR=<relative-path>` (LF-terminated)
#   Failure: final line is `RUN_DIR=ERROR: <reason>` (LF-terminated), exit 1
#
# Diagnostics go to stderr; stdout is reserved for the RUN_DIR line so
# shell-injection capture does not leak debug text into the conductor prompt.

set -euo pipefail

err() { printf 'RUN_DIR=ERROR: %s\n' "$*"; exit 1; }

# --- 1. flag parse (accept both --type=X and --type X; preserve positional) ---
TYPE_OVERRIDE=""
ARTIFACT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --type=*)
      TYPE_OVERRIDE="${1#--type=}"
      shift
      ;;
    --type)
      shift
      [ $# -gt 0 ] || err "--type requires value"
      TYPE_OVERRIDE="$1"
      shift
      ;;
    --)
      shift
      ;;
    -*)
      err "unknown flag: $1"
      ;;
    *)
      if [ -z "$ARTIFACT" ]; then
        ARTIFACT="$1"
      else
        err "unexpected arg '$1'"
      fi
      shift
      ;;
  esac
done

[ -n "$ARTIFACT" ] || err "usage: dc-prep.sh <artifact> [--type=<code-diff|plan|rfc>]"
[ -f "$ARTIFACT" ] || err "artifact not found: $ARTIFACT"

# Validate --type override value if supplied.
if [ -n "$TYPE_OVERRIDE" ]; then
  case "$TYPE_OVERRIDE" in
    code-diff|plan|rfc) ;;
    *) err "invalid --type value '$TYPE_OVERRIDE' (expected code-diff|plan|rfc)" ;;
  esac
fi

# --- 2. binary guard (Pitfall 7) ---
MIME=$(file --mime "$ARTIFACT" 2>/dev/null || printf '')
case "$MIME" in
  *charset=binary*) err "binary artifacts not supported in v1" ;;
esac

# --- 3. size guard (Claude's-discretion 100KB cap) ---
BYTES=$(wc -c < "$ARTIFACT" | tr -d ' ')
case "$BYTES" in
  ''|*[!0-9]*) err "could not determine artifact size" ;;
esac
[ "$BYTES" -lt 102400 ] || err "artifact > 100KB (v1 limit)"

# --- 4. classifier: D-05 precedence (ext → diff-prefix → PLAN → RFC → line-count) ---
detect_type() {
  local path="$1"

  # Rule 1: filename extension
  case "$path" in
    *.patch|*.diff) printf 'code-diff'; return ;;
  esac

  # Rule 2: content starts with a diff marker
  local first
  first=$(head -n1 "$path" 2>/dev/null || printf '')
  case "$first" in
    'diff --git '*|'--- a/'*|'Index: '*)
      printf 'code-diff'
      return
      ;;
  esac

  # Detect YAML frontmatter (first line is exactly `---`).
  local has_fm="no"
  if head -n1 "$path" 2>/dev/null | grep -qxE '^---[[:space:]]*$'; then
    has_fm="yes"
  fi

  # Scan first 50 lines for headings we care about.
  local head_scan
  head_scan=$(head -n 50 "$path" 2>/dev/null || printf '')

  # Rule 3: YAML frontmatter + heading containing PLAN (case-insensitive),
  # OR a heading that starts with PLAN as the first word after the # marker.
  if printf '%s\n' "$head_scan" | grep -qiE '^#[[:space:]]*.*\bPLAN\b'; then
    if [ "$has_fm" = "yes" ] || printf '%s\n' "$head_scan" | grep -qiE '^#[[:space:]]*PLAN\b'; then
      printf 'plan'
      return
    fi
  fi

  # Rule 4: YAML frontmatter present OR heading starts with `# RFC` (case-insensitive).
  if printf '%s\n' "$head_scan" | grep -qiE '^#[[:space:]]+RFC\b'; then
    printf 'rfc'
    return
  fi
  if [ "$has_fm" = "yes" ]; then
    printf 'rfc'
    return
  fi

  # Rule 5: line-count fallback — net +/- prefixed lines > 10 ⇒ code-diff, else rfc.
  local plusminus
  plusminus=$(grep -cE '^[+-][^+-]' "$path" 2>/dev/null || printf '0')
  if [ "${plusminus:-0}" -gt 10 ]; then
    printf 'code-diff'
    return
  fi

  printf 'rfc'
}

CLASSIFIED=$(detect_type "$ARTIFACT")
CLASSIFICATION_WARNING="null"
if [ -z "$CLASSIFIED" ]; then
  # Defensive: detect_type always returns something, but honor D-07 safe default.
  CLASSIFIED="rfc"
  CLASSIFICATION_WARNING='"type detection failed, defaulted to rfc"'
fi
TYPE="${TYPE_OVERRIDE:-$CLASSIFIED}"

# --- 5. slug + timestamp + run-dir creation with collision guard (Pitfall 6) ---
TS=$(date -u +%Y%m%dT%H%M%SZ)
BASE=$(basename "$ARTIFACT")
# Strip ONLY the final extension; lowercase; non-[a-z0-9-] → `-`; collapse; trim; cap 40 chars.
SLUG=$(printf '%s' "${BASE%.*}" \
  | tr '[:upper:]' '[:lower:]' \
  | tr -c 'a-z0-9-' '-' \
  | tr -s '-' \
  | sed 's/^-//; s/-$//' \
  | cut -c1-40)
[ -n "$SLUG" ] || SLUG="artifact"

RUN_DIR=".council/${TS}-${SLUG}"
if [ -d "$RUN_DIR" ]; then
  SUFFIX=$(od -An -N2 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')
  [ -n "$SUFFIX" ] || err "failed to generate collision suffix"
  RUN_DIR="${RUN_DIR}-${SUFFIX}"
fi

mkdir -p "$RUN_DIR"

# --- 6. snapshot INPUT.md (byte-identical — cp, not cat) ---
cp "$ARTIFACT" "$RUN_DIR/INPUT.md"

# --- 7. portable SHA256 ---
if command -v shasum >/dev/null 2>&1; then
  SHA=$(shasum -a 256 "$RUN_DIR/INPUT.md" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
  SHA=$(sha256sum "$RUN_DIR/INPUT.md" | awk '{print $1}')
else
  err "no sha256 tool available (expected shasum or sha256sum)"
fi

# --- 8. nonce generation (ADD-1: 6-8 hex chars, rotates per run) ---
if command -v od >/dev/null 2>&1; then
  NONCE=$(od -An -N4 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')
elif command -v openssl >/dev/null 2>&1; then
  NONCE=$(openssl rand -hex 4)
else
  err "no nonce source available (expected od or openssl)"
fi
# Guard: nonce MUST be 6-8 hex chars. od -N4 yields 8; fallback path still checked.
if [ "${#NONCE}" -lt 6 ] || [ "${#NONCE}" -gt 8 ]; then
  err "nonce length invalid (got ${#NONCE})"
fi

# --- 9. plugin version lookup (null if manifest absent or unreadable) ---
PLUGIN_VERSION=""
if [ -f .claude-plugin/plugin.json ]; then
  PLUGIN_VERSION=$(jq -r '.version // empty' .claude-plugin/plugin.json 2>/dev/null || printf '')
fi

# --- 10. MANIFEST.json emit via jq -n (correct quoting + unicode) ---
jq -n \
  --arg artifact_path "$ARTIFACT" \
  --arg detected_type "$TYPE" \
  --arg run_dir "$RUN_DIR" \
  --arg started_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg sha256 "$SHA" \
  --arg nonce "$NONCE" \
  --argjson bytes "$BYTES" \
  --argjson warning "$CLASSIFICATION_WARNING" \
  --arg plugin_version "$PLUGIN_VERSION" \
  '{
    artifact_path: $artifact_path,
    detected_type: $detected_type,
    run_dir: $run_dir,
    started_at: $started_at,
    sha256: $sha256,
    nonce: $nonce,
    bytes: $bytes,
    personas_run: [],
    findings_kept: 0,
    findings_dropped: 0,
    budget_usage: null,
    classification_warning: $warning,
    plugin_version: (if $plugin_version == "" then null else $plugin_version end)
  }' > "$RUN_DIR/MANIFEST.json"

# --- 11. final stdout line (load-bearing — shell-injection captures this) ---
printf 'RUN_DIR=%s\n' "$RUN_DIR"
