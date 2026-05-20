#!/usr/bin/env bash
# scripts/test-telemetry-skip-non-github.sh — CORR-03 + Pitfall 2
# Asserts bin/dc-telemetry.sh exits silently when the calling cwd's
# `git remote get-url origin` does not point to github.com — including the
# malformed `https://github.com/` empty-path case which would otherwise
# yield an empty owner_repo on the wire.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TELEM="$REPO_ROOT/bin/dc-telemetry.sh"
SRC_FIXTURE="$REPO_ROOT/tests/fixtures/council-run"

pass=0; fail=0

# run_in_tmp <remote_url|""> — sets up a tmp git repo with the given remote
# (skip remote add if empty), copies the fixture in, invokes the script with
# --dry-run, and echoes the captured stdout/stderr.
run_in_tmp() {
  local remote="$1"
  local tmp
  tmp=$(mktemp -d)
  (
    cd "$tmp"
    git init -q
    if [ -n "$remote" ]; then
      git remote add origin "$remote"
    fi
    mkdir -p .council/sample-run
    cp "$SRC_FIXTURE/MANIFEST.json" .council/sample-run/MANIFEST.json
    cp "$SRC_FIXTURE/SYNTHESIS.md" .council/sample-run/SYNTHESIS.md
    env -i HOME="$HOME" PATH="$PATH" \
           CLAUDE_PLUGIN_ROOT="$REPO_ROOT" \
           DC_TELEMETRY=true \
           "$TELEM" .council/sample-run --runtime=claude-code --dry-run 2>&1
  )
  rm -rf "$tmp"
}

assert_silent() {
  local desc="$1"; local remote="$2"
  local out
  out=$(run_in_tmp "$remote")
  if [ -z "$out" ]; then
    printf "  PASS  %s\n" "$desc"
    pass=$((pass+1))
  else
    printf "  FAIL  %s (out=[%s])\n" "$desc" "$out" >&2
    fail=$((fail+1))
  fi
}

assert_silent "gitlab SSH origin → silent" \
  "git@gitlab.example.com:foo/bar.git"

assert_silent "bitbucket HTTPS origin → silent" \
  "https://bitbucket.org/foo/bar.git"

assert_silent "no remote → silent" \
  ""

assert_silent "malformed github URL (empty path) → silent" \
  "https://github.com/"

printf "\n%s/%s cases passed\n" "$pass" "$((pass+fail))"
[ "$fail" -eq 0 ]
