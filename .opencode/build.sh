#!/usr/bin/env bash
set -euo pipefail
# Build script: transforms agents/ → .opencode/agents/
# Used for npm publish (prepublishOnly). Local dev reads agents/ directly via plugin hook.
#
# What this script does:
#   1. Transforms PERSONAS array members from agents/ source into .opencode/agents/
#   2. Validates each transformed file for OpenCode compatibility
#   3. Leaves ALL other files in .opencode/agents/ untouched (e.g., council-review.md)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="$SCRIPT_DIR/agents"

# --- Dependency gate: python3 + PyYAML ---
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 is required but not found in PATH." >&2
  echo "Install Python 3: https://www.python.org/downloads/" >&2
  exit 1
fi

python3 -c "import yaml" 2>/dev/null || {
  echo "ERROR: PyYAML is required but not installed." >&2
  echo "Install: pip install pyyaml (or: pip3 install pyyaml)" >&2
  exit 1
}

# Personas are derived from agents/ source, not hand-listed. agents/ contains
# persona subagents and nothing else — authoring docs live in docs/ — so every
# agents/*.md is a persona and the roster cannot drift from the plugin's.
# Files in .opencode/agents/ with no agents/ source are left alone — not
# validated, not deleted, not categorized.
PERSONAS=()
while IFS= read -r -d '' _src; do
  PERSONAS+=("$(basename "$_src" .md)")
done < <(find "$REPO_ROOT/agents" -maxdepth 1 -type f -name '*.md' -print0 | sort -z)

if [[ ${#PERSONAS[@]} -eq 0 ]]; then
  echo "ERROR: no persona sources found in $REPO_ROOT/agents" >&2
  exit 1
fi

# --- Atomic write: build to temp dir, move on success ---
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

for persona in "${PERSONAS[@]}"; do
  src="$REPO_ROOT/agents/${persona}.md"

  if [[ ! -f "$src" ]]; then
    echo "ERROR: Missing persona source: $src" >&2
    exit 1
  fi

  # Transform Claude Code agent → OpenCode agent using PyYAML
  python3 - "$src" "$TEMP_DIR/${persona}.md" << 'PYTHON_SCRIPT'
import sys
import re
import yaml

src_path = sys.argv[1]
dst_path = sys.argv[2]

with open(src_path, 'r') as f:
    content = f.read()

# Split frontmatter from body
if not content.startswith('---\n'):
    print(f"ERROR: No frontmatter delimiter in {src_path}", file=sys.stderr)
    sys.exit(1)

# Find the closing ---
end_idx = content.index('\n---\n', 4)
fm_text = content[4:end_idx]
body = content[end_idx + 5:]  # skip \n---\n

# Parse YAML safely
fields = yaml.safe_load(fm_text)
if not isinstance(fields, dict):
    print(f"ERROR: Frontmatter is not a mapping in {src_path}", file=sys.stderr)
    sys.exit(1)

# Build OpenCode frontmatter.
# Codex delegation is not part of the OpenCode build (see post-build cleanup), so
# drop any description sentence that mentions it. Sentence-level, not phrase-level:
# each persona words its delegation clause differently.
_desc = fields.get('description', 'Adversarial reviewer persona')
_desc = re.sub(r'\s*[^.]*?\b(?:Codex|delegation_request)\b[^.]*?\.', '', _desc).strip()

oc_fields = {
    'description': _desc or 'Adversarial reviewer persona',
    'mode': 'subagent',
    'permission': {
        'edit': 'deny',
        'bash': 'deny',
    }
}

oc_fm = yaml.dump(oc_fields, default_flow_style=False, sort_keys=False).rstrip()

# --- Body transformations ---

# 1. Drop the "Read `INPUT.md` at the run directory" bullet — OpenCode has no run
# directory. Done line-by-line rather than by regex: personas wrap this bullet at
# different widths and punctuate the tail with either an em-dash or `--`, and a
# regex pinned to one spelling silently leaves the bullet in place (the defect that
# shipped junior-engineer and competing-team-lead with a stale filesystem read).
_lines = body.split('\n')
_out = []
_i = 0
while _i < len(_lines):
    if _lines[_i].startswith('- Read `INPUT.md` at the run directory'):
        _i += 1
        # consume the bullet's continuation lines
        while _i < len(_lines) and _lines[_i].strip() and not re.match(r'\s*(?:[-*+]\s|#|\d+\.\s)', _lines[_i]):
            _i += 1
        continue
    _out.append(_lines[_i])
    _i += 1
body = '\n'.join(_out)

# 2. Replace output contract "Write your scorecard to $RUN_DIR/..." sections
# Whitespace-flexible: personas wrap this sentence three different ways and a
# pattern pinned to one wrapping leaves the $RUN_DIR path to be swallowed by the
# catch-all below, which yields "Write your scorecard to (removed — ...)" — an
# instruction to write nowhere.
body = re.sub(
    r'Write your scorecard to `\$RUN_DIR/[^`]+`\.\s+The\s+file\s+has\s+exactly\s+two\s+parts:',
    'Output your scorecard directly in your response. Use the exact format below —\nYAML frontmatter between `---` fences with `findings:` array, followed by prose\nSummary body.\n\nThe scorecard has exactly two parts:',
    body
)
body = re.sub(
    r'Write your scorecard to `\$RUN_DIR/[^`]+`\. The file has\s*\n\s*exactly two parts:',
    'Output your scorecard directly in your response. Use the exact format below —\nYAML frontmatter between `---` fences with `findings:` array, followed by prose\nSummary body.\n\nThe scorecard has exactly two parts:',
    body
)
body = re.sub(
    r'Write your scorecard to `\$RUN_DIR/[^`]+`\. The file\s*\nhas exactly two parts:',
    'Output your scorecard directly in your response. Use the exact format below —\nYAML frontmatter between `---` fences with `findings:` array, followed by prose\nSummary body.\n\nThe scorecard has exactly two parts:',
    body
)

# 3. Remove "Do not write the final $RUN_DIR/..." lines. The whitespace-flexible
# pattern comes first: the two pinned ones below miss any other line wrapping.
body = re.sub(
    r'Do not write the final `\$RUN_DIR/[^`]+`\.\s+Do\s+not\s+validate\s+your\s+own\s+output\.\n',
    '',
    body
)
body = re.sub(r'Do not write the final `\$RUN_DIR/[^`]+`\. Do not validate your\s*\nown output\.\n', '', body)
body = re.sub(r'Do not write the final `\$RUN_DIR/[^`]+`\. Do not validate\s*\nyour own output\.\n', '', body)

# 4. Replace validator references with generic downstream language
body = re.sub(r'The validator reads ONLY', 'The `findings:` array is the only load-bearing contract. Downstream consumers read ONLY', body)
body = re.sub(r'The validator drops findings whose evidence is not found\.', 'Findings whose evidence is not found in the artifact are invalid.', body)

# 5. Remove artifact_sha256 lines from worked examples
body = re.sub(r'artifact_sha256: [a-f0-9]+\n', '', body)

# 6. Remove remaining $RUN_DIR references (catch-all)
body = re.sub(r'`\$RUN_DIR/[^`]*`', '(removed — filesystem references not used in OpenCode)', body)
body = re.sub(r'\$RUN_DIR', '(removed)', body)

# 7. Replace "INPUT.md" references in evidence description
body = body.replace('literal substring of `INPUT.md`', 'literal substring of the artifact')
body = body.replace('literal substring of the artifact (≥8 characters)', 'literal substring of the artifact (≥8 characters)')

# 8. Add OpenCode input instruction at top of "How you review" section
input_instruction = "The artifact to review is provided in the user's message or as file content pasted into the conversation. Review ONLY this artifact text. Do not attempt to read from filesystem paths unless the user explicitly provides a file path to read.\n\n"
body = re.sub(
    r'(## How you review\n+)',
    r'\1' + input_instruction,
    body
)

# 9. Replace persona-metadata sidecar references with inline note
body = re.sub(
    r'without the banned phrases listed in your (?:frontmatter|persona-metadata sidecar)\.',
    'without the banned phrases listed below.',
    body
)
body = re.sub(
    r'without the banned phrases listed in your\s*\npersona-metadata sidecar\.',
    'without the banned phrases listed below.',
    body
)

# 10. Catch-all: any surviving INPUT.md reference. The specific replacements above
# only cover the phrasings that existed when they were written; this is the floor.
body = body.replace('`INPUT.md`', 'the artifact')
body = body.replace('INPUT.md', 'the artifact')

with open(dst_path, 'w') as f:
    f.write('---\n')
    f.write(oc_fm)
    f.write('\n---\n')
    f.write(body)
PYTHON_SCRIPT

  echo "✓ Transformed: ${persona}.md"
done

# --- Move transformed files into target (preserve non-PERSONAS files) ---
# Instead of rm -rf the whole target, only overwrite PERSONAS members
mkdir -p "$TARGET_DIR"
for persona in "${PERSONAS[@]}"; do
  mv "$TEMP_DIR/${persona}.md" "$TARGET_DIR/${persona}.md"
done

# Disable trap cleanup since files were moved
rm -rf "$TEMP_DIR"
trap - EXIT

echo ""
echo "Build complete: ${#PERSONAS[@]} personas transformed from agents/"
echo ""

# --- Post-build cleanup: strip Codex delegation and persona-metadata sidecar refs ---
# Codex CLI integration deferred to v1.3. Remove all delegation_request sections,
# Codex references, and persona-metadata sidecar references from bench agents.
# Core personas don't have these, so this is safe to run on all.

for persona in "${PERSONAS[@]}"; do
  target_file="$TARGET_DIR/${persona}.md"

  python3 - "$target_file" << 'CLEANUP_SCRIPT'
import sys
import re

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

original = content

# 1. Remove "Delegating a deep scan to Codex" section entirely (security-reviewer)
content = re.sub(
    r'\n## Delegating a deep scan to Codex.*?(?=\n## )',
    '\n',
    content,
    flags=re.DOTALL
)

# 2. Remove "Do NOT emit delegation_request" paragraphs (finops, air-gap)
content = re.sub(
    r'\nDo NOT emit `delegation_request:`[^\n]*\n(?:[^\n]*\n)*?(?=\nThe `findings:` array)',
    '\n',
    content
)
content = re.sub(
    r'\nNo `delegation_request:`[^\n]*\n(?:[^\n]*\n)*?(?=\nThe `findings:` array)',
    '\n',
    content
)

# 3. Remove "MAY delegate deep scans to Codex via delegation_request." from description
content = re.sub(
    r'( +MAY delegate\n\s+deep scans to Codex via delegation_request\.)', '', content
)
content = re.sub(
    r' MAY delegate\s+deep scans to Codex via delegation_request\.', '', content
)

# 4. Remove "Does not delegate to Codex in v1." from description
content = re.sub(r'\s*Does not delegate to Codex in v1\.', '', content)

# 5. Strip delegation_request from output contract instructions
content = re.sub(
    r'\s*If you are delegating, `delegation_request:` lives here as well, as a\n\s+top-level sibling of `findings:`\.',
    '',
    content
)
content = re.sub(
    r' \(and, if\n\s*present, `delegation_request:`\)',
    '',
    content
)

# 6. Clean worked example: remove delegation_request block from example YAML
content = re.sub(
    r'delegation_request:\n(?:  [^\n]*\n)*',
    '',
    content
)

# 7. Fix worked example intro text referencing delegation
content = re.sub(
    r'findings AND one delegation_request\. The findings live inside the YAML\nfrontmatter `findings:` array; the delegation_request is a top-level\nsibling\. The body below the frontmatter contains only prose\.',
    'findings. The findings live inside the YAML\nfrontmatter `findings:` array. The body below the frontmatter contains only prose.',
    content
)

# 8. Remove "delegated to Codex" references in worked example Summary
content = re.sub(
    r' A third question —\nhow far the `skipVerify` flag reaches into the request-handler tree —\nis delegated to Codex because the answer requires reading files\nbeyond this persona\'s immediate context\.',
    '',
    content
)

# 9a. Sidecar reference where the paren stays OPEN and wraps the inlined phrase
# list: "listed in your persona-metadata sidecar (`persona-metadata/sre.yml`:
# `monitor carefully`, ...)". The patterns below (9b+) all assume the paren closes
# immediately after the path, so they miss this form and the sidecar path — a file
# the npm package does not ship — survives into the shipped agent.
content = re.sub(
    r'(?:listed\s+)?in your persona-metadata sidecar\s*\(\s*`persona-metadata/[^`]+`\s*:[ \t]*',
    'listed below (',
    content
)

# 9b. Replace persona-metadata sidecar references with "listed below"
# Handles multiple patterns: single-line and multi-line with newlines
content = re.sub(
    r'without the banned phrases\s+listed\s+in your persona-metadata sidecar\s*\n?\s*\(`persona-metadata/[^`]+`\)[.:]\s*',
    'without the banned phrases\nlisted below: ',
    content
)
content = re.sub(
    r'without the banned phrases listed\s+in your persona-metadata sidecar\s*\n?\s*\(`persona-metadata/[^`]+`\)[.:]\s*',
    'without the banned phrases listed\nbelow: ',
    content
)
content = re.sub(
    r'without the banned phrases listed in your persona-metadata sidecar\s*\(`persona-metadata/[^`]+`\)\.',
    'without the banned phrases listed below.',
    content
)

# 10. Generalized worked-example intro: personas end this sentence differently
# ("The body below contains only prose." vs "...below the frontmatter...").
content = re.sub(
    r'findings AND one delegation_request\.\s+The findings live inside the YAML\s+frontmatter `findings:` array;\s+the delegation_request is a top-level\s+sibling\.',
    'findings. The findings live inside the YAML\nfrontmatter `findings:` array.',
    content
)

# 11. Generalized: any sentence that delegates a question to Codex.
content = re.sub(r'\s*[^.]*?\bdelegated to\s+Codex\b[^.]*?\.', '', content)

if content != original:
    with open(path, 'w') as f:
        f.write(content)
    print(f"  ⚡ Cleaned: {path.split('/')[-1]}")
CLEANUP_SCRIPT
done

# --- Normalize whitespace: collapse consecutive blank lines (markdown lint MD012) ---
for persona in "${PERSONAS[@]}"; do
  target_file="$TARGET_DIR/${persona}.md"
  # Use perl to collapse 3+ consecutive newlines down to 2 (one blank line)
  perl -i -0777 -pe 's/\n{3,}/\n\n/g' "$target_file"
done

echo ""

# --- Post-transform validation ---
VALIDATION_FAILED=0

for persona in "${PERSONAS[@]}"; do
  target_file="$TARGET_DIR/${persona}.md"
  echo "Validating: ${persona}.md"

  # Check 1: Valid YAML frontmatter (has --- delimiters)
  if ! head -1 "$target_file" | grep -q '^---$'; then
    echo "  FAIL: Missing opening --- delimiter" >&2
    VALIDATION_FAILED=1
    continue
  fi

  # Check 2: mode: subagent in frontmatter
  if ! grep -q 'mode: subagent' "$target_file"; then
    echo "  FAIL: Missing 'mode: subagent' in frontmatter" >&2
    VALIDATION_FAILED=1
    continue
  fi

  # Check 2b (v1.3 FR-10): NO frontmatter `model:` — shipped personas must stay
  # model-silent so the plugin config-hook default and the user's opencode.json
  # override both win (frontmatter beats project config). Inspect only the
  # frontmatter (between the first two --- delimiters).
  frontmatter=$(awk 'BEGIN{c=0} /^---$/{c++; if(c==2) exit; next} c==1{print}' "$target_file")
  if echo "$frontmatter" | grep -qE '^model:'; then
    echo "  FAIL: frontmatter declares 'model:' (v1.3 FR-10 — personas must be model-silent)" >&2
    VALIDATION_FAILED=1
    continue
  fi

  # Check 3: No $RUN_DIR in body (after frontmatter)
  # Extract body (everything after second ---)
  body_content=$(awk 'BEGIN{c=0} /^---$/{c++;next} c>=2{print}' "$target_file")
  if echo "$body_content" | grep -q '\$RUN_DIR'; then
    echo "  FAIL: Body still contains \$RUN_DIR reference" >&2
    VALIDATION_FAILED=1
    continue
  fi

  # Check 4: No Agent tool references in frontmatter tools/allowed-tools
  if grep -q 'tools:.*Agent' "$target_file" || grep -q 'allowed-tools:.*Agent' "$target_file"; then
    echo "  FAIL: Contains Agent tool reference" >&2
    VALIDATION_FAILED=1
    continue
  fi

  echo "  ✓ PASS"
done

echo ""
# --- Banned-token gate -------------------------------------------------------
# The transforms above are prose-pattern matches. When a new persona words a
# Codex/run-directory reference differently, those patterns silently miss and the
# stale reference ships. This gate turns that class of miss into a build failure.
# Every token here is something OpenCode has no equivalent for:
#   RUN_DIR / INPUT.md  — Claude Code's per-run filesystem contract
#   delegation_request / Codex — Codex CLI integration, not part of this build
#   persona-metadata/   — sidecar files the npm package does not ship
BANNED_TOKENS=(RUN_DIR 'INPUT\.md' delegation_request Codex 'persona-metadata/')

# The catch-all replacement in the transform ("(removed — filesystem references not
# used in OpenCode)") is a last resort: it strips the path but leaves a sentence that
# instructs the agent to write nowhere. Its presence means a targeted rewrite was
# missed, so it is a build failure too.
#
# EXEMPT: council-chair. Its Claude Code contract is coupled to the run directory in
# ~12 places (MANIFEST.json, personas_run[], SYNTHESIS.md.draft, and the
# bin/dc-validate-synthesis.sh atomic rename). An OpenCode variant needs those input
# and output contracts hand-authored, not regex-substituted. Open defect — remove
# this exemption when the variant is written.
CATCHALL_EXEMPT=(council-chair)

for persona in "${PERSONAS[@]}"; do
  target_file="$TARGET_DIR/${persona}.md"

  exempt=0
  for e in "${CATCHALL_EXEMPT[@]}"; do
    [[ "$persona" == "$e" ]] && exempt=1
  done
  if [[ $exempt -eq 0 ]] && grep -qF '(removed' "$target_file"; then
    echo "  FAIL: ${persona}.md has an unrewritten filesystem reference" >&2
    grep -nF '(removed' "$target_file" | sed 's/^/    /' >&2
    VALIDATION_FAILED=1
  fi

  for token in "${BANNED_TOKENS[@]}"; do
    if grep -qE "$token" "$target_file"; then
      echo "  FAIL: ${persona}.md still contains '$token' after transform" >&2
      grep -nE "$token" "$target_file" | sed 's/^/    /' >&2
      VALIDATION_FAILED=1
    fi
  done
done

if [[ $VALIDATION_FAILED -ne 0 ]]; then
  echo "VALIDATION FAILED: One or more personas did not pass checks." >&2
  exit 1
fi

echo "All ${#PERSONAS[@]} personas validated successfully."
echo "Files in .opencode/agents/ without an agents/ source: left untouched."

# --- TypeScript compilation (for npm publish) ---
# OpenCode loads plugins via `await import()` on a compiled binary —
# raw .ts files won't load. Compile plugins/*.ts → plugins/*.js using tsc.

echo ""
echo "=== TypeScript compilation ==="

if ! command -v npx &>/dev/null; then
  echo "WARNING: npx not found — skipping TypeScript compilation." >&2
  echo "  npm-published package will NOT work without compiled .js files." >&2
  echo "  Install Node.js 18+ to enable compilation." >&2
  exit 0
fi

# Compile with tsc (uses tsconfig.json in .opencode/)
cd "$SCRIPT_DIR"
npx --yes -p typescript tsc --outDir dist --declaration --declarationDir dist 2>&1 || {
  echo "ERROR: TypeScript compilation failed." >&2
  exit 1
}

# Move compiled files alongside source (npm publish ships plugins/ directory)
for jsfile in dist/plugins/*.js; do
  [ -f "$jsfile" ] && cp "$jsfile" plugins/
done
for dtsfile in dist/plugins/*.d.ts; do
  [ -f "$dtsfile" ] && cp "$dtsfile" plugins/
done

# Clean up dist/
rm -rf dist

echo "✓ TypeScript compiled: plugins/*.js + plugins/*.d.ts"

# --- Copy bin/ and lib/ for npm publish ---
echo ""
echo "=== Copying bin/ and lib/ ==="

rm -r "$SCRIPT_DIR/bin" "$SCRIPT_DIR/lib" 2>/dev/null || true
cp -r "$REPO_ROOT/bin" "$SCRIPT_DIR/bin"
cp -r "$REPO_ROOT/lib" "$SCRIPT_DIR/lib"
cp "$REPO_ROOT/config.json" "$SCRIPT_DIR/config.json"
rm -r "$SCRIPT_DIR/persona-metadata" 2>/dev/null || true   # avoid cp -r nesting into an existing dir
cp -r "$REPO_ROOT/persona-metadata" "$SCRIPT_DIR/persona-metadata"
rm -r "$SCRIPT_DIR/lib/__pycache__" 2>/dev/null || true
rm "$SCRIPT_DIR/bin/.gitkeep" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/bin/"*.sh "$SCRIPT_DIR/bin/"*.py 2>/dev/null || true

echo "✓ bin/ and lib/ copied"

# FR-04 (v1.3): assert model_tier propagated to the generated sidecar copy.
# Root persona-metadata/ is authored; .opencode/persona-metadata/ is this generated copy.
# Every non-classifier sidecar must carry the same model_tier in both.
mt_sync_fail=0
for src in "$REPO_ROOT/persona-metadata/"*.yml; do
  base="$(basename "$src")"
  gen="$SCRIPT_DIR/persona-metadata/$base"
  # classifier is exempt (no model_tier on either side)
  if grep -q '^tier: classifier' "$src"; then continue; fi
  src_mt="$(grep '^model_tier:' "$src" || true)"
  gen_mt="$(grep '^model_tier:' "$gen" 2>/dev/null || true)"
  if [ -z "$src_mt" ]; then
    echo "  ✗ $base: root sidecar missing model_tier" >&2; mt_sync_fail=1; continue
  fi
  if [ "$src_mt" != "$gen_mt" ]; then
    echo "  ✗ $base: model_tier did not propagate to generated copy (root='$src_mt' gen='$gen_mt')" >&2; mt_sync_fail=1
  fi
done
if [ "$mt_sync_fail" -ne 0 ]; then
  echo "✗ model_tier propagation check failed (FR-04)" >&2; exit 1
fi
echo "✓ model_tier propagated to generated sidecars"
echo ""
echo "Build complete."
