#!/usr/bin/env bash
# validate-personas.sh — Deterministic schema validator for agents/*.md.
#
# Implements PERSONA-SCHEMA.md §"Validator Summary" (rules R1-R8 + W1-W3).
# Schema-only. No LLM calls. No network. No writes. Read-only.
#
# Usage:
#   validate-personas.sh                       validate every agents/*.md
#   validate-personas.sh <file>                validate exactly one file
#   validate-personas.sh --signals <path>      override lib/signals.json path
#   validate-personas.sh -h | --help           show usage
#
# Exit codes:
#   0 — all files pass hard-fail rules (soft warnings allowed)
#   1 — one or more hard-fail violations
#   2 — usage / environment error (missing parser, bad signals.json, etc.)
#
# Hard rules (exit 1 on any violation, all violations reported):
#   R1  frontmatter present AND parses as valid YAML
#   R2  `tier` present AND ∈ {core, bench, chair}
#   R3  `primary_concern` present AND non-empty string
#   R4  `blind_spots` present AND non-empty list
#   R5  `characteristic_objections` present AND length >= 3
#   R6  `banned_phrases` present AND non-empty list
#   R7  if tier == bench: `triggers` non-empty AND every ID ∈ signals.json keys
#   R8  if tier ∈ {core, chair}: `triggers` empty or absent
#
# Soft warnings (stderr only, exit code unchanged):
#   W1  banned_phrases missing any of "consider" / "think about" / "be aware of"
#   W2  body lacks `## Examples` H2
#   W3  frontmatter contains `hooks`, `mcpServers`, or `permissionMode`
#       (stripped silently by Claude Code for plugin-shipped agents)

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

err()  { printf 'validate-personas: ERROR: %s\n' "$*" >&2; }
warn() { printf 'validate-personas: WARN: %s\n' "$*" >&2; }

usage() {
  cat <<'USAGE'
validate-personas.sh — deterministic schema validator for agents/*.md

Usage:
  validate-personas.sh                       validate all agents/*.md
  validate-personas.sh <file>                validate one file
  validate-personas.sh --signals <path>      override signal registry path
  validate-personas.sh -h | --help           show this help

Exit codes:
  0 — all files pass hard-fail rules
  1 — one or more hard-fail violations
  2 — usage / environment error (missing yq+python, bad signals.json, etc.)
USAGE
}

# -----------------------------------------------------------------------------
# 1. Argument parsing
# -----------------------------------------------------------------------------

SIGNALS_PATH="${REPO_ROOT}/lib/signals.json"
TARGET_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --signals)
      if [ $# -lt 2 ]; then
        err "--signals requires a path argument"
        exit 2
      fi
      SIGNALS_PATH="$2"
      shift 2
      ;;
    --signals=*)
      SIGNALS_PATH="${1#--signals=}"
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      err "unknown option: $1"
      usage >&2
      exit 2
      ;;
    *)
      if [ -n "$TARGET_FILE" ]; then
        err "only one positional path argument is supported (got '$TARGET_FILE' and '$1')"
        exit 2
      fi
      TARGET_FILE="$1"
      shift
      ;;
  esac
done

# -----------------------------------------------------------------------------
# 2. Parser detection (prefer Go-based mikefarah/yq, fall back to python3+PyYAML)
# -----------------------------------------------------------------------------

YAML_PARSER=""
if command -v yq >/dev/null 2>&1; then
  # Sanity-check: mikefarah/yq prints "version" somewhere in --version.
  if yq --version >/dev/null 2>&1; then
    YAML_PARSER="yq"
  fi
fi

if [ -z "$YAML_PARSER" ] && command -v python3 >/dev/null 2>&1; then
  if python3 -c 'import yaml' >/dev/null 2>&1; then
    YAML_PARSER="python3"
  fi
fi

if [ -z "$YAML_PARSER" ]; then
  err "no YAML parser available. Install one of:"
  err "  brew install yq                 # mikefarah/yq (preferred)"
  err "  pip3 install pyyaml             # python3 + PyYAML fallback"
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  err "jq is required but not installed. brew install jq / apt-get install jq"
  exit 2
fi

# -----------------------------------------------------------------------------
# 3. Signal registry load
# -----------------------------------------------------------------------------

if [ ! -f "$SIGNALS_PATH" ]; then
  err "signals registry not found: $SIGNALS_PATH"
  exit 2
fi

if ! jq -e '.signals | type == "object"' "$SIGNALS_PATH" >/dev/null 2>&1; then
  err "signals registry malformed or missing .signals object: $SIGNALS_PATH"
  exit 2
fi

# VALID_SIGNAL_IDS — newline-delimited list of keys in .signals.
VALID_SIGNAL_IDS="$(jq -r '.signals | keys[]' "$SIGNALS_PATH")"

# -----------------------------------------------------------------------------
# 4. Frontmatter extraction + YAML helpers
# -----------------------------------------------------------------------------

# extract_frontmatter <file> → prints the YAML block between the first pair of
# --- fences to stdout. Exits non-zero if no fenced frontmatter found.
extract_frontmatter() {
  local file=$1
  awk '
    BEGIN { state = 0 }
    {
      if (state == 0) {
        if ($0 == "---") { state = 1; next }
        # Non-fence before frontmatter opener → no frontmatter.
        if (NF > 0) { exit 2 }
        next
      }
      if (state == 1) {
        if ($0 == "---") { state = 2; exit 0 }
        print
      }
    }
    END {
      if (state != 2) exit 2
    }
  ' "$file"
}

# extract_body <file> → prints everything AFTER the closing --- fence.
extract_body() {
  local file=$1
  awk '
    BEGIN { state = 0 }
    {
      if (state == 0) {
        if ($0 == "---") { state = 1; next }
        next
      }
      if (state == 1) {
        if ($0 == "---") { state = 2; next }
        next
      }
      if (state == 2) { print }
    }
  ' "$file"
}

# yaml_parse_check <yaml-text> → exit 0 if parses, non-zero otherwise.
# Prints parser error (if any) on stderr.
yaml_parse_check() {
  local text=$1
  if [ "$YAML_PARSER" = "yq" ]; then
    printf '%s\n' "$text" | yq eval '.' - >/dev/null 2>&1
  else
    printf '%s\n' "$text" | python3 -c 'import sys, yaml; yaml.safe_load(sys.stdin)' >/dev/null 2>&1
  fi
}

# yaml_has_key <yaml-text> <key> → exit 0 if top-level key present, non-zero otherwise.
yaml_has_key() {
  local text=$1; local key=$2
  if [ "$YAML_PARSER" = "yq" ]; then
    local result
    result=$(printf '%s\n' "$text" | yq eval "has(\"${key}\")" - 2>/dev/null || printf 'false')
    [ "$result" = "true" ]
  else
    printf '%s\n' "$text" | python3 -c "
import sys, yaml
d = yaml.safe_load(sys.stdin) or {}
sys.exit(0 if isinstance(d, dict) and '${key}' in d else 1)
" 2>/dev/null
  fi
}

# yaml_type <yaml-text> <key> → prints type: !!str, !!seq, !!map, !!null, or empty.
# Uses a normalized vocabulary: string, list, map, null, missing.
yaml_type() {
  local text=$1; local key=$2
  if [ "$YAML_PARSER" = "yq" ]; then
    local t
    t=$(printf '%s\n' "$text" | yq eval ".${key} | tag" - 2>/dev/null || printf '')
    case "$t" in
      '!!str')  printf 'string' ;;
      '!!seq')  printf 'list' ;;
      '!!map')  printf 'map' ;;
      '!!int')  printf 'int' ;;
      '!!float') printf 'float' ;;
      '!!bool') printf 'bool' ;;
      '!!null') printf 'null' ;;
      '')       printf 'missing' ;;
      *)        printf 'other' ;;
    esac
  else
    printf '%s\n' "$text" | python3 -c "
import sys, yaml
d = yaml.safe_load(sys.stdin) or {}
if not isinstance(d, dict) or '${key}' not in d:
    print('missing'); sys.exit(0)
v = d['${key}']
if v is None: print('null')
elif isinstance(v, str): print('string')
elif isinstance(v, list): print('list')
elif isinstance(v, dict): print('map')
elif isinstance(v, bool): print('bool')
elif isinstance(v, int): print('int')
elif isinstance(v, float): print('float')
else: print('other')
" 2>/dev/null
  fi
}

# yaml_string <yaml-text> <key> → prints the value as a string, or empty if missing.
yaml_string() {
  local text=$1; local key=$2
  if [ "$YAML_PARSER" = "yq" ]; then
    printf '%s\n' "$text" | yq eval ".${key} // \"\"" - 2>/dev/null || printf ''
  else
    printf '%s\n' "$text" | python3 -c "
import sys, yaml
d = yaml.safe_load(sys.stdin) or {}
v = d.get('${key}', '') if isinstance(d, dict) else ''
print('' if v is None else str(v))
" 2>/dev/null
  fi
}

# yaml_list_length <yaml-text> <key> → prints integer count, or -1 if the key
# exists but is not a list, or -2 if missing entirely.
yaml_list_length() {
  local text=$1; local key=$2
  local t
  t=$(yaml_type "$text" "$key")
  case "$t" in
    missing)  printf '%s' '-2'; return ;;
    list)     ;;
    *)        printf '%s' '-1'; return ;;
  esac
  if [ "$YAML_PARSER" = "yq" ]; then
    printf '%s\n' "$text" | yq eval ".${key} | length" - 2>/dev/null || printf '0'
  else
    printf '%s\n' "$text" | python3 -c "
import sys, yaml
d = yaml.safe_load(sys.stdin) or {}
v = d.get('${key}', [])
print(len(v) if isinstance(v, list) else 0)
" 2>/dev/null
  fi
}

# yaml_list_items <yaml-text> <key> → prints each list element on its own line.
yaml_list_items() {
  local text=$1; local key=$2
  if [ "$YAML_PARSER" = "yq" ]; then
    printf '%s\n' "$text" | yq eval ".${key}[]" - 2>/dev/null || true
  else
    printf '%s\n' "$text" | python3 -c "
import sys, yaml
d = yaml.safe_load(sys.stdin) or {}
v = d.get('${key}', [])
if isinstance(v, list):
    for item in v:
        print(item)
" 2>/dev/null || true
  fi
}

# validate_synthesis_schema_inline <rel> <meta-yaml-text> <errors-array-name>
#
# D-42, D-48 synthesizer schema rules (R-CHAIR-*). Invoked for tier: chair.
# Appends errors to the named bash array by reference (local -n).
validate_synthesis_schema_inline() {
  local rel=$1
  local meta=$2
  local -n err_ref=$3

  # R-CHAIR-1: required_sections present + non-empty list.
  local rs_len
  rs_len=$(yaml_list_length "$meta" 'required_sections')
  case "$rs_len" in
    -2) err_ref+=("$rel: [R-CHAIR-1] required_sections missing (required non-empty list per D-48)") ;;
    -1) err_ref+=("$rel: [R-CHAIR-1] required_sections has wrong type (expected list)") ;;
    0)  err_ref+=("$rel: [R-CHAIR-1] required_sections is empty (required non-empty list per D-48)") ;;
    *)  ;;
  esac

  # R-CHAIR-2: banned_tokens present + non-empty list (CHAIR-04 enforcement surface).
  local bt_len
  bt_len=$(yaml_list_length "$meta" 'banned_tokens')
  case "$bt_len" in
    -2) err_ref+=("$rel: [R-CHAIR-2] banned_tokens missing (required non-empty list per D-48 / CHAIR-04)") ;;
    -1) err_ref+=("$rel: [R-CHAIR-2] banned_tokens has wrong type (expected list)") ;;
    0)  err_ref+=("$rel: [R-CHAIR-2] banned_tokens is empty (required non-empty list per D-48 / CHAIR-04)") ;;
    *)  ;;
  esac

  # R-CHAIR-3: min_contradiction_anchors present AND equals 2 (D-48 fixed value).
  local mca_type mca
  mca_type=$(yaml_type "$meta" 'min_contradiction_anchors')
  case "$mca_type" in
    missing|null)
      err_ref+=("$rel: [R-CHAIR-3] min_contradiction_anchors missing (required int == 2 per D-48)")
      ;;
    int)
      mca=$(yaml_string "$meta" 'min_contradiction_anchors')
      if [ "$mca" != "2" ]; then
        err_ref+=("$rel: [R-CHAIR-3] min_contradiction_anchors is ${mca}; D-48 fixes this at 2")
      fi
      ;;
    *)
      err_ref+=("$rel: [R-CHAIR-3] min_contradiction_anchors has wrong type (expected int, got ${mca_type})")
      ;;
  esac

  # R-CHAIR-4: max_blockers present AND equals 3 (D-48 / D-34 fixed value).
  local mb_type mb
  mb_type=$(yaml_type "$meta" 'max_blockers')
  case "$mb_type" in
    missing|null)
      err_ref+=("$rel: [R-CHAIR-4] max_blockers missing (required int == 3 per D-48 / D-34)")
      ;;
    int)
      mb=$(yaml_string "$meta" 'max_blockers')
      if [ "$mb" != "3" ]; then
        err_ref+=("$rel: [R-CHAIR-4] max_blockers is ${mb}; D-48 / D-34 fix this at 3")
      fi
      ;;
    *)
      err_ref+=("$rel: [R-CHAIR-4] max_blockers has wrong type (expected int, got ${mb_type})")
      ;;
  esac
}

# -----------------------------------------------------------------------------
# 5. Per-file validation
# -----------------------------------------------------------------------------

# validate_one <file> → echoes hard-fail lines to stdout and soft-warn lines
# to stderr. Returns 0 if no hard failures, 1 otherwise.
validate_one() {
  local file=$1
  local rel="$file"
  local errors=()
  local fm
  local meta
  local body

  # R1: frontmatter present + parseable YAML.
  if ! fm=$(extract_frontmatter "$file" 2>/dev/null); then
    errors+=("$rel: [R1] frontmatter missing or no closing --- fence")
    for e in "${errors[@]}"; do printf '%s\n' "$e"; done
    return 1
  fi

  if ! yaml_parse_check "$fm"; then
    errors+=("$rel: [R1] frontmatter is not valid YAML")
    for e in "${errors[@]}"; do printf '%s\n' "$e"; done
    return 1
  fi

  body=$(extract_body "$file")

  # Sidecar resolution — Bedrock rejects custom keys in agent frontmatter,
  # so tier/primary_concern/blind_spots/characteristic_objections/banned_phrases
  # live in persona-metadata/<persona>.yml. Resolution order matches
  # bin/dc-validate-scorecard.sh:
  #   1. persona-metadata/<basename>.yml (preferred — sidecar pattern)
  #   2. agent frontmatter (legacy path — pre-sidecar personas)
  local persona_slug sidecar
  persona_slug=$(basename "$file" .md)
  sidecar="${REPO_ROOT}/persona-metadata/${persona_slug}.yml"
  if [ -f "$sidecar" ]; then
    meta=$(cat "$sidecar")
    if ! yaml_parse_check "$meta"; then
      errors+=("$rel: [R1] persona-metadata sidecar is not valid YAML: $sidecar")
      for e in "${errors[@]}"; do printf '%s\n' "$e"; done
      return 1
    fi
  else
    # Legacy: custom fields live in agent frontmatter alongside name/description/model.
    meta="$fm"
  fi

  # R2: tier present AND ∈ {core, bench, chair}.
  local tier tier_type
  tier_type=$(yaml_type "$meta" 'tier')
  if [ "$tier_type" = "missing" ] || [ "$tier_type" = "null" ]; then
    errors+=("$rel: [R2] tier missing (required; must be one of core|bench|chair)")
    tier=""
  else
    tier=$(yaml_string "$meta" 'tier')
    case "$tier" in
      core|bench|chair) ;;
      *) errors+=("$rel: [R2] tier '${tier}' is not one of core|bench|chair") ;;
    esac
  fi

  # R3-R6 apply to CRITIC personas (tier: core, tier: bench).
  # tier: chair personas are synthesizers — validated by validate_synthesis_schema_inline instead.
  local bp_len=-2    # declared in outer scope so W1 guard below can reference it
  case "$tier" in
    core|bench)
      # R3: primary_concern present + non-empty string.
      local pc_type pc
      pc_type=$(yaml_type "$meta" 'primary_concern')
      case "$pc_type" in
        missing|null)
          errors+=("$rel: [R3] primary_concern missing (required non-empty string)")
          ;;
        string)
          pc=$(yaml_string "$meta" 'primary_concern')
          local pc_stripped
          pc_stripped=$(printf '%s' "$pc" | awk '{$1=$1;print}')
          if [ -z "$pc_stripped" ]; then
            errors+=("$rel: [R3] primary_concern is empty (required non-empty string)")
          fi
          ;;
        *)
          errors+=("$rel: [R3] primary_concern has wrong type (expected string, got ${pc_type})")
          ;;
      esac

      # R4: blind_spots present + non-empty list.
      local bs_len
      bs_len=$(yaml_list_length "$meta" 'blind_spots')
      case "$bs_len" in
        -2) errors+=("$rel: [R4] blind_spots missing (required non-empty list)") ;;
        -1) errors+=("$rel: [R4] blind_spots has wrong type (expected list)") ;;
        0)  errors+=("$rel: [R4] blind_spots is empty (required non-empty list)") ;;
        *) ;;
      esac

      # R5: characteristic_objections list, length >= 3.
      local co_len
      co_len=$(yaml_list_length "$meta" 'characteristic_objections')
      case "$co_len" in
        -2) errors+=("$rel: [R5] characteristic_objections missing (required list, length >= 3)") ;;
        -1) errors+=("$rel: [R5] characteristic_objections has wrong type (expected list)") ;;
        *)
          if [ "$co_len" -lt 3 ]; then
            errors+=("$rel: [R5] characteristic_objections has ${co_len} entries; rule requires >= 3")
          fi
          ;;
      esac

      # R6: banned_phrases list, non-empty.
      bp_len=$(yaml_list_length "$meta" 'banned_phrases')
      case "$bp_len" in
        -2) errors+=("$rel: [R6] banned_phrases missing (required non-empty list)") ;;
        -1) errors+=("$rel: [R6] banned_phrases has wrong type (expected list)") ;;
        0)  errors+=("$rel: [R6] banned_phrases is empty (required non-empty list)") ;;
        *) ;;
      esac
      ;;
    chair)
      # Synthesizer schema (D-42 reuse-of-tier path). Inline so errors
      # accumulate in the same `errors` array other rules use.
      validate_synthesis_schema_inline "$rel" "$meta" errors
      ;;
  esac

  # R7 / R8: tier-conditional triggers handling.
  local tr_type tr_len
  tr_type=$(yaml_type "$meta" 'triggers')

  if [ "$tier" = "bench" ]; then
    # R7: triggers must be a non-empty list AND every ID in signals registry.
    case "$tr_type" in
      missing|null)
        errors+=("$rel: [R7] bench tier requires non-empty triggers list (was ${tr_type})")
        ;;
      list)
        tr_len=$(yaml_list_length "$meta" 'triggers')
        if [ "$tr_len" -eq 0 ]; then
          errors+=("$rel: [R7] bench tier requires non-empty triggers list (was empty)")
        else
          # Validate each ID against signal registry.
          local id
          while IFS= read -r id; do
            [ -z "$id" ] && continue
            if ! printf '%s\n' "$VALID_SIGNAL_IDS" | grep -Fxq -- "$id"; then
              errors+=("$rel: [R7] triggers references undeclared signal ID '${id}' (not a key in ${SIGNALS_PATH})")
            fi
          done < <(yaml_list_items "$meta" 'triggers')
        fi
        ;;
      *)
        errors+=("$rel: [R7] triggers has wrong type (expected list, got ${tr_type})")
        ;;
    esac
  elif [ "$tier" = "core" ] || [ "$tier" = "chair" ]; then
    # R8: triggers must be empty or absent.
    case "$tr_type" in
      missing|null) ;;
      list)
        tr_len=$(yaml_list_length "$meta" 'triggers')
        if [ "$tr_len" -gt 0 ]; then
          errors+=("$rel: [R8] tier '${tier}' must have empty or absent triggers (had ${tr_len} entries)")
        fi
        ;;
      *)
        errors+=("$rel: [R8] triggers has wrong type (expected list or absent, got ${tr_type})")
        ;;
    esac
  fi

  # -- Soft warnings (never affect exit code) --

  # W1: only meaningful for critics that have banned_phrases. Skip for chair.
  if [ "$tier" != "chair" ] && [ "${bp_len:-0}" -gt 0 ]; then
    local bp_items missing_bans=()
    bp_items=$(yaml_list_items "$meta" 'banned_phrases' | tr '[:upper:]' '[:lower:]')
    for needle in 'consider' 'think about' 'be aware of'; do
      if ! printf '%s\n' "$bp_items" | grep -Fxq -- "$needle"; then
        missing_bans+=("$needle")
      fi
    done
    if [ ${#missing_bans[@]} -gt 0 ]; then
      warn "$rel: banned_phrases is missing recommended baseline entries: ${missing_bans[*]} (W1 — advisory)"
    fi
  fi

  # W2: body lacks `## Examples` H2. Chair's body has `## Complete worked example` instead.
  if [ "$tier" != "chair" ] && ! printf '%s\n' "$body" | grep -qE '^##[[:space:]]+Examples[[:space:]]*$'; then
    warn "$rel: body lacks '## Examples' section (W2 — per skills/persona-voice/SKILL.md worked-example discipline)"
  fi

  # W3: forbidden frontmatter keys (stripped by Claude Code).
  local forbidden
  for forbidden in 'hooks' 'mcpServers' 'permissionMode'; do
    if yaml_has_key "$fm" "$forbidden"; then
      warn "$rel: frontmatter contains '${forbidden}' which Claude Code strips for plugin-shipped agents (W3)"
    fi
  done

  # Emit errors (if any) and return appropriate status.
  if [ ${#errors[@]} -gt 0 ]; then
    for e in "${errors[@]}"; do printf '%s\n' "$e"; done
    return 1
  fi
  return 0
}

# -----------------------------------------------------------------------------
# 6. Main
# -----------------------------------------------------------------------------

# Build file list.
FILES=()

if [ -n "$TARGET_FILE" ]; then
  if [ ! -f "$TARGET_FILE" ]; then
    err "file not found: $TARGET_FILE"
    exit 2
  fi
  FILES=("$TARGET_FILE")
else
  # Default: validate every agents/*.md except README.md / .gitkeep.
  # Use `find` with -print0 for robustness; exclude README.md by name.
  if [ -d "agents" ]; then
    while IFS= read -r -d '' f; do
      base=$(basename "$f")
      case "$base" in
        README.md|.gitkeep) continue ;;
      esac
      FILES+=("$f")
    done < <(find agents -maxdepth 1 -type f -name '*.md' -print0 2>/dev/null)
  fi
fi

if [ ${#FILES[@]} -eq 0 ]; then
  printf 'validate-personas: no agents to validate\n'
  exit 0
fi

# Validate each file, collecting exit status.
OVERALL_STATUS=0
for f in "${FILES[@]}"; do
  if ! validate_one "$f"; then
    OVERALL_STATUS=1
  fi
done

exit "$OVERALL_STATUS"
