#!/usr/bin/env bash
# dc-validate-scorecard.sh <persona> <run-dir>
#
# Conductor-side post-processor for the devils-council review engine.
#
# Reads <run-dir>/<persona>-draft.md (produced by a persona subagent),
# validates each finding against:
#   (a) evidence is a verbatim substring of <run-dir>/INPUT.md after
#       normalization (strip leading line-number prefixes, collapse
#       runs of whitespace to single spaces). Minimum length 8 chars
#       post-normalization.
#   (b) banned-phrase check on claim + ask fields ONLY (never evidence —
#       Pitfall 3 guard). Case-insensitive word-boundary match against
#       the persona's `banned_phrases` list.
#
# Drops failed findings; records them in:
#   - <run-dir>/<persona>.md frontmatter `dropped_findings:` list
#   - <run-dir>/MANIFEST.json `validation[]` array (additive; new personas
#     append rather than clobber)
#
# Writes <run-dir>/<persona>.md and deletes <run-dir>/<persona>-draft.md.
#
# SINGLE-PASS by design — ENGN-07 + D-15. Never re-invokes the persona.
# No loop. No retry. If all findings drop, exit 0 with empty findings list.
#
# Exit codes:
#   0 — draft was structurally parseable, final file written (even if 0 kept)
#   1 — malformed input (missing files, unparseable YAML, persona not found,
#       persona banned_phrases list missing)
#   2 — usage error (wrong arg count)
#
# Normalization policy (documented for Pitfall 2 + reviewer sanity):
#   both evidence and INPUT.md are piped through:
#     1. strip leading `[whitespace][digits]:[whitespace]` line-number prefix
#     2. `tr '[:space:]' ' '`  — convert all whitespace (incl. newlines) to space
#     3. `tr -s ' '`           — collapse runs of spaces to one
#     4. trim leading/trailing spaces
#   Case is NOT lowered (evidence should match INPUT.md byte-identically
#   modulo whitespace).

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

err()  { printf 'dc-validate-scorecard: ERROR: %s\n' "$*" >&2; }
warn() { printf 'dc-validate-scorecard: WARN: %s\n'  "$*" >&2; }

usage() {
  cat >&2 <<'USAGE'
dc-validate-scorecard.sh <persona> <run-dir>

  <persona>   persona name (matches agents/<persona>.md and
              <run-dir>/<persona>-draft.md)
  <run-dir>   run directory created by dc-prep.sh

Exit codes:
  0 — draft parseable, final file written (even with zero kept findings)
  1 — malformed input (missing files, unparseable YAML, persona not found,
      banned_phrases list missing)
  2 — usage error
USAGE
}

# -----------------------------------------------------------------------------
# 1. Argument parse
# -----------------------------------------------------------------------------

if [ $# -ne 2 ]; then
  usage
  exit 2
fi

PERSONA="$1"
RUN_DIR="$2"

DRAFT="$RUN_DIR/${PERSONA}-draft.md"
FINAL="$RUN_DIR/${PERSONA}.md"
INPUT_MD="$RUN_DIR/INPUT.md"
MANIFEST="$RUN_DIR/MANIFEST.json"

# Persona file: prefer ${REPO_ROOT}/agents/${PERSONA}.md so this script works
# from any cwd; fall back to relative path for callers that cd into repo root.
if [ -f "${REPO_ROOT}/agents/${PERSONA}.md" ]; then
  PERSONA_FILE="${REPO_ROOT}/agents/${PERSONA}.md"
else
  PERSONA_FILE="agents/${PERSONA}.md"
fi

# -----------------------------------------------------------------------------
# 2. Preconditions
# -----------------------------------------------------------------------------

[ -d "$RUN_DIR" ]      || { err "run dir not found: $RUN_DIR"; exit 1; }
[ -f "$DRAFT" ]        || { err "draft not found: $DRAFT"; exit 1; }
[ -f "$INPUT_MD" ]     || { err "INPUT.md not found: $INPUT_MD"; exit 1; }
[ -f "$MANIFEST" ]     || { err "MANIFEST.json not found: $MANIFEST"; exit 1; }
[ -f "$PERSONA_FILE" ] || { err "persona file not found: $PERSONA_FILE"; exit 1; }

# -----------------------------------------------------------------------------
# 3. Parser detection (mirror validate-personas.sh — prefer mikefarah/yq,
#    fall back to python3+PyYAML)
# -----------------------------------------------------------------------------

YAML_PARSER=""
if command -v yq >/dev/null 2>&1; then
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
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  err "jq is required but not installed. brew install jq / apt-get install jq"
  exit 1
fi

# For the frontmatter REWRITE step (filtering findings + adding
# dropped_findings), we require python3+PyYAML unconditionally — the logic is
# too subtle to express safely in yq+jq. If yq was the only parser available,
# we still require python3+PyYAML here; fall back cleanly if missing.
if ! command -v python3 >/dev/null 2>&1 \
     || ! python3 -c 'import yaml' >/dev/null 2>&1; then
  err "python3 with PyYAML is required for frontmatter rewrite."
  err "Install: pip3 install pyyaml (or use a virtualenv)"
  exit 1
fi

# -----------------------------------------------------------------------------
# 4. YAML helpers (mirror validate-personas.sh pattern)
# -----------------------------------------------------------------------------

# extract_frontmatter <file> → prints YAML block between first pair of ---
# fences. Exits non-zero if no fenced frontmatter found.
extract_frontmatter() {
  local file=$1
  awk '
    BEGIN { state = 0 }
    {
      if (state == 0) {
        if ($0 == "---") { state = 1; next }
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

# -----------------------------------------------------------------------------
# 5. Load persona banned_phrases
#
# Resolution order (Claude Code plugin compat — Bedrock rejects unknown agent
# frontmatter keys, so persona metadata lives in a sidecar .meta.yml):
#   1. agents/<persona>.meta.yml (preferred — keeps agent frontmatter schema-clean)
#   2. agents/<persona>.md frontmatter (legacy — still supported for non-plugin use)
# -----------------------------------------------------------------------------

PERSONA_META="${PERSONA_FILE%.md}.meta.yml"

# Temp dir for all ephemeral artifacts; clean on exit.
TMPDIR_RUN=$(mktemp -d -t dc-validate.XXXXXX)
trap 'rm -rf "$TMPDIR_RUN"' EXIT

BANNED_PHRASES_FILE="$TMPDIR_RUN/banned-phrases"

if [ -f "$PERSONA_META" ]; then
  # Sidecar path (preferred)
  PERSONA_FM=$(cat "$PERSONA_META")
  if ! printf '%s\n' "$PERSONA_FM" \
       | python3 -c 'import sys, yaml; yaml.safe_load(sys.stdin)' >/dev/null 2>&1; then
    err "persona sidecar is not valid YAML: $PERSONA_META"
    exit 1
  fi
else
  # Legacy path — agent .md frontmatter
  PERSONA_FM=$(extract_frontmatter "$PERSONA_FILE" 2>/dev/null) || {
    err "persona frontmatter missing or no closing --- fence: $PERSONA_FILE"
    exit 1
  }

  if ! printf '%s\n' "$PERSONA_FM" \
       | python3 -c 'import sys, yaml; yaml.safe_load(sys.stdin)' >/dev/null 2>&1; then
    err "persona frontmatter is not valid YAML: $PERSONA_FILE"
    exit 1
  fi
fi

yaml_list_items "$PERSONA_FM" 'banned_phrases' > "$BANNED_PHRASES_FILE" || true

if [ ! -s "$BANNED_PHRASES_FILE" ]; then
  err "persona '$PERSONA' has empty or missing banned_phrases list (checked $PERSONA_META and $PERSONA_FILE frontmatter)"
  exit 1
fi

# -----------------------------------------------------------------------------
# 6. Load draft frontmatter and normalize INPUT.md
# -----------------------------------------------------------------------------

DRAFT_FM=$(extract_frontmatter "$DRAFT" 2>/dev/null) || {
  err "draft frontmatter missing or no closing --- fence: $DRAFT"
  exit 1
}

if ! printf '%s\n' "$DRAFT_FM" \
     | python3 -c 'import sys, yaml; yaml.safe_load(sys.stdin)' >/dev/null 2>&1; then
  err "draft frontmatter is not valid YAML: $DRAFT"
  exit 1
fi

# Normalize INPUT.md: strip line-prefix anchors on each line, convert all
# whitespace to spaces, collapse runs. Resulting file is one long line-ish.
NORMALIZED_INPUT="$TMPDIR_RUN/input.normalized"
sed -E 's/^[[:space:]]*[0-9]+:[[:space:]]*//' "$INPUT_MD" \
  | tr '[:space:]' ' ' \
  | tr -s ' ' \
  | sed -e 's/^ *//' -e 's/ *$//' \
  > "$NORMALIZED_INPUT"

# -----------------------------------------------------------------------------
# 7. Finding-by-finding validation loop (Python for clarity + correctness)
# -----------------------------------------------------------------------------
#
# We emit, for each finding, one of:
#   KEEP <index>
#   DROP <index> <reason> [phrase]
#
# Python reads the draft frontmatter + banned-phrases file + normalized
# INPUT.md and makes the decisions. We keep the normalization in bash above
# (it's simple enough) and pass NORMALIZED_INPUT via env to python.

export NORMALIZED_INPUT BANNED_PHRASES_FILE

DECISIONS_FILE="$TMPDIR_RUN/decisions"
DRAFT_FM_FILE="$TMPDIR_RUN/draft-fm.yaml"
printf '%s\n' "$DRAFT_FM" > "$DRAFT_FM_FILE"

python3 - "$DRAFT_FM_FILE" "$DECISIONS_FILE" <<'PYEOF'
import os
import re
import sys
import yaml

draft_fm_path = sys.argv[1]
decisions_path = sys.argv[2]
norm_input_path = os.environ['NORMALIZED_INPUT']
banned_phrases_path = os.environ['BANNED_PHRASES_FILE']

with open(draft_fm_path, 'r', encoding='utf-8') as f:
    fm = yaml.safe_load(f) or {}

findings = fm.get('findings') or []

with open(norm_input_path, 'r', encoding='utf-8') as f:
    normalized_input = f.read()

with open(banned_phrases_path, 'r', encoding='utf-8') as f:
    banned_phrases = [ln.strip() for ln in f if ln.strip()]


LINE_PREFIX_RE = re.compile(r'^[ \t]*\d+:[ \t]*', re.MULTILINE)
WS_RE = re.compile(r'\s+')


def normalize(text: str) -> str:
    if text is None:
        return ''
    stripped = LINE_PREFIX_RE.sub('', str(text))
    collapsed = WS_RE.sub(' ', stripped).strip()
    return collapsed


def banned_hit(text: str, phrase: str) -> bool:
    """Case-insensitive word-boundary match of phrase inside text.
    Word boundary = non-alnum-underscore on each side (or string edge).
    """
    if not text or not phrase:
        return False
    pat = re.compile(
        r'(?:^|[^A-Za-z0-9_])' + re.escape(phrase) + r'(?:[^A-Za-z0-9_]|$)',
        re.IGNORECASE,
    )
    return bool(pat.search(text))


decisions = []
for idx, finding in enumerate(findings):
    fid = finding.get('id') or f'finding-{idx}'
    evidence = finding.get('evidence', '')
    claim = finding.get('claim', '') or ''
    ask = finding.get('ask', '') or ''

    norm_evi = normalize(evidence)

    # Check 1: minimum length after normalization.
    if len(norm_evi) < 8:
        decisions.append(('DROP', idx, fid, 'evidence_too_short', ''))
        continue

    # Check 2: substring of normalized INPUT.md.
    if norm_evi not in normalized_input:
        decisions.append(('DROP', idx, fid, 'evidence_not_verbatim', ''))
        continue

    # Check 3: banned phrase in claim OR ask (never evidence — Pitfall 3).
    matched = ''
    for phrase in banned_phrases:
        if banned_hit(claim, phrase) or banned_hit(ask, phrase):
            matched = phrase
            break

    if matched:
        decisions.append(('DROP', idx, fid, 'banned_phrase_detected', matched))
        continue

    decisions.append(('KEEP', idx, fid, '', ''))

# Emit decisions as TSV: kind<TAB>idx<TAB>id<TAB>reason<TAB>phrase
with open(decisions_path, 'w', encoding='utf-8') as f:
    for kind, idx, fid, reason, phrase in decisions:
        f.write(f"{kind}\t{idx}\t{fid}\t{reason}\t{phrase}\n")
PYEOF

# -----------------------------------------------------------------------------
# 8. Parse decisions → kept indices + drops JSON
# -----------------------------------------------------------------------------

KEPT_INDICES=()
DROPS_JSON='[]'
KEPT_COUNT=0
DROPPED_COUNT=0

while IFS=$'\t' read -r KIND IDX FID REASON PHRASE; do
  [ -z "$KIND" ] && continue
  case "$KIND" in
    KEEP)
      KEPT_INDICES+=("$IDX")
      KEPT_COUNT=$((KEPT_COUNT + 1))
      ;;
    DROP)
      if [ -n "$PHRASE" ]; then
        DROPS_JSON=$(printf '%s' "$DROPS_JSON" \
          | jq --arg id "$FID" --arg reason "$REASON" --arg phrase "$PHRASE" \
              '. + [{id: $id, reason: $reason, phrase: $phrase}]')
      else
        DROPS_JSON=$(printf '%s' "$DROPS_JSON" \
          | jq --arg id "$FID" --arg reason "$REASON" \
              '. + [{id: $id, reason: $reason, phrase: null}]')
      fi
      DROPPED_COUNT=$((DROPPED_COUNT + 1))
      ;;
  esac
done < "$DECISIONS_FILE"

# KEPT_INDICES as JSON array for python rewrite.
if [ ${#KEPT_INDICES[@]} -eq 0 ]; then
  KEPT_IDX_JSON='[]'
else
  KEPT_IDX_JSON=$(printf '%s\n' "${KEPT_INDICES[@]}" | jq -R . | jq -s 'map(tonumber)')
fi

# -----------------------------------------------------------------------------
# 9. Build final scorecard frontmatter (python3 + yaml.safe_dump)
# -----------------------------------------------------------------------------

FINAL_FM_FILE="$TMPDIR_RUN/final-fm.yaml"
export KEPT_IDX_JSON DROPS_JSON

python3 - "$DRAFT_FM_FILE" "$FINAL_FM_FILE" <<'PYEOF'
import json
import os
import sys
import yaml

draft_path = sys.argv[1]
final_path = sys.argv[2]

with open(draft_path, 'r', encoding='utf-8') as f:
    fm = yaml.safe_load(f) or {}

keep = json.loads(os.environ['KEPT_IDX_JSON'])
drops = json.loads(os.environ['DROPS_JSON'])

findings = fm.get('findings') or []
kept = [findings[i] for i in keep if 0 <= i < len(findings)]

fm['findings'] = kept
fm['dropped_findings'] = drops

with open(final_path, 'w', encoding='utf-8') as f:
    yaml.safe_dump(fm, f, sort_keys=False, allow_unicode=True, width=200,
                   default_flow_style=False)
PYEOF

# -----------------------------------------------------------------------------
# 10. Compose final scorecard (frontmatter + body) atomically, delete draft
# -----------------------------------------------------------------------------

BODY_FILE="$TMPDIR_RUN/body"
extract_body "$DRAFT" > "$BODY_FILE"

FINAL_TMP="$TMPDIR_RUN/final.md"
{
  printf -- '---\n'
  cat "$FINAL_FM_FILE"
  # yaml.safe_dump already terminates with a newline; no extra needed.
  printf -- '---\n'
  cat "$BODY_FILE"
} > "$FINAL_TMP"

# Atomic swap: move final into place, then delete draft only on success.
mv "$FINAL_TMP" "$FINAL"
rm -f "$DRAFT"

# -----------------------------------------------------------------------------
# 11. Update MANIFEST.json — additive (preserve existing fields + arrays)
# -----------------------------------------------------------------------------

VALIDATION_ENTRY=$(jq -n \
  --arg persona "$PERSONA" \
  --argjson kept "$KEPT_COUNT" \
  --argjson dropped "$DROPPED_COUNT" \
  --argjson drops "$DROPS_JSON" \
  '{persona: $persona, findings_kept: $kept, findings_dropped: $dropped, drop_reasons: $drops}')

MANIFEST_TMP="$TMPDIR_RUN/manifest.json"
jq --argjson v "$VALIDATION_ENTRY" --arg persona "$PERSONA" '
  .validation        = ((.validation        // []) + [$v])
  | .findings_kept    = ((.findings_kept    // 0) + $v.findings_kept)
  | .findings_dropped = ((.findings_dropped // 0) + $v.findings_dropped)
  | .personas_run     = (
      # ENGN-08: personas_run[] entries are {name, trigger_reason} OBJECTS,
      # not bare strings. Conductor (Plan 04) is expected to append the
      # entry BEFORE calling the validator; if it did not, fall back to a
      # stub entry so downstream tooling still sees this persona ran.
      ((.personas_run // []) as $existing
       | if any($existing[]?; (type == "object") and (.name == $persona))
         then $existing
         else $existing + [{name: $persona, trigger_reason: "core:always-on"}]
         end)
    )
' "$MANIFEST" > "$MANIFEST_TMP" && mv "$MANIFEST_TMP" "$MANIFEST"

# -----------------------------------------------------------------------------
# 12. Summary line for conductor (stderr — stdout stays quiet for CI pipes)
# -----------------------------------------------------------------------------

printf 'dc-validate-scorecard: %s — %d kept, %d dropped\n' \
  "$PERSONA" "$KEPT_COUNT" "$DROPPED_COUNT" >&2

exit 0
