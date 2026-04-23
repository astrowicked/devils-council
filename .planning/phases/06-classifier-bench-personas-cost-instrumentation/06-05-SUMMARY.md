---
phase: 06-classifier-bench-personas-cost-instrumentation
plan: 05
subsystem: codex-delegation
tags: [codex, delegation, fail-loud, bench-personas, D-50, D-51, CDEX-03, CDEX-04, CDEX-05]
dependency-graph:
  requires: [06-02, 06-04]
  provides: [bin/dc-codex-delegate.sh, scripts/test-codex-delegation.sh, commands/review.md#reconcile-codex-delegations]
  affects: [security-reviewer, dual-deploy-reviewer]
tech-stack:
  added: []
  patterns: [PATH-injection for binary mocking, python3+PyYAML frontmatter rewrite, jq additive MANIFEST merge, timeout(1)/gtimeout/background-kill portable wall-clock enforcement]
key-files:
  created:
    - bin/dc-codex-delegate.sh
    - scripts/test-codex-delegation.sh
    - tests/fixtures/bench-personas/codex-stub-success.sh
    - tests/fixtures/bench-personas/codex-stub-auth-expired.sh
    - tests/fixtures/bench-personas/codex-stub-timeout.sh
    - tests/fixtures/bench-personas/codex-stub-json-parse-error.sh
    - tests/fixtures/bench-personas/codex-stub-sandbox-violation.sh
    - tests/fixtures/bench-personas/codex-stub-unknown.sh
    - tests/fixtures/bench-personas/codex-stub-not-installed.sh
    - tests/fixtures/bench-personas/security-draft-with-delegation.md
  modified:
    - commands/review.md
decisions:
  - "MANIFEST.personas_run[] additive merge contract: dc-codex-delegate may create a stub {name, delegation} entry that bin/dc-validate-scorecard.sh later enriches with full persona fields. Ordering (classifier -> budget-plan -> fan-out -> dc-codex-delegate -> validator loop) is load-bearing."
  - "not-installed test case filters PATH entries containing a `codex` binary rather than stripping PATH wholesale, preserving access to jq/python3/bash for the harness to complete."
  - "write_failure() is defined immediately after ATTEMPTED_AT and REQ_JSON default, before any pre-check invokes it. Guards against regression where sandbox/auth/not-installed calls would hit an undefined function."
metrics:
  duration: "~15min"
  completed: "2026-04-23"
  tasks_committed: 3
  files_created: 10
  files_modified: 1
---

# Phase 06 Plan 05: Codex Delegation Wiring (D-50 shell, D-51 fail-loud) Summary

Wires the Codex delegation path end to end: bench persona drafts can emit a
`delegation_request:` block, the conductor runs `bin/dc-codex-delegate.sh`
per draft post-fan-out, and Codex findings (or a delegation_failed envelope
covering all 6 error classes) are merged back into the draft before the
scorecard validator runs. All 21 test assertions (7 cases x 3 checks) pass.

## What Ships

1. **`bin/dc-codex-delegate.sh`** (~260 lines) — reads draft YAML frontmatter,
   performs the sandbox != read-only pre-check (T-06-03 Elevation mitigation),
   verifies `codex` binary and `codex login status`, builds a prompt file
   from `question` + `target` + `context_files`, invokes the canonical
   `codex exec --json --sandbox read-only --skip-git-repo-check --ephemeral -o`
   form with a portable wall-clock timeout (`timeout`/`gtimeout`/background-kill),
   and writes either a merged finding (category `codex-delegate`, source
   `codex-delegate`) on success or a verbatim `delegation_failed` envelope
   finding (category `delegation_failed`) on any of the 6 error classes. The
   MANIFEST.personas_run[].delegation block is written additively so the
   subsequent scorecard validator can enrich the same row without overwriting.
2. **`scripts/test-codex-delegation.sh`** (~115 lines) — drives the 7 cases
   via PATH-injected codex symlinks. Runs in under 10s total (timeout case
   uses `timeout_seconds: 2` from the fixture).
3. **7 codex stubs + 1 draft fixture** — each stub mimics a specific exit-code
   + stderr + -o behavior matching `skills/codex-deep-scan/SKILL.md` error
   taxonomy triggers.
4. **`commands/review.md`** gains two H2 sections (+62 lines, 0 removed):
   `## Reconcile Codex delegations (bench personas only)` between
   `## Spawn the four core personas in parallel` and
   `## Validate each persona's draft sequentially`, and
   `## Render delegation status lines (CDEX-05 fail-loud)` between
   `## Render all four scorecards inline` and `## Explicitly NOT in this flow`.

## Error Classes Exercised in scripts/test-codex-delegation.sh

| Test Case          | Stub Behavior                                        | Expected error_code       |
| ------------------ | ---------------------------------------------------- | ------------------------- |
| success            | writes well-formed JSON to `-o`; exit 0              | `null` (status=succeeded) |
| auth-expired       | `login status` exits 1                               | `codex_auth_expired`      |
| timeout            | `exec` sleeps 30s; fixture timeout_seconds=2         | `codex_timeout`           |
| json-parse-error   | exit 0 but writes malformed JSON                     | `codex_json_parse_error`  |
| sandbox-violation  | exit 1 with "sandbox violation" on stderr            | `codex_sandbox_violation` |
| unknown            | exit 42 with generic stderr                          | `codex_unknown`           |
| not-installed      | `codex` absent from PATH entirely                    | `codex_not_installed`     |

Each case asserts three things: MANIFEST delegation `status`, MANIFEST
delegation `error_code`, and a draft finding with the expected `category`
(`codex-delegate` for success, `delegation_failed` for the six error paths).

## Deviations from Plan

**None material.** Two small authorial refinements to stay true to the
plan's intent:

**1. [Rule 3 - Blocking] `not-installed` PATH handling**
- **Found during:** Task 2 test-harness execution.
- **Issue:** The plan's original harness snippet set `PATH="/usr/bin:/bin"`
  for the not-installed case. On macOS this strips access to
  Homebrew-managed `jq` and Miniconda's `python3+PyYAML`, causing the
  delegate script to abort with "PyYAML required" before reaching the
  `command -v codex` check.
- **Fix:** Filter ORIG_PATH to keep every entry that does NOT contain a
  `codex` executable. Portable across CI (ubuntu-latest) and dev
  workstations (macOS). Still simulates the real-world "codex not
  installed" case faithfully — only the `codex` binary is made
  unreachable; other tools remain on PATH.
- **Files modified:** `scripts/test-codex-delegation.sh` (run_case helper).
- **Commit:** `9cee750` (included in Task 2 commit).

**2. [Rule 2 - Robustness] Stubs drain stdin**
- **Found during:** Task 1 execution of the sandbox-violation stub under
  the test harness.
- **Issue:** `bin/dc-codex-delegate.sh` pipes the prompt file to `codex exec -`
  on stdin. Stubs that printed to stderr and exited without reading stdin
  received SIGPIPE from the `cat` producer, producing spurious exit codes
  in edge cases. Not a correctness issue in the test harness itself but
  rendered individual stub invocations non-deterministic when invoked
  standalone (as in Task 1's acceptance checks).
- **Fix:** Each failure stub now executes `cat >/dev/null 2>&1 || true` before
  emitting its stderr / exit code. Success stub also drains stdin before
  writing the `-o` file.
- **Files modified:** all 7 `codex-stub-*.sh` files.
- **Commit:** `3123035`.

No deviation from `skills/codex-deep-scan/SKILL.md` error-taxonomy message
strings: each of the 6 `write_failure` calls uses the exact canonical message
from the taxonomy table (or a near-verbatim paraphrase where a dynamic value
like `${TIMEOUT}` or `$EXIT_CODE` is interpolated, as required by the table's
`{N}` placeholders).

## Timeout Path Portability

The delegate script handles three environments for wall-clock timeout
enforcement, in priority order:

1. **`timeout(1)`** — GNU coreutils, present on `ubuntu-latest` (GitHub
   Actions default) and most Linux distros.
2. **`gtimeout`** — Homebrew coreutils on macOS (`brew install coreutils`).
   Installs `gtimeout` to avoid colliding with BSD tools.
3. **Background-kill fallback** — portable bash; forks the codex pipeline,
   sleeps `TIMEOUT` seconds, sends SIGTERM. Used on macOS without Homebrew
   coreutils and any system without `timeout`.

**Tested on this session's macOS dev workstation:** `timeout` IS available
(Homebrew coreutils installed, exposes both `timeout` and `gtimeout`). The
first branch triggered in all 7 test cases. The background-kill fallback is
untested end-to-end but follows the canonical shell pattern for portable
kill-after-timeout semantics.

**Follow-up for CI validation:** when this lands in `.github/workflows/ci.yml`,
run `scripts/test-codex-delegation.sh` on both `ubuntu-latest` (exercises the
`timeout(1)` branch) and `macos-latest` (exercises whichever of the three is
resolvable in the default macOS runner toolchain). Plan 06-08 (final CI
wiring) is the natural home for that matrix addition.

## Conductor Positioning Confirmation

`commands/review.md` line numbers after the edit:

- `## Spawn the four core personas in parallel` — line 37
- `## Reconcile Codex delegations (bench personas only)` — line 94 (NEW)
- `## Validate each persona's draft sequentially` — line 130
- `## Render all four scorecards inline` — line 335
- `## Render delegation status lines (CDEX-05 fail-loud)` — line 375 (NEW)
- `## Explicitly NOT in this flow` — line 401

The reconciliation block is strictly between Spawn (37) and Validate (130).
The delegation-status render is strictly between RenderAll (335) and the
ExplicitlyNOT trailer (401). Line-count delta: +62, 0 removed.

## Known Stubs

None. Every code path produces concrete data — success merges real Codex
output into the draft; the 6 failure paths write concrete `delegation_failed`
envelopes. Tests drive every path deterministically.

## Threat Flags

None. Per the plan's `<threat_model>`, all six T-06-xx threats are mitigated
by existing defenses:

- Sandbox-widening rejected pre-invocation (step 2 of delegate, hardcoded
  `--sandbox read-only` in the invocation).
- context_files passed as prompt text, not shell args.
- Question extracted with `jq -r` + printf, never shell-interpolated.
- timeout enforced at the shell level.
- Codex output enters the existing verbatim-evidence validator unchanged.

No new surface introduced that isn't in the threat register.

## Commits

- `3123035` — test(06-05): add codex stubs + delegation draft fixture
- `9cee750` — feat(06-05): add dc-codex-delegate.sh + test-codex-delegation.sh
- `da6e217` — feat(06-05): wire codex delegation reconciliation into review.md

## Self-Check: PASSED

- bin/dc-codex-delegate.sh: FOUND (`test -x` + `bash -n` both pass)
- scripts/test-codex-delegation.sh: FOUND (21/21 assertions pass; exit 0)
- 7 codex-stub-*.sh fixtures: FOUND
- security-draft-with-delegation.md: FOUND (YAML parses; delegation_request
  block present with `sandbox: read-only` and `timeout_seconds: 2`)
- commands/review.md: contains both new H2 sections in the required
  positions.
- Commits `3123035`, `9cee750`, `da6e217` all present in `git log`.
