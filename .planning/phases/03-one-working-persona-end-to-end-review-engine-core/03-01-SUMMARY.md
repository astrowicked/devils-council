---
phase: 03-one-working-persona-end-to-end-review-engine-core
plan: 01
subsystem: engine-core
tags: [shell, plugin, prep-script, engine-core]
dependency_graph:
  requires:
    - Phase 01 shell style (scripts/smoke-codex.sh)
    - jq (Phase 1+2 dependency)
    - shasum or sha256sum (preinstalled)
  provides:
    - bin/dc-prep.sh — classify + snapshot + MANIFEST init
    - MANIFEST.json v1 schema (13 fields)
    - RUN_DIR=<path> stdout contract for shell-injection capture
    - Per-run XML-framing nonce (ADD-1)
  affects:
    - Plan 03-04 conductor (commands/review.md) — consumes RUN_DIR stdout
    - Plan 03-05 CI smoke test — exercises every classifier branch
    - Plan 03-02 validator (bin/dc-validate-scorecard.sh) — consumes INPUT.md
tech_stack:
  added: []
  patterns:
    - set -euo pipefail + err() helper (Phase 1 convention mirrored)
    - jq -n structured JSON emit (no string concat)
    - case-based flag parse (bash 3.2 compatible)
    - file --mime binary detection
    - shasum/sha256sum portable fallback detection
key_files:
  created:
    - bin/dc-prep.sh
  modified: []
decisions:
  - 100KB artifact size cap (Claude's discretion, documented in err message)
  - Slug truncation at 40 chars (keeps macOS 255-byte filename headroom for persona children)
  - Collision suffix is 4-hex from /dev/urandom via od -An -N2 (≈1/65536 second-collision)
  - XML nonce is 8-hex via od -N4 (validated 6-8 range for fallback openssl path)
  - --type accepts BOTH --type=X and --type X (Pitfall 5 recommendation)
  - Detection failure path exists structurally (CLASSIFICATION_WARNING) but
    detect_type always returns a value today; structural safety net for D-07
metrics:
  duration: ~15m
  completed: 2026-04-22
  commits: 1
  files_created: 1
  lines_added: 228
---

# Phase 03 Plan 01: dc-prep.sh Deterministic Artifact-Prep Script

Deterministic shell preprocessor for `/devils-council:review`: classifies artifact
type by D-05 precedence rules, snapshots byte-identically to INPUT.md, emits
MANIFEST.json v1 with per-run nonce (ADD-1), and prints `RUN_DIR=<path>` as its
final stdout line so the conductor can capture it via `` !`...` `` shell-injection
at prompt-load time.

## What Shipped

**File created:** `bin/dc-prep.sh` (228 lines, executable, bash 3.2 compatible)

**MANIFEST.json v1 schema emitted (13 fields):**

| Field                    | Type          | Source                                                       |
| ------------------------ | ------------- | ------------------------------------------------------------ |
| `artifact_path`          | string        | First positional arg (verbatim)                              |
| `detected_type`          | enum          | `code-diff`\|`plan`\|`rfc` (classifier or `--type` override) |
| `run_dir`                | string        | `.council/<TS>-<slug>[-<hex>]`                               |
| `started_at`             | ISO-8601 UTC  | `date -u +%Y-%m-%dT%H:%M:%SZ`                                |
| `sha256`                 | 64-hex        | Against INPUT.md (snapshot, not source — TOCTOU-safe)        |
| `nonce`                  | 6-8 hex       | `/dev/urandom` via `od -An -N4 -tx1` (ADD-1)                 |
| `bytes`                  | number        | `wc -c` of artifact                                          |
| `personas_run`           | array         | `[]` (populated by conductor in Plan 04)                     |
| `findings_kept`          | number        | `0` (populated by validator in Plan 02)                      |
| `findings_dropped`       | number        | `0` (populated by validator in Plan 02)                      |
| `budget_usage`           | null          | Reserved for Phase 6 cost instrumentation                    |
| `classification_warning` | string\|null  | `null` unless detect_type returns empty (defensive)          |
| `plugin_version`         | string\|null  | `.claude-plugin/plugin.json .version` or `null`              |

## Classifier Rule Coverage (D-05)

Verified against all three existing fixtures:

| Fixture                        | Rule Matched | Detected   | Notes                              |
| ------------------------------ | ------------ | ---------- | ---------------------------------- |
| `tests/fixtures/plan-sample.md` | Rule 3       | `plan`     | `# Plan:` heading matches inner `^#[[:space:]]*PLAN\b` case-insensitive |
| `tests/fixtures/diff-sample.patch` | Rule 1    | `code-diff` | `.patch` extension wins before content scan |
| `tests/fixtures/rfc-sample.md` | Rule 4       | `rfc`      | `# RFC:` heading matches `^#[[:space:]]+RFC\b` |
| `plan-sample.md --type=code-diff` | override  | `code-diff` | Override takes precedence over Rule 3 |
| `plan-sample.md --type rfc`    | override     | `rfc`      | Space-separated flag form also accepted |

## Error-Path Verification

All error cases emit `RUN_DIR=ERROR: <reason>` on stdout and exit 1:

| Case                                   | Stdout                                                               |
| -------------------------------------- | -------------------------------------------------------------------- |
| Missing file                           | `RUN_DIR=ERROR: artifact not found: /tmp/does-not-exist.md`         |
| Binary file (`dd if=/dev/urandom`)     | `RUN_DIR=ERROR: binary artifacts not supported in v1`               |
| >100KB text file                       | `RUN_DIR=ERROR: artifact > 100KB (v1 limit)`                        |
| Invalid `--type=foo`                   | `RUN_DIR=ERROR: invalid --type value 'foo' (expected code-diff\|plan\|rfc)` |
| Unknown flag `--nope`                  | `RUN_DIR=ERROR: unknown flag: --nope`                               |
| `--type` with no value                 | `RUN_DIR=ERROR: --type requires value`                              |
| Bare extra positional                  | `RUN_DIR=ERROR: unexpected arg '...'`                               |

## Collision Guard Verification

Two rapid back-to-back runs on the same artifact within the same second:

```
R1=.council/20260422T220005Z-plan-sample
R2=.council/20260422T220005Z-plan-sample-bc70
```

Both directories exist; second run does NOT overwrite the first (T-03-06 mitigated).

## Discretion Calls Made

1. **Slug truncation length:** 40 chars. Rationale: long enough to be human-readable,
   short enough that `<run-dir>/<persona-name>.md` stays under macOS' 255-byte
   filename limit even with 20-char persona names and a 4-hex collision suffix.
2. **Artifact size cap:** 100KB (102400 bytes). Matches research recommendation;
   plan/RFC artifacts are typically under 20KB so this leaves headroom.
3. **Collision suffix length:** 4 hex chars (`od -N2`). Second-collision probability
   ≈ 1/65536 — sufficient for interactive use; tight enough to keep run-dir names
   short.
4. **Nonce length:** 8 hex chars (`od -N4`). Research specified 6-8 hex; we chose
   the upper bound for stronger unguessability against `</artifact>` break-out.
   Fallback path (`openssl rand -hex 4`) also yields 8. Validation range 6-8
   preserved in case future fallbacks differ.
5. **`--type` flag form:** Accept BOTH `--type=X` AND `--type X`. Plan 04 conductor
   can document either form without fear of breakage.
6. **Diagnostics policy:** No stderr diagnostics emitted today. All failures route
   through `err()` which prints the `RUN_DIR=ERROR:` line on stdout (intentional —
   shell-injection captures stdout, so the conductor sees the error in the same
   channel as success). Debug echoes that would leak into Claude's prompt are
   avoided entirely.

## Security Posture (Threat Register Dispositions)

| Threat ID | Disposition | How Mitigated Here                                                 |
| --------- | ----------- | ------------------------------------------------------------------ |
| T-03-01   | mitigate    | All positional args double-quoted; no `eval`; `case`-based parser  |
| T-03-02   | accept (v1) | `cp` follows symlinks; documented for v1.1 `readlink -f` hardening |
| T-03-03   | mitigate    | `file --mime` binary refusal + 100KB size cap before disk write    |
| T-03-04   | mitigate    | SHA computed against snapshot (`$RUN_DIR/INPUT.md`), not source    |
| T-03-05   | mitigate    | All output is the final `RUN_DIR=...` line; no debug echoes        |
| T-03-06   | mitigate    | Directory-exists check + 4-hex suffix                              |
| T-03-07   | mitigate    | Nonce from `/dev/urandom` via `od -N4`; length-validated 6-8 hex   |

## Known Limitations (Carried Forward)

- **Symlink traversal (T-03-02):** `cp` follows symlinks to arbitrary paths. Low
  risk for local user-invoked plugin, but flagged for v1.1 `readlink -f` + CWD
  containment check. README (when written in a later plan) should advise
  workspace-local artifacts.
- **Paths with spaces:** Shell-injection pass-through in `commands/review.md`
  does not preserve quoted arguments reliably; prep script itself handles them
  correctly via `"$@"`. Documented in Plan 03-CONTEXT Open Questions §3.
- **Banned-phrase Unicode homoglyphs:** Out of scope here (validator concern in
  Plan 02); flagged for v1.1 per PITFALLS Pitfall 3.

## Deviations from Plan

None. Plan 03-01 executed exactly as written. Classifier, schema, error paths,
collision guard, nonce generation, and stdout contract all match the `<action>`
block verbatim.

## Verification Evidence

The plan's `<automated>` verify block passed end-to-end:
- `test -x bin/dc-prep.sh` ✓
- `bash -n bin/dc-prep.sh` ✓
- `bin/dc-prep.sh tests/fixtures/plan-sample.md` → `detected_type=plan`, MANIFEST
  parses, nonce 6-8 hex, bytes is number, personas_run is array, `cmp -s` against
  source passes (byte-identical INPUT.md) ✓

All eight `<done>` criteria verified manually in the same session.

## Commit

- `5fb4be8` — `feat(03-01): add bin/dc-prep.sh deterministic artifact-prep script`

## Self-Check: PASSED

- **File exists:** `bin/dc-prep.sh` — FOUND (228 lines, mode 0755)
- **Commit exists:** `5fb4be8` — FOUND on branch `main`
- **MANIFEST schema:** 13 fields emitted (matches v1 interface contract)
- **Classifier:** All 3 fixtures + 2 override forms produce expected `detected_type`
- **Error paths:** 7 error scenarios verified (`RUN_DIR=ERROR:` + exit 1)
- **Collision guard:** Rapid-fire second run produces `-<4-hex>` suffixed dir
- **Byte-identity:** `cmp -s tests/fixtures/plan-sample.md <run>/INPUT.md` passes
