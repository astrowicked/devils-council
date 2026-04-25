#!/usr/bin/env bash
# scripts/validate-shell-inject.sh
# Dry-run pre-parser for Claude Code shell-injection patterns in commands/*.md.
#
# APPROXIMATION WARNING: This parser implements the documented shell-injection
# rules (!`<cmd>` inline + ```! fenced) but is NOT byte-identical to Claude
# Code's actual pre-parser. If drift appears (false positive or false negative)
# treat this script as the source-of-record approximation and file an issue;
# do NOT bypass the hook by editing commands/*.md outside Claude Code.
#
# Regression target: v1.0.0 P0 — inline !`<cmd>` in prose (commit da45340).
# Test fixtures: tests/fixtures/shell-inject/
# Allowlist:     scripts/shell-inject-allowlist.txt + inline <!-- dc-shell-inject-ok: reason -->
#
# Usage:
#   validate-shell-inject.sh <file.md> [<file.md> ...]
#   validate-shell-inject.sh --allowlist <path> <file.md>   (default: scripts/shell-inject-allowlist.txt)
#   validate-shell-inject.sh --verbose <file.md>
#   validate-shell-inject.sh -h | --help
#
# Exit codes:
#   0 — all files pass (no unauthorized injections)
#   1 — one or more unauthorized injections found
#   2 — usage / file-not-found / env error
#
# Env gates (D-03):
#   CLAUDE_PLUGIN_OPTION_SHELL_INJECT_GUARD=false  skip validation entirely, exit 0
#
# PASS example (allowed inline marker):
#   <!-- dc-shell-inject-ok: intentional prep-hook invocation -->
#   !`${CLAUDE_PLUGIN_ROOT}/bin/dc-prep.sh`
#
# FAIL example (v1.0.0 P0 class — inline injection in prose):
#   Do NOT use `` !`<cmd>` `` shell-inject here — `<RUN_DIR>` is resolved at runtime.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

DEFAULT_ALLOWLIST="${REPO_ROOT}/scripts/shell-inject-allowlist.txt"
ALLOWLIST_PATH=""
VERBOSE=0
FILES=()

usage() {
  cat <<'USAGE'
validate-shell-inject.sh — dry-run pre-parser for shell-inject patterns in commands/*.md

Usage:
  validate-shell-inject.sh <file.md> [<file.md> ...]
  validate-shell-inject.sh --allowlist <path> <file.md>
  validate-shell-inject.sh --verbose <file.md>

Exit codes:
  0 — no unauthorized injections
  1 — unauthorized injection(s) detected
  2 — usage / env error

Env:
  CLAUDE_PLUGIN_OPTION_SHELL_INJECT_GUARD=false   disable parser (emits note to stderr, exit 0)
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --allowlist)
      if [ $# -lt 2 ]; then echo "validate-shell-inject: --allowlist requires a path" >&2; exit 2; fi
      ALLOWLIST_PATH="$2"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    --) shift; while [ $# -gt 0 ]; do FILES+=("$1"); shift; done ;;
    -*) echo "validate-shell-inject: unknown flag: $1" >&2; usage >&2; exit 2 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

# Env gate (D-03): opt-out
GUARD_VAL="${CLAUDE_PLUGIN_OPTION_SHELL_INJECT_GUARD:-true}"
GUARD_LOWER=$(printf '%s' "$GUARD_VAL" | tr '[:upper:]' '[:lower:]')
if [ "$GUARD_LOWER" = "false" ]; then
  echo "validate-shell-inject: shell-inject guard disabled by userConfig; skipping" >&2
  exit 0
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "validate-shell-inject: no input files" >&2
  usage >&2
  exit 2
fi

for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "validate-shell-inject: file not found: $f" >&2
    exit 2
  fi
done

: "${ALLOWLIST_PATH:=$DEFAULT_ALLOWLIST}"

# Dispatch to embedded python3 parser.
export ALLOWLIST_PATH VERBOSE REPO_ROOT
python3 - "${FILES[@]}" <<'PYEOF'
# Embedded parser — STACK.md §Q3 regex + fence-state machine (~50 LOC).
# Detects:
#   - inline !`<cmd>` in prose (v1.0.0 P0 regression target)
#   - fenced ```! code blocks (executable injection fence)
# Exempts:
#   - triple-backtick non-! fences (documentation of syntax)
#   - sites listed in scripts/shell-inject-allowlist.txt by <relpath>:<line>
#   - sites preceded by <!-- dc-shell-inject-ok: <non-empty reason> -->
import os
import re
import sys

ALLOWLIST_PATH = os.environ.get("ALLOWLIST_PATH", "")
REPO_ROOT = os.environ.get("REPO_ROOT", os.getcwd())
VERBOSE = os.environ.get("VERBOSE", "0") == "1"

# Skip the heredoc-script arg (python3 consumes it as sys.argv[0] = '-').
FILES = [a for a in sys.argv[1:] if not a.startswith("-")]
# Re-derive: our bash wrapper passes all original args including flags; filter
# to only real paths (files that exist).
FILES = [a for a in FILES if os.path.isfile(a)]

FENCE_OPEN  = re.compile(r'^(\s*)```(!?)(\w*)\s*$')
FENCE_CLOSE = re.compile(r'^(\s*)```\s*$')
INLINE_INJECT = re.compile(r'!`([^`\n]+)`')
INLINE_MARKER = re.compile(r'<!--\s*dc-shell-inject-ok:\s*(.+?)\s*-->')

def load_allowlist(path):
    """Return dict: {relpath: set(line_numbers)}."""
    entries = {}
    if not path or not os.path.isfile(path):
        return entries
    with open(path, 'r', encoding='utf-8') as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith('#'):
                continue
            # Format: <relpath>:<lineno>:<pattern>
            parts = line.split(':', 2)
            if len(parts) < 2:
                continue
            relpath = parts[0].strip()
            try:
                lineno = int(parts[1].strip())
            except ValueError:
                continue
            entries.setdefault(relpath, set()).add(lineno)
    return entries

def relpath_for(abs_or_rel):
    """Resolve path relative to REPO_ROOT for allowlist matching."""
    p = os.path.abspath(abs_or_rel)
    root = os.path.abspath(REPO_ROOT)
    try:
        return os.path.relpath(p, root)
    except ValueError:
        return abs_or_rel

ALLOW = load_allowlist(ALLOWLIST_PATH)

def is_allowlisted(relpath, lineno):
    return lineno in ALLOW.get(relpath, set())

def has_inline_marker(prev_line):
    if prev_line is None:
        return False
    m = INLINE_MARKER.search(prev_line)
    if not m:
        return False
    reason = m.group(1).strip()
    return len(reason) > 0

def scan(path):
    """Return list of (lineno, col, kind, extracted, context_line) violations."""
    violations = []
    try:
        with open(path, 'r', encoding='utf-8') as fh:
            lines = fh.read().splitlines()
    except Exception as exc:
        print(f"validate-shell-inject: cannot read {path}: {exc}", file=sys.stderr)
        sys.exit(2)

    relpath = relpath_for(path)
    in_fence = False
    fence_is_inject = False
    prev_raw = None

    for idx, line in enumerate(lines):
        lineno = idx + 1
        if not in_fence:
            m = FENCE_OPEN.match(line)
            if m:
                in_fence = True
                fence_is_inject = (m.group(2) == '!')
                if fence_is_inject:
                    if not is_allowlisted(relpath, lineno) and not has_inline_marker(prev_raw):
                        violations.append((lineno, len(m.group(1)), 'FENCED_INJECT_OPEN',
                                           line.strip(), line))
                prev_raw = line
                continue
            # Outside any fence — scan for inline !`<cmd>`
            for im in INLINE_INJECT.finditer(line):
                col = im.start()
                if is_allowlisted(relpath, lineno):
                    continue
                if has_inline_marker(prev_raw):
                    continue
                violations.append((lineno, col, 'INLINE_INJECT', im.group(1), line))
        else:
            # inside a fence
            if FENCE_CLOSE.match(line):
                in_fence = False
                fence_is_inject = False
                prev_raw = line
                continue
            if fence_is_inject:
                # every line inside an injection fence is an injection
                if not is_allowlisted(relpath, lineno):
                    violations.append((lineno, 0, 'FENCED_INJECT_BODY', line.strip(), line))
            # else: non-inject fence — exempt zone (documentation of syntax)
        prev_raw = line
    return violations

def fmt(path, lineno, col, kind, extracted, context):
    ctx = context if len(context) <= 120 else context[:117] + '...'
    return (
        f"validate-shell-inject: FAIL — unauthorized shell-inject in {path}:{lineno}:{col}\n"
        f"  pattern: !`{extracted}`\n"
        f"  kind:    {kind}\n"
        f"  context: {ctx}\n"
        f"  remediation: wrap in a non-`!` triple-backtick fence, add <!-- dc-shell-inject-ok: reason --> above it,\n"
        f"               or add {relpath_for(path)}:{lineno}:<pattern-prefix> to scripts/shell-inject-allowlist.txt"
    )

total_violations = 0
for f in FILES:
    viols = scan(f)
    if viols:
        for (ln, col, kind, extracted, ctx) in viols:
            print(fmt(f, ln, col, kind, extracted, ctx), file=sys.stderr)
        total_violations += len(viols)
    elif VERBOSE:
        print(f"validate-shell-inject: PASS {f}", file=sys.stderr)

if total_violations > 0:
    sys.exit(1)
sys.exit(0)
PYEOF
