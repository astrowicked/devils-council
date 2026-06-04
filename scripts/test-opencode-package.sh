#!/usr/bin/env bash
# v1.3 FR-11: guardrail on what actually SHIPS (the npm tarball), not the working tree.
#   1. Pack the OpenCode plugin (npm pack), using the files allowlist.
#   2. Assert NO shipped persona agent declares a frontmatter `model:` (model-silent rule).
#   3. Post-pack smoke: the plugin entry loads and default-exports a function.
# Run AFTER .opencode/build.sh (the tarball ships whatever is in .opencode/agents/).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="$SCRIPT_DIR/.opencode"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; rm -f "$PKG_DIR"/devils-council-opencode-*.tgz' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

echo "== packing $PKG_DIR =="
( cd "$PKG_DIR" && npm pack --quiet >/dev/null 2>&1 ) || fail "npm pack failed"
tgz="$(ls "$PKG_DIR"/devils-council-opencode-*.tgz 2>/dev/null | head -1)"
[ -n "$tgz" ] || fail "no tarball produced"

tar -xzf "$tgz" -C "$WORK"
ROOT="$WORK/package"

# 1. Model-silent guarantee (FR-11): inspect frontmatter of every shipped agent.
echo "== checking shipped agents are model-silent =="
violations=0
shopt -s nullglob
for f in "$ROOT"/agents/*.md; do
  fm="$(awk 'BEGIN{c=0} /^---$/{c++; if(c==2) exit; next} c==1{print}' "$f")"
  if echo "$fm" | grep -qE '^model:'; then
    echo "  VIOLATION: $(basename "$f") ships a frontmatter 'model:'" >&2
    violations=$((violations+1))
  fi
done
[ "$violations" -eq 0 ] || fail "$violations shipped persona(s) declare a frontmatter model: (FR-10/FR-11)"
echo "  ok: no shipped persona declares a frontmatter model:"

# 2. Post-pack smoke: the entry is present, syntactically valid, and exports
#    what the loader expects. (A full dynamic import is avoided: the compiled JS
#    uses extensionless relative imports that opencode's loader resolves but
#    plain `node` ESM does not — so we check syntax + exports, not resolution.)
echo "== post-pack smoke: plugin entry valid + exports =="
entry="$ROOT/plugins/devils-council.js"
[ -f "$entry" ] || fail "plugins/devils-council.js missing from tarball"
node --check "$entry" 2>/dev/null || fail "plugins/devils-council.js is not syntactically valid"
grep -q "export default" "$entry" || fail "entry missing a default export"
grep -q "injectModelDefaults" "$entry" || fail "entry missing injectModelDefaults"
echo "  ok: entry valid, has default export + injectModelDefaults"

# 3. Presets ship.
[ -f "$ROOT/lib/model-presets.json" ] || fail "lib/model-presets.json missing from tarball"
echo "  ok: lib/model-presets.json shipped"

echo "PASS: package guardrail (model-silent + entry smoke + presets present)"
