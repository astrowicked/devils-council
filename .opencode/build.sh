#!/usr/bin/env bash
set -euo pipefail
# Build script: transforms agents/ → .opencode/agents/
# Used for npm publish (prepublishOnly). Local dev reads agents/ directly via plugin hook.

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

# Phase 1 scope: 4 core + Chair
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

  # Transform Claude Code frontmatter → OpenCode frontmatter using PyYAML
  python3 - "$src" "$TEMP_DIR/${persona}.md" << 'PYTHON_SCRIPT'
import sys
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

with open(dst_path, 'w') as f:
    f.write('---\n')
    f.write(oc_fm)
    f.write('\n---\n')
    f.write(body)
PYTHON_SCRIPT

  echo "✓ Transformed: ${persona}.md"
done

# --- Atomic move: replace target only on full success ---
rm -rf "$TARGET_DIR"
mv "$TEMP_DIR" "$TARGET_DIR"
# Disable trap cleanup since TEMP_DIR was moved
trap - EXIT

echo "Build complete: ${#PERSONAS[@]} agents in $TARGET_DIR"
