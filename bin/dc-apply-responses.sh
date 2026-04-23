#!/usr/bin/env bash
# bin/dc-apply-responses.sh <run-dir>
#
# RESP-01 suppression binary. Phase 7 Plan 06.
#
# Reads `.council/responses.md` (absent = bootstrap empty; created on first run).
# Parses YAML frontmatter via python3 + yaml.safe_load (NEVER yaml.load — T-07-05
# mitigation). Intersects `status: dismissed` entries with the current run's
# finding IDs in `<run-dir>/MANIFEST.json .personas_run[].findings[].id`.
# Writes `<run-dir>/MANIFEST.json .suppressed_findings[]` (always present; empty
# array when none). Emits `SUPPRESSED_IDS=<csv>` on stdout as the last line.
#
# Preserves Phase 3 D-12 single-writer: this binary writes ONLY to MANIFEST
# (suppressed_findings key) and — on first run only — creates the bootstrap
# `.council/responses.md`. It does NOT modify persona .md files, scorecards,
# or any other MANIFEST field. It does NOT rewrite responses.md after bootstrap
# (responses.md is user-authoritative per D-69).
#
# CLI contract:
#   bin/dc-apply-responses.sh <run-dir>
#
# Stdout:
#   Final line: SUPPRESSED_IDS=<csv>   (empty value when zero suppressions)
#
# Exit codes:
#   0 — success (MANIFEST updated; suppressed_findings written)
#   1 — malformed responses.md YAML or missing MANIFEST
#   2 — usage error (bad arg count or run-dir not a directory)

set -euo pipefail

usage() {
  echo "Usage: $0 <run-dir>" >&2
  exit 2
}

[ "$#" -eq 1 ] || usage
RUN_DIR="$1"
[ -d "$RUN_DIR" ] || { echo "ERROR: run-dir not a directory: $RUN_DIR" >&2; exit 2; }

MANIFEST="$RUN_DIR/MANIFEST.json"
[ -f "$MANIFEST" ] || { echo "ERROR: MANIFEST.json missing at $MANIFEST" >&2; exit 1; }

RESPONSES_FILE=".council/responses.md"
mkdir -p .council 2>/dev/null || true

# -----------------------------------------------------------------------------
# Bootstrap: create empty responses.md if absent (D-69 first-run UX).
# -----------------------------------------------------------------------------
if [ ! -f "$RESPONSES_FILE" ]; then
  cat > "$RESPONSES_FILE" <<'BOOTSTRAP'
---
version: 1
responses: []
---
# Response Notes

Annotate findings from `.council/<ts>-<slug>/*.md` here. Format: add
entries under `responses:` with `status` (accepted | dismissed | deferred),
a `reason` (required for dismissed/deferred), and a `date` (YYYY-MM-DD).
Finding IDs are stable across re-runs of the same artifact — see
Phase 5 D-38 in `.planning/phases/05-council-chair-synthesis/05-CONTEXT.md`.
BOOTSTRAP

  # No entries yet → write empty suppressed_findings[] and exit.
  TMP=$(mktemp)
  jq '.suppressed_findings = []' "$MANIFEST" > "$TMP" && mv "$TMP" "$MANIFEST"
  echo "SUPPRESSED_IDS="
  exit 0
fi

# -----------------------------------------------------------------------------
# Parse responses.md frontmatter + intersect with current-run finding IDs.
# -----------------------------------------------------------------------------
python3 - "$RESPONSES_FILE" "$MANIFEST" "$RUN_DIR" <<'PYEOF'
import sys, json, re, os
try:
    import yaml
except ImportError:
    print("ERROR: PyYAML required. Install: pip3 install pyyaml", file=sys.stderr)
    sys.exit(1)

resp_path, manifest_path, run_dir = sys.argv[1], sys.argv[2], sys.argv[3]

with open(resp_path, encoding='utf-8') as f:
    raw = f.read()

# Split on first two '---' fences. Content before first fence must be empty
# (whitespace only); frontmatter block is between fences.
parts = raw.split('---', 2)
if len(parts) < 3:
    print(f"ERROR: {resp_path} has no YAML frontmatter block", file=sys.stderr)
    sys.exit(1)

try:
    fm = yaml.safe_load(parts[1]) or {}
except yaml.YAMLError as e:
    print(f"ERROR: malformed YAML in {resp_path}: {e}", file=sys.stderr)
    sys.exit(1)

if not isinstance(fm, dict):
    print(f"ERROR: {resp_path} frontmatter is not a mapping", file=sys.stderr)
    sys.exit(1)

version = fm.get('version')
if not isinstance(version, int) or version < 1:
    print(f"ERROR: {resp_path} has missing or invalid 'version' (expected int >= 1)", file=sys.stderr)
    sys.exit(1)

responses = fm.get('responses', []) or []
if not isinstance(responses, list):
    print(f"ERROR: {resp_path} 'responses' is not a list", file=sys.stderr)
    sys.exit(1)

id_re = re.compile(r'^[a-z0-9-]+-[0-9a-f]{8}$')
date_re = re.compile(r'^\d{4}-\d{2}-\d{2}$')
ALLOWED_STATUS = ('accepted', 'dismissed', 'deferred')

dismissed = []
for i, entry in enumerate(responses):
    if not isinstance(entry, dict):
        print(f"ERROR: {resp_path} responses[{i}] is not a mapping", file=sys.stderr)
        sys.exit(1)
    fid = entry.get('finding_id')
    status = entry.get('status')
    reason = entry.get('reason')
    date = entry.get('date')
    if not isinstance(fid, str) or not id_re.match(fid):
        print(f"ERROR: {resp_path} responses[{i}].finding_id malformed: {fid!r}", file=sys.stderr)
        sys.exit(1)
    if status not in ALLOWED_STATUS:
        print(f"ERROR: {resp_path} responses[{i}].status must be accepted|dismissed|deferred (got {status!r})", file=sys.stderr)
        sys.exit(1)
    if status in ('dismissed', 'deferred') and not (isinstance(reason, str) and reason.strip()):
        print(f"ERROR: {resp_path} responses[{i}] status={status!r} requires non-empty reason", file=sys.stderr)
        sys.exit(1)
    if not (isinstance(date, str) and date_re.match(date)):
        print(f"ERROR: {resp_path} responses[{i}].date must be YYYY-MM-DD (got {date!r})", file=sys.stderr)
        sys.exit(1)
    if status == 'dismissed':
        dismissed.append({'finding_id': fid, 'reason': reason, 'dismissed_at': date})

# Load MANIFEST + build finding-id -> {persona, target} lookup from current run.
with open(manifest_path, encoding='utf-8') as f:
    manifest = json.load(f)

id_lookup = {}
for pr in manifest.get('personas_run', []) or []:
    persona = pr.get('name')
    for fnd in pr.get('findings', []) or []:
        fid = fnd.get('id')
        if fid:
            id_lookup[fid] = {'persona': persona, 'target': fnd.get('target')}

suppressed = []
for d in dismissed:
    if d['finding_id'] in id_lookup:
        info = id_lookup[d['finding_id']]
        suppressed.append({
            'finding_id': d['finding_id'],
            'status': 'dismissed',
            'reason': d['reason'],
            'dismissed_at': d['dismissed_at'],
            'persona': info['persona'],
            'target': info['target'],
        })

manifest['suppressed_findings'] = suppressed

# Atomic swap write.
tmp = manifest_path + '.tmp'
with open(tmp, 'w', encoding='utf-8') as f:
    json.dump(manifest, f, indent=2, ensure_ascii=False)
    f.write('\n')
os.replace(tmp, manifest_path)

ids = ','.join(s['finding_id'] for s in suppressed)
print(f"SUPPRESSED_IDS={ids}")
PYEOF
