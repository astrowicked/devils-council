#!/usr/bin/env bash
# scripts/test-severity-render.sh — RESP-04 / D-72 / D-73 render-transform test.
#
# Exercises the severity-tier partition + one-liner emit logic against a
# prebuilt fixture set. Does NOT invoke `claude`. Instead, runs a python
# helper implementing the same spec the commands/review.md render block
# prescribes, and asserts the helper's output matches D-72 expectations
# for both default and --show-nits modes.
#
# Also asserts the RESP-04 invariant that the render transform is
# read-only: fixture file hashes (staff-engineer.md, MANIFEST.json,
# SYNTHESIS.md) are byte-identical before and after the render.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

FAIL=0
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }

FIXDIR="tests/fixtures/severity-render"
[ -f "$FIXDIR/staff-engineer.md" ] || { fail "fixture missing: $FIXDIR/staff-engineer.md"; exit 1; }
[ -f "$FIXDIR/MANIFEST.json" ]     || { fail "fixture missing: $FIXDIR/MANIFEST.json"; exit 1; }
[ -f "$FIXDIR/SYNTHESIS.md" ]      || { fail "fixture missing: $FIXDIR/SYNTHESIS.md"; exit 1; }

# Capture pre-render file hashes to assert the read-only invariant.
if command -v shasum >/dev/null 2>&1; then
  HASH_CMD="shasum -a 256"
else
  HASH_CMD="sha256sum"
fi
SE_HASH_BEFORE=$($HASH_CMD "$FIXDIR/staff-engineer.md" | awk '{print $1}')
MF_HASH_BEFORE=$($HASH_CMD "$FIXDIR/MANIFEST.json"     | awk '{print $1}')
SN_HASH_BEFORE=$($HASH_CMD "$FIXDIR/SYNTHESIS.md"      | awk '{print $1}')

# Python helper implementing the D-72 severity-tier render spec.
# Mirrors the pseudocode in commands/review.md under
# "## Render all four scorecards (severity-tier transform — D-72 / D-73)".
render_spec() {
  local show_nits="$1"
  python3 - "$FIXDIR" "$show_nits" <<'PYEOF'
import sys, yaml, json
fixdir, show_nits_arg = sys.argv[1], sys.argv[2]
show_nits = show_nits_arg == "1"

persona_file = f"{fixdir}/staff-engineer.md"
raw = open(persona_file, encoding='utf-8').read()
parts = raw.split('---', 2)
fm = yaml.safe_load(parts[1]) or {}
findings = fm.get('findings', []) or []

manifest = json.load(open(f"{fixdir}/MANIFEST.json", encoding='utf-8'))
# Display map from commands/review.md (D-72 render block)
persona_slug = 'staff-engineer'
persona_name = 'Staff Engineer'
val = next((v for v in manifest.get('validation', []) if v.get('persona') == persona_slug), {})
kept    = val.get('findings_kept', 0)
dropped = val.get('findings_dropped', 0)

def by_sev(s):
    return [f for f in findings if f.get('severity') == s]

majors = by_sev('major')
minors = by_sev('minor')
nits   = by_sev('nit')

def trunc(s, n=80):
    s = str(s or '')
    return s if len(s) <= n else s[:n] + '…'

out = []
out.append(f"## {persona_name}")
out.append("")
out.append(f"{kept} findings kept, {dropped} dropped.")
out.append("")
# Blockers: already in Chair Top-3 — do not re-render here.
for m in majors:
    out.append(f"[major] {persona_name}: {m.get('target')} — {trunc(m.get('claim'))}")
if minors:
    out.append(f"{len(minors)} minor findings from {persona_name} — cat .council/<run>/{persona_slug}.md to expand")
if nits:
    if show_nits:
        for n in nits:
            out.append(f"[nit] {persona_name}: {n.get('target')} — {trunc(n.get('claim'))}")
    else:
        out.append(f"{len(nits)} nits collapsed from {persona_name} — run with --show-nits to expand or cat .council/<run>/{persona_slug}.md")
print('\n'.join(out))
PYEOF
}

# ---- Default render (SHOW_NITS=0) ----
DEFAULT_OUT=$(render_spec 0)

echo "$DEFAULT_OUT" | grep -qE '^\[major\] Staff Engineer: section-approach — Approach lacks explicit error-budget' \
  && pass "default: major1 one-liner present" \
  || fail "default: major1 one-liner missing"

echo "$DEFAULT_OUT" | grep -qE '^\[major\] Staff Engineer: section-rollout — Rollout flag gate has no rollback command' \
  && pass "default: major2 one-liner present" \
  || fail "default: major2 one-liner missing"

echo "$DEFAULT_OUT" | grep -qE '^2 minor findings from Staff Engineer — cat \.council/' \
  && pass "default: minor collapsed summary present" \
  || fail "default: minor collapsed summary missing"

echo "$DEFAULT_OUT" | grep -qE '^1 nits collapsed from Staff Engineer — run with --show-nits to expand' \
  && pass "default: nits collapse line present" \
  || fail "default: nits collapse line missing"

if echo "$DEFAULT_OUT" | grep -qE '^\[nit\]'; then
  fail "default: nit one-liner present (should be collapsed)"
else
  pass "default: no [nit] one-liners emitted (correctly collapsed)"
fi

if echo "$DEFAULT_OUT" | grep -qiE 'Goal section opens with passive voice'; then
  fail "default: nit claim text leaked (should be collapsed)"
else
  pass "default: nit claim text not present (correctly collapsed)"
fi

# ---- With --show-nits (SHOW_NITS=1) ----
SHOWN_OUT=$(render_spec 1)

echo "$SHOWN_OUT" | grep -qE '^\[major\] Staff Engineer: section-approach' \
  && pass "--show-nits: major1 still present" \
  || fail "--show-nits: major1 missing"

echo "$SHOWN_OUT" | grep -qE '^\[nit\] Staff Engineer: section-goal — Goal section opens with passive voice' \
  && pass "--show-nits: nit one-liner present" \
  || fail "--show-nits: nit one-liner missing"

if echo "$SHOWN_OUT" | grep -qE '^1 nits collapsed from Staff Engineer'; then
  fail "--show-nits: collapse line present (should be expanded)"
else
  pass "--show-nits: no collapse line (correctly expanded)"
fi

# ---- RESP-04 invariant: render is read-only ----
SE_HASH_AFTER=$($HASH_CMD "$FIXDIR/staff-engineer.md" | awk '{print $1}')
MF_HASH_AFTER=$($HASH_CMD "$FIXDIR/MANIFEST.json"     | awk '{print $1}')
SN_HASH_AFTER=$($HASH_CMD "$FIXDIR/SYNTHESIS.md"      | awk '{print $1}')

[ "$SE_HASH_BEFORE" = "$SE_HASH_AFTER" ] && pass "read-only: staff-engineer.md hash unchanged" || fail "read-only: staff-engineer.md modified"
[ "$MF_HASH_BEFORE" = "$MF_HASH_AFTER" ] && pass "read-only: MANIFEST.json hash unchanged"     || fail "read-only: MANIFEST.json modified"
[ "$SN_HASH_BEFORE" = "$SN_HASH_AFTER" ] && pass "read-only: SYNTHESIS.md hash unchanged"      || fail "read-only: SYNTHESIS.md modified"

[ "$FAIL" -ne 0 ] && exit 1
echo "RESP-04 SEVERITY-RENDER TEST: PASSED"
exit 0
