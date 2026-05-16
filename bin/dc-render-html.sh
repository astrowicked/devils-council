#!/usr/bin/env bash
set -euo pipefail
# Render a council run as a single-page HTML report.
# Usage: dc-render-html.sh <run-dir|latest> [-o output.html]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/dc-render-html.py" "$@"
