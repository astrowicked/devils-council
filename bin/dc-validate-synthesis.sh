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

# --- 5. per-check validation (embedded python for clarity + correctness) ---
ERRORS_TSV="$TMPDIR_RUN/errors.tsv"
STATS_FILE="$TMPDIR_RUN/stats"

python3 - "$DRAFT" "$SIDECAR" "$ERRORS_TSV" "$STATS_FILE" <<'PYEOF'
import json, os, re, sys, yaml

draft_path, sidecar_path, errors_path, stats_path = sys.argv[1:5]

# Inputs from bash ---------------------------------------------------------
with open(draft_path,   'r', encoding='utf-8') as f:
    draft_text = f.read()
with open(sidecar_path, 'r', encoding='utf-8') as f:
    sidecar = yaml.safe_load(f) or {}
with open(os.environ['STAMPED_IDS_FILE'], 'r', encoding='utf-8') as f:
    stamped_ids = {ln.strip() for ln in f if ln.strip()}
with open(os.environ['CANDIDATE_TARGETS_FILE'], 'r', encoding='utf-8') as f:
    candidate_targets = {ln.strip() for ln in f if ln.strip()}
survivor_count = int(os.environ.get('SURVIVOR_COUNT', '0') or '0')

required_sections      = sidecar.get('required_sections', []) or []
req_sections_no_surv   = sidecar.get('required_sections_no_survivors', []) or []
banned_tokens          = sidecar.get('banned_tokens', []) or []
min_anchors            = int(sidecar.get('min_contradiction_anchors', 2))
max_blockers           = int(sidecar.get('max_blockers', 3))

errors = []  # each: (check, detail)

# ID resolution table: stamped id -> (persona, target, severity) — built from MANIFEST.
# We need target lookup by id for the Top-3 candidate-set check.
MANIFEST_PATH = os.path.join(os.path.dirname(draft_path), 'MANIFEST.json')
with open(MANIFEST_PATH, 'r', encoding='utf-8') as f:
    manifest = json.load(f)
id_to_finding = {}
for pr in (manifest.get('personas_run') or []):
    if not isinstance(pr, dict):
        continue
    for fnd in (pr.get('findings') or []):
        fid = (fnd or {}).get('id')
        if fid:
            id_to_finding[fid] = {
                'persona':  pr.get('name'),
                'target':   fnd.get('target'),
                'severity': fnd.get('severity'),
            }

# Section parser: dict of "heading text" -> body string (between this heading and next H2).
# D-39 section order matters for readability but the validator checks presence, not order.
SECTION_H2 = re.compile(r'^##\s+(.+?)\s*$', re.MULTILINE)
sections = {}
matches = list(SECTION_H2.finditer(draft_text))
for i, m in enumerate(matches):
    heading = m.group(1).strip()
    start = m.end()
    end = matches[i+1].start() if i+1 < len(matches) else len(draft_text)
    sections[heading] = draft_text[start:end]

# -----------------------------------------------------------------------
# Check 1: required sections present (D-43 survivor branching).
# -----------------------------------------------------------------------
if survivor_count == 0:
    # Zero-survivors edge case (D-43): only required_sections_no_survivors.
    wanted = req_sections_no_surv
    # Also require the "No synthesis possible" sentinel anywhere in body.
    if 'No synthesis possible' not in draft_text:
        errors.append(('required_sentinel_missing',
                       'zero-survivors run must include the sentinel line "No synthesis possible"'))
else:
    wanted = required_sections

for s in wanted:
    if s not in sections:
        errors.append(('required_section_missing', s))

# -----------------------------------------------------------------------
# Check 2: banned_tokens scan (case-insensitive substring).
# -----------------------------------------------------------------------
lower = draft_text.lower()
for tok in banned_tokens:
    if str(tok).lower() in lower:
        errors.append(('banned_token', str(tok)))

# -----------------------------------------------------------------------
# Check 3: contradictions — each entry cites >= min_anchors ids, all resolve.
# We treat each "- **" bullet or each blank-line-separated block inside the
# Contradictions section as one "entry". An id is any `(<slug>-<8hex>)` paren
# citation.
# D-44: if body matches the "No contradictions surfaced" sentinel, skip per-entry check.
# -----------------------------------------------------------------------
ID_RE = re.compile(r'\(([a-z][a-z0-9-]*-[0-9a-f]{8})\)')
contradictions_body = sections.get('Contradictions', '')
contradiction_count = 0
no_contradictions_sentinel = 'No contradictions surfaced' in contradictions_body
if survivor_count > 0 and 'Contradictions' in sections and not no_contradictions_sentinel:
    # Split entries by blank lines. Each paragraph is one entry.
    raw_entries = [p.strip() for p in re.split(r'\n[ \t]*\n', contradictions_body) if p.strip()]
    for entry in raw_entries:
        cited = ID_RE.findall(entry)
        if len(cited) < min_anchors:
            errors.append(('contradiction_anchors_insufficient',
                           f'entry cites {len(cited)} id(s); sidecar requires >= {min_anchors}'))
            continue
        unresolvable = [cid for cid in cited if cid not in stamped_ids]
        if unresolvable:
            errors.append(('contradiction_id_not_resolvable',
                           ','.join(unresolvable)))
        contradiction_count += 1

# -----------------------------------------------------------------------
# Check 4: Top-3 — each entry cites >= 1 resolvable id AND target in candidate set.
# Zero-blocker sentinel short-circuits the check (D-35).
# -----------------------------------------------------------------------
top3_body = sections.get('Top-3 Blocking Concerns', '')
top3_count = 0
zero_blocker_sentinel = 'No blocking concerns raised — candidate set is empty' in top3_body
if survivor_count > 0 and 'Top-3 Blocking Concerns' in sections and not zero_blocker_sentinel:
    # Numbered or bulleted entries; split on leading "- " or "1." "2." "3." line starts.
    entries = [p.strip() for p in re.split(r'\n[ \t]*\n', top3_body) if p.strip()]
    if len(entries) > max_blockers:
        errors.append(('top3_exceeds_max',
                       f'{len(entries)} entries; max_blockers = {max_blockers}'))
    for entry in entries:
        cited = ID_RE.findall(entry)
        if len(cited) < 1:
            errors.append(('top3_anchor_missing',
                           'entry cites zero finding ids'))
            continue
        resolvable = [cid for cid in cited if cid in stamped_ids]
        if not resolvable:
            errors.append(('top3_id_not_resolvable',
                           ','.join(cited)))
            continue
        # Target membership check against D-34 candidate set.
        off_candidate = []
        for cid in resolvable:
            tgt = id_to_finding.get(cid, {}).get('target')
            if tgt is not None and tgt not in candidate_targets:
                off_candidate.append(f'{cid}->{tgt}')
        if off_candidate:
            errors.append(('top3_off_candidate_set',
                           ','.join(off_candidate)))
        # -------------------------------------------------------------
        # TD-05: top3_composite_target strictness check (D-05, D-06, D-07).
        # Reject Top-3 entries whose cited finding target matches composite
        # shape: " and "/" or " separator, or 3+ comma-separated tokens.
        # Medium threshold per D-06: allows "/" (client/server), single
        # descriptive commas ("Foo, the bar"), and "&" (Q&A workflow).
        # Error key emitted on match: 'top3_composite_target'.
        # -------------------------------------------------------------
        COMPOSITE_PATTERNS = [
            re.compile(r'\s+(and|or)\s+\w+', re.IGNORECASE),
            re.compile(r',\s*\w+,\s*\w+'),
        ]
        # Track (cid, target) tuples for every citation whose target matched a
        # composite pattern. The diagnostic must report the target of the FIRST
        # composite match (the cid that actually triggered rejection), NOT the
        # first resolvable citation's target — those can differ when a Top-3
        # entry cites multiple IDs and only a later one is composite. Reporting
        # resolvable[0]'s target when resolvable[1] is the offender misleads
        # authors debugging rejected synthesis.
        composite_hits = []
        for cid in resolvable:
            tgt = id_to_finding.get(cid, {}).get('target') or ''
            for pat in COMPOSITE_PATTERNS:
                if pat.search(tgt):
                    composite_hits.append((cid, tgt))
                    break
        if composite_hits:
            offending_cid, offending_target = composite_hits[0]
            errors.append(('top3_composite_target',
                           f"Top-3 entry #{top3_count + 1} rejected: composite target '{offending_target}'. Chair must name one concept per entry. Re-run or amend."))
        top3_count += 1

# -----------------------------------------------------------------------
# Also-Raised count (informational, written to stats).
# -----------------------------------------------------------------------
also_raised_body = sections.get('Also Raised', '')
also_raised_count = 0
if also_raised_body.strip():
    also_raised_count = len([ln for ln in also_raised_body.splitlines() if ln.strip().startswith('-')])

# Emit TSV of errors ------------------------------------------------------
with open(errors_path, 'w', encoding='utf-8') as f:
    for check, detail in errors:
        f.write(f"{check}\t{detail}\n")

# Emit stats JSON ---------------------------------------------------------
with open(stats_path, 'w', encoding='utf-8') as f:
    json.dump({
        'contradiction_count':    contradiction_count,
        'blocker_candidate_count': len(candidate_targets),
        'top3_count':             top3_count,
        'also_raised_count':      also_raised_count,
        'survivor_count':         survivor_count,
    }, f)

PYEOF

# --- 6. determine pass/fail from ERRORS_TSV ---
if [ -s "$ERRORS_TSV" ]; then
  VALIDATION_PASSED=0
else
  VALIDATION_PASSED=1
fi

# --- 7. build MANIFEST.synthesis block + atomic rename ---
STATS=$(cat "$STATS_FILE")

# Convert TSV errors to JSON array for MANIFEST.
ERRORS_JSON='[]'
if [ -s "$ERRORS_TSV" ]; then
  ERRORS_JSON=$(python3 - "$ERRORS_TSV" <<'PYEOF'
import json, sys
out = []
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    for line in f:
        line = line.rstrip('\n')
        if not line:
            continue
        parts = line.split('\t', 1)
        check  = parts[0]
        detail = parts[1] if len(parts) > 1 else ''
        out.append({'check': check, 'detail': detail})
print(json.dumps(out))
PYEOF
)
fi

# Compose MANIFEST.synthesis block.
if [ "$VALIDATION_PASSED" -eq 1 ]; then
  SYNTHESIS_BLOCK=$(jq -n \
    --argjson stats "$STATS" \
    --argjson missing "$MISSING_PERSONAS_JSON" \
    '{
      ran: true,
      chair_persona: "council-chair",
      duration_ms: null,
      contradiction_count: $stats.contradiction_count,
      blocker_candidate_count: $stats.blocker_candidate_count,
      top3_count: $stats.top3_count,
      also_raised_count: $stats.also_raised_count,
      missing_personas: $missing,
      validation: {passed: true, errors: []}
    }')
else
  SYNTHESIS_BLOCK=$(jq -n \
    --argjson stats "$STATS" \
    --argjson missing "$MISSING_PERSONAS_JSON" \
    --argjson errs "$ERRORS_JSON" \
    '{
      ran: false,
      chair_persona: "council-chair",
      duration_ms: null,
      contradiction_count: $stats.contradiction_count,
      blocker_candidate_count: $stats.blocker_candidate_count,
      top3_count: $stats.top3_count,
      also_raised_count: $stats.also_raised_count,
      missing_personas: $missing,
      validation: {passed: false, errors: $errs}
    }')
fi

# Additive jq write — mirrors bin/dc-validate-scorecard.sh:489-505 pattern.
MANIFEST_TMP="$TMPDIR_RUN/manifest.json"
jq --argjson s "$SYNTHESIS_BLOCK" '.synthesis = $s' "$MANIFEST" > "$MANIFEST_TMP" \
  && mv "$MANIFEST_TMP" "$MANIFEST"

# Atomic rename draft → final or .invalid.
if [ "$VALIDATION_PASSED" -eq 1 ]; then
  mv "$DRAFT" "$FINAL"
  printf 'dc-validate-synthesis: PASS — contradictions=%s top3=%s candidates=%s missing=%s\n' \
    "$(printf '%s' "$STATS" | jq '.contradiction_count')" \
    "$(printf '%s' "$STATS" | jq '.top3_count')" \
    "$(printf '%s' "$STATS" | jq '.blocker_candidate_count')" \
    "$(printf '%s' "$MISSING_PERSONAS_JSON" | jq 'length')" >&2
  exit 0
else
  mv "$DRAFT" "$INVALID"
  printf 'dc-validate-synthesis: FAIL — %s error(s):\n' \
    "$(printf '%s' "$ERRORS_JSON" | jq 'length')" >&2
  printf '%s\n' "$ERRORS_JSON" | jq -r '.[] | "  - [\(.check)] \(.detail)"' >&2
  exit 1
fi
