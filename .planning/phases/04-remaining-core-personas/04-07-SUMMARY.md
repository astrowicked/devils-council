---
phase: 04-remaining-core-personas
plan: 07
subsystem: test-harness
tags:
  - test-harness
  - isolation
  - fingerprint
  - manual-gate
  - order-swap
  - core-06
requires:
  - commands/review.md (Plan 05 output; four-line spawn enumeration targeted by surgical edit)
  - bin/dc-validate-scorecard.sh (Plan 03; produces validated per-persona scorecards with findings[] frontmatter)
  - .council/<ts>-<slug>/ run-dir schema (Plan 03; script reads <run-dir>/<persona>.md)
  - python3 + PyYAML (Phase 3 validator dependency)
  - jq (fixture manipulation + result JSON append)
provides:
  - CORE-06 order-swap isolation verifier (local-interactive, not wired into CI)
  - tests/fixtures/order-swap-results.json as append-only run log
affects:
  - commands/review.md (at RUNTIME only — surgical edit, triple-layer-protected restore; committed file unchanged)
tech_added:
  - python3 inline HEREDOC for surgical multi-line edit of commands/review.md
  - python3 hashlib.sha256 for portable cross-platform hashing (no shasum/sha256sum divergence in fingerprint path)
  - yaml.safe_load for frontmatter parsing (no unsafe_load; T-04-46)
patterns_used:
  - Triple-layer restoration defense (backup + trap EXIT + sha256-verified explicit restore)
  - Fingerprint comparison per research §Pattern 4 (sorted (target, severity, category) tuples + severity/category distributions + finding count → canonical JSON → sha256)
  - Fail-loud match-count invariant (surgical edit requires exactly one match, aborts before any write if structure drifts)
  - Shell-harness pattern from scripts/test-engine-smoke.sh (set -euo pipefail, pass/fail helpers, trap cleanup, exit contract)
key_files_created:
  - scripts/test-order-swap.sh
  - tests/fixtures/order-swap-results.json
key_files_modified: []
decisions:
  - "D-28 resolved: path B (fingerprint comparison) is the only viable determinism strategy; path A (hash-equality via sampling determinism) foreclosed by research §Summary #1 (sampling controls not exposed to plugin Agent calls). No sampling-control flags anywhere in script."
  - "Order-change mechanism: surgical python3 edit of commands/review.md (chosen over a DC_PERSONA_ORDER env-var test-mode branch). Rationale: zero modification to Plan 05's committed commands/review.md contract; the only risk (restoration failure) is mitigated by three independent restoration mechanisms."
  - "Fingerprint intentionally ignores prose (claim/ask/evidence wording), intra-run finding ordering, timestamps, nonces, and file paths. Sensitive to real context-bleed (a persona that saw another's draft would emit qualitatively different targets)."
  - "Script is NOT wired into .github/workflows/ci.yml. Requires live Claude Code Agent invocations; headless faking is impossible and a --headless flag was intentionally not offered to prevent future accidental CI wiring (T-04-44)."
metrics:
  completed: 2026-04-22
  duration_minutes: approximately 20
  tasks_completed: 1
  files_created: 2
  lines_of_code: 410
---

# Phase 4 Plan 07: CORE-06 Order-Swap Isolation Verifier Summary

**One-liner:** Interactive harness that drives two live `/devils-council:review` runs (canonical + reversed spawn order) and asserts per-persona scorecard fingerprint stability to prove parallel-spawn isolation; implements D-28 path B exclusively because research foreclosed path A.

## What Was Built

Two files, one executable interactive test harness and one append-only result log:

1. **`scripts/test-order-swap.sh`** (410 lines, mode 0755) — the CORE-06 verification rite. Flow:
   - Preflight checks: `commands/review.md` exists, `jq` / `python3` / PyYAML present, fixture readable.
   - Capture pre-edit `sha256` of `commands/review.md` for restoration verification.
   - Install `trap restore_review_cmd EXIT` BEFORE the first edit so any exit path restores the backup.
   - Write backup file `commands/review.md.orderswap-backup` to disk.
   - Prompt user: run `/devils-council:review <fixture>` in a live Claude Code session, paste the resulting run-dir. Validate all four scorecards exist.
   - Surgical python3 edit of `commands/review.md` to reverse the four-line spawn enumeration; fails loudly if the canonical block does not match exactly once. Post-edit `sha256` must differ from pre-edit.
   - Prompt user to `/reload-plugins` (or restart claude), re-run the review on the same fixture, paste the new run-dir. Validate all four scorecards exist and the run-dir differs from canonical.
   - Restore `commands/review.md` from backup; verify `sha256` matches pre-edit. If mismatch: retain backup for manual recovery, disarm trap, exit 1.
   - Compute path-B fingerprint per persona per run using `python3 + yaml.safe_load`: extract `findings[]` from frontmatter, build sorted `(target, severity, category)` tuples, compute severity + category distributions + finding count, emit sorted JSON, `sha256`.
   - Compare per-persona fingerprints across the two runs; assemble result JSON (canonical+reversed orders, per-persona match booleans, full fingerprint map, mismatches array, outcome).
   - Append result to `tests/fixtures/order-swap-results.json` via `jq --arg/--argjson`.
   - Exit 0 on all-four-match; exit 1 on any drift or restoration failure.

2. **`tests/fixtures/order-swap-results.json`** — initialized with `[]` + trailing newline. Append-only log; each invocation appends one JSON object matching the schema in the plan's `<interfaces>` section.

## Commits

| Task | Commit  | Description                                                  |
| ---- | ------- | ------------------------------------------------------------ |
| 1    | a521d85 | feat(04-07): add CORE-06 order-swap isolation verifier       |

## Key Decisions Recapped

### D-28 resolution — path B chosen (path A foreclosed by research)

Research §Summary finding #1 verified against `code.claude.com/docs/en/sub-agents` and `code.claude.com/docs/en/settings` that no plugin-authored Agent frontmatter field, slash-command option, or environment variable exposes the sampling controls that path A would require for hash-equality across runs. The script therefore implements path B exclusively: fingerprint comparison. The script contains zero references to sampling-control flags, environment variables, or heredoc options that would tempt a future contributor to attempt path A. The docstring cites the research §Summary #1 finding as the reason.

### Order-change mechanism — surgical edit over env-var branch

Two options were on the table:

- **Path 1 (chosen):** Script edits `commands/review.md` in place to reverse the four-line spawn enumeration, runs the review, then restores the file.
- **Path 2 (rejected):** Conductor accepts a `DC_PERSONA_ORDER` env var and branches on it.

Path 1 wins because path 2 would have required modifying Plan 05's committed `commands/review.md` to add a test-mode branch — that modification would either have required replanning Plan 05 (forbidden by the orchestration prompt) or would leave Plan 05's output silently inconsistent with this plan's assumptions. Path 1 keeps Plan 05's output exactly as-authored; the only added risk (restoration failure) is mitigated by three independent restoration mechanisms.

### Triple-layer restoration defense (T-04-42 mitigation)

- **Layer 1 (durable state):** `cp -f "$REVIEW_CMD" "$BACKUP"` writes `commands/review.md.orderswap-backup` to disk BEFORE any edit. A crash between the backup write and the edit leaves the repo identical to its pre-run state.
- **Layer 2 (involuntary exit):** `trap restore_review_cmd EXIT` is installed before the edit. Any exit path — `set -e` abort mid-script, Ctrl-C, kill -9 to a child process that propagates, normal exit from a fail path — triggers the trap, which copies the backup back over `commands/review.md` and removes the backup.
- **Layer 3 (voluntary restore + verification):** After the reversed run completes, the script explicitly `cp -f "$BACKUP" "$REVIEW_CMD"` and verifies that the post-restore `sha256` matches the captured pre-edit `sha256`. If they differ, the script retains the backup for manual recovery, disarms the trap (to prevent the trap from overwriting the diverged state a second time with an identical but unverified backup), and exits 1. If they match, the backup is removed and the trap is disarmed.

### Fingerprint recipe — why (target, severity, category) + distributions is the right signal

`target` strings are deterministic anchors: line references, quoted snippets, file paths. Severity and category are bounded enums. Finding count is an integer. These four axes are what would shift if a persona saw another's draft — a Staff Engineer who got leakage from Devil's Advocate's context would emit targets covering assumptions and premises, not just architectural scope. Claim, ask, and evidence prose varies run-to-run from sampling noise, but that variation is orthogonal to the isolation question. The fingerprint is robust to noise AND sensitive to real context-bleed. Known limitation: a persona that produces zero findings on both runs fingerprints identically regardless of isolation. Compensating control: CORE-05 (Plan 06) independently validates that personas produce differentiated non-empty content via the blinded-reader harness.

### Manual-gate / no-CI recap

The script requires live Claude Code Agent invocations to produce the two runs being compared. GH Actions has no live Claude Code session and no supported way to fake one while still exercising the parallel subagent spawn path. The script is therefore interactive-only, lives in `scripts/`, and is intentionally not referenced from `.github/workflows/ci.yml`. The docstring states "NOT WIRED INTO CI" in its header. No `--headless` flag is offered, to prevent future contributors from wiring it into CI and causing indefinite hangs at the `read -rp` prompts (T-04-44).

## Deviations from Plan

None — plan executed exactly as written. Both the plan's automated verify regex (`temperature.*=.*0`) and the stricter prompt-level criterion ("no references to temperature or ANTHROPIC_TEMPERATURE at all") were satisfied: the docstring was authored from the start to refer to "sampling controls" and "sampling determinism" instead of the token `temperature`, so no remediation was needed.

## Verification Results

All 22 automated acceptance criteria enumerated in the plan pass:

| # | Check | Result |
|---|-------|--------|
| A1  | `test -x scripts/test-order-swap.sh` | OK |
| A2  | `bash -n scripts/test-order-swap.sh` | OK |
| A3  | line count >= 200 (actual: 410) | OK |
| A4  | shebang is `#!/usr/bin/env bash` | OK |
| A5  | `set -euo pipefail` present | OK |
| A6  | `CORE-06` + `path B`/`fingerprint comparison` present | OK |
| A7  | fingerprint fields (sorted_tuples, severity_dist, category_dist, finding_count) | OK |
| A8  | path A foreclosure (no `temperature.*=.*0`, `ANTHROPIC_TEMPERATURE`, `--temperature`) | OK |
| A9  | stricter: no `temperature` references at all | OK |
| A10 | triple-layer restore (`orderswap-backup`, `trap restore_review_cmd EXIT`, `SHA_BEFORE`/`SHA_AFTER_RESTORE`) | OK |
| A11 | all four persona slugs present | OK |
| A12 | `CANONICAL_ORDER=` + `REVERSED_ORDER=` arrays | OK |
| A13 | python3 surgical edit heredoc | OK |
| A14 | `count != 1` fail-loud check | OK |
| A15 | bash 3.2 compat (no `declare -A`, `readarray`, `mapfile`) | OK |
| A16 | result JSON fields (canonical_run_dir, reversed_run_dir, per_persona_fingerprint_match, fingerprints, mismatches, outcome) | OK |
| A17 | `ALL_MATCH` exit contract | OK |
| A18 | PyYAML precheck (`import yaml`) | OK |
| A19 | `yaml.safe_load` (no unsafe_load) | OK |
| A20 | `tests/fixtures/order-swap-results.json` is `[]` | OK |
| A21 | `.github/workflows/ci.yml` NOT modified (no `test-persona-voice` or `test-order-swap` refs) | OK |
| A22 | `commands/review.md` NOT modified by this plan | OK |

## Manual Verification (out of scope for this plan; owned by /gsd-verify-work)

Per the plan's `<verification>` §Manual, Andy runs the harness on both `tests/fixtures/plan-sample.md` and `tests/fixtures/diff-sample.patch` once Plans 04-01 through 04-06 have landed (i.e., once `commands/review.md` contains the four-line spawn enumeration the surgical edit targets, and once all four persona agent files exist). The CORE-06 ship signal is both fixtures reporting `PASS: CORE-06 order-swap: all four personas fingerprint-stable`.

Because this worktree was cut before Plans 04-01..04-06 landed, the script cannot be end-to-end exercised in this branch; Andy runs it after the full Phase 4 waves converge on main.

## Self-Check: PASSED

File existence:
- `FOUND: scripts/test-order-swap.sh`
- `FOUND: tests/fixtures/order-swap-results.json`
- `FOUND: .planning/phases/04-remaining-core-personas/04-07-SUMMARY.md`

Commit verification:
- `FOUND: a521d85` (feat(04-07): add CORE-06 order-swap isolation verifier)
