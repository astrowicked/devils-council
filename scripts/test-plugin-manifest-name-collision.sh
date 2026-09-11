#!/usr/bin/env bash
# Guard: .opencode/plugin.json must NOT claim the same plugin `name` as
# .claude-plugin/plugin.json.
#
# Regression context (2026-09-11): .opencode/plugin.json shipped
# "name": "devils-council" — identical to the Claude Code plugin
# identifier. Claude Code then resolved the repo-local OpenCode build as
# the devils-council plugin, shadowing the installed package. Observed
# symptoms:
#   - `claude plugin list` reported 1.5.1 (the .opencode manifest version)
#   - only the 10 agents in .opencode/agents/ registered; the 16 in
#     agents/ did not, so compliance-reviewer and dual-deploy-reviewer
#     were unavailable
#   - /devils-council:review resolved to .opencode/commands/review.md and
#     died on ${DC_ROOT}, which Claude Code never sets
#
# The OpenCode package name of record is .opencode/package.json's
# "devils-council-opencode" — the same string .opencode/README.md tells
# users to put in their opencode.json.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

fail=0

claude_name=$(jq -r .name "$REPO_ROOT/.claude-plugin/plugin.json")
oc_name=$(jq -r .name "$REPO_ROOT/.opencode/plugin.json")
pkg_name=$(jq -r .name "$REPO_ROOT/.opencode/package.json")

if [ "$oc_name" = "$claude_name" ]; then
  echo "FAIL: .opencode/plugin.json name '$oc_name' collides with .claude-plugin/plugin.json" >&2
  echo "      Claude Code will load the OpenCode build in place of the real plugin." >&2
  fail=1
fi

if [ "$oc_name" != "$pkg_name" ]; then
  echo "FAIL: .opencode/plugin.json name '$oc_name' != .opencode/package.json name '$pkg_name'" >&2
  fail=1
fi

# --- version parity -------------------------------------------------------
# There is no release/bump tooling in this repo; all three manifests are
# edited by hand. .opencode/plugin.json drifted to 1.5.1 while the other
# two reached 1.8.0, which is how the shadowing bug above stayed invisible
# (`claude plugin list` reported a version matching no released package).
claude_ver=$(jq -r .version "$REPO_ROOT/.claude-plugin/plugin.json")
oc_ver=$(jq -r .version "$REPO_ROOT/.opencode/plugin.json")
pkg_ver=$(jq -r .version "$REPO_ROOT/.opencode/package.json")

if [ "$claude_ver" != "$oc_ver" ] || [ "$claude_ver" != "$pkg_ver" ]; then
  echo "FAIL: manifest versions disagree — .claude-plugin=$claude_ver .opencode/plugin.json=$oc_ver .opencode/package.json=$pkg_ver" >&2
  echo "      All three are bumped by hand; bump them together." >&2
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "test-plugin-manifest-name-collision: OK — names claude='$claude_name' opencode='$oc_name'; versions all $claude_ver"
fi
exit "$fail"
