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

# Personas transformed from agents/ source. Files in .opencode/agents/ NOT in this
# array are simply left alone — not validated, not deleted, not categorized.
PERSONAS=(staff-engineer sre product-manager devils-advocate council-chair)

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

# Build OpenCode frontmatter
oc_fields = {
    'description': fields.get('description', 'Adversarial reviewer persona'),
    'mode': 'subagent',
    'permission': {
        'edit': 'deny',
        'bash': 'deny',
    }
}

oc_fm = yaml.dump(oc_fields, default_flow_style=False, sort_keys=False).rstrip()

# --- Body transformations ---

# 1. Replace $RUN_DIR input instructions with OpenCode equivalent
# Pattern: lines referencing "Read `INPUT.md` at the run directory..."
body = re.sub(
    r'- Read `INPUT\.md` at the run directory specified by the conductor\. You are reviewing only that artifact — no extra files\.\n',
    '',
    body
)

# 2. Replace output contract "Write your scorecard to $RUN_DIR/..." sections
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

# 3. Remove "Do not write the final $RUN_DIR/..." lines
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
if [[ $VALIDATION_FAILED -ne 0 ]]; then
  echo "VALIDATION FAILED: One or more personas did not pass checks." >&2
  exit 1
fi

echo "All ${#PERSONAS[@]} personas validated successfully."
echo "Files in .opencode/agents/ not in PERSONAS array: left untouched."
