---
phase: 08-gsd-hook-integration-dig-in-docs-release
plan: 03
subsystem: dig-command
tags: [dig, resp-02, phase-8, scorecard-preload, ephemeral-command]
dependency-graph:
  requires: [08-02, 05-council-chair-synthesis]
  provides: [RESP-02]
  affects: [commands/, scripts/, tests/fixtures/, .github/workflows/ci.yml]
tech-stack:
  added: []
  patterns:
    - "portable `ls -td */` directory listing (BSD + GNU)"
    - "case/esac path-traversal rejection BEFORE filesystem access"
    - "grep -qE regex validation for slash-command arg allowlist"
    - "static-grep CI assertion for ephemeral invariant"
key-files:
  created:
    - commands/dig.md
    - scripts/test-dig-spawn.sh
    - tests/fixtures/dig-spawn/latest-run/staff-engineer.md
    - tests/fixtures/dig-spawn/latest-run/MANIFEST.json
  modified:
    - .github/workflows/ci.yml
decisions:
  - "Persona regex ^[a-z][a-z-]*$ (rejects uppercase, digits, underscores, path separators) — matches existing agents/*.md slug pattern"
  - "Run-id rejection case pattern */*|*..*|.* runs BEFORE any filesystem access (T-08-04)"
  - "`latest` sentinel uses `ls -td */ | head -1` inside `cd .council/` — portable BSD + GNU; responses.md file excluded automatically (trailing-slash glob matches only dirs)"
  - "Ephemeral invariant enforced structurally: static grep for MANIFEST-write patterns + hash-stable fixture MANIFEST check in test harness"
  - "Agent prompt template explicitly instructs persona to NOT re-critique the artifact; redirects artifact questions to /devils-council:review"
  - "No changes to commands/review.md — dig is a standalone command with its own lifecycle"
metrics:
  duration-sec: ~900
  tasks: 2
  commits: 2
  files-created: 4
  files-modified: 1
  test-assertions: 27
  completed-date: 2026-04-24
---

# Phase 08 Plan 03: Dig-In Interactive Follow-Up Summary

`/devils-council:dig <persona> <run-id|latest> [question]` ships — single-`Agent()` scorecard-preload follow-up command with regex-guarded persona + case/esac path-traversal defense + portable `latest` sentinel resolution, backed by 27-assertion test harness wired into CI.

## Plan Objective

Close RESP-02: enable users to drill into a persona's prior scorecard without re-running the full council. Per CONTEXT.md D-78, dig is scorecard-preload not artifact-re-review — one Agent() call, no fan-out, no Chair, no MANIFEST writes.

## What Shipped

### 1. `commands/dig.md` (RESP-02)

Frontmatter: `name: dig`, `argument-hint: "<persona> <run-id|latest> [question...]"`, `allowed-tools: [Bash, Read, Agent]`.

Four shell-injection blocks (run before the prompt reaches Claude):

1. **Parse and validate arguments** — extracts persona/run-id/question from `$ARGUMENTS`, validates persona matches `^[a-z][a-z-]*$` (regex rejects uppercase, digits, underscores, path separators), runs `case/esac` rejecting `*/*`, `*..*`, `.*` on run-id BEFORE any filesystem access.
2. **Resolve run-id** — handles `latest` sentinel via `cd .council && ls -td */ | head -1 | sed 's:/$::'` (portable BSD + GNU; responses.md is a file, excluded automatically by the `*/` trailing-slash glob). Validates `.council/<RUN_ID>/` exists and contains `<persona>.md`; emits available-scorecards listing on miss.
3. **Load scorecard content** — re-validates inputs (defense-in-depth; each shell block is independent), quotes all variables, `cat`s the scorecard for preload.
4. **Spawn follow-up agent** — instructs Claude to use the `Agent` tool with `subagent_type=<persona>` and a prompt template wrapping the scorecard in `<previous-scorecard>` tags, embedding the user's question in `<user-question>` tags, with an explicit "Do NOT re-critique the underlying artifact" directive.

Ephemeral contract encoded in prose ("No new run dir", "No MANIFEST writes", "No Chair spawn", "No fan-out").

### 2. `tests/fixtures/dig-spawn/latest-run/`

- **`staff-engineer.md`** — scorecard fixture with valid Phase 5 D-38 finding ID format (`staff-engineer-a3f2c1d8`) and the full frontmatter shape (persona / run_id / findings[] with id/severity/category/target/claim/evidence/ask).
- **`MANIFEST.json`** — stable-content fixture used for the ephemeral-invariant hash check.

### 3. `scripts/test-dig-spawn.sh` — 27/27 PASS

Covers all 5 RESP-02 paths:

| Path | Assertions | What it proves |
|------|-----------|----------------|
| 1 | 3 | `latest` resolves to newest subdir; responses.md file excluded from candidates |
| 2 | 2 | Literal run-id directory-match works; bogus run-id rejected |
| 3 | 2 | Missing-scorecard detected; dig.md prose lists available-scorecards |
| 4 | 12 | Path-traversal rejected (`../etc/passwd`, `a/b`, `.hidden`, `..`, `foo..bar`) + persona-regex rejection (uppercase, underscore, digits, empty, path-traversal) |
| 5 | 4 | MANIFEST hash stable; static-grep confirms no `> MANIFEST.json` or `jq…>MANIFEST.json` write patterns in dig.md |
| static | 3 | persona regex pattern present; `Do NOT re-critique` text present; fixture finding ID matches D-38 format |

Harness builds a sandbox `.council/` tree under `mktemp -d`, exercises the exact shell logic from `commands/dig.md` (not the slash command itself — CI has no Claude session), and cleans up via `trap`.

### 4. `.github/workflows/ci.yml`

One new step `Run dig-spawn test (Phase 8 RESP-02)` added AFTER `Run on-plan / on-code wrapper test` and BEFORE `Confirm no settings.json hijack (PLUG-05)`. Existence-gated per Phase 7 pattern — skips gracefully if harness or fixture absent.

Verified step ordering via `grep -nE 'on-plan / on-code|dig-spawn|settings\.json hijack' .github/workflows/ci.yml | sort -n`:
```
231: Run on-plan / on-code wrapper test
243: Run dig-spawn test
257: Confirm no settings.json hijack
```

## Commits

| Hash | Message |
|------|---------|
| `7ac174f` | `feat(08-03): add commands/dig.md for interactive follow-up (RESP-02)` |
| `d89d50e` | `test(08-03): add test-dig-spawn.sh + fixture + CI step (Phase 8 RESP-02)` |

## Key Decisions

1. **Persona regex `^[a-z][a-z-]*$`** (Task 1) — rejects all path-traversal metacharacters structurally. Matches the existing `agents/*.md` slug convention (every shipped persona is lowercase + hyphens). Error message lists available personas from `${CLAUDE_PLUGIN_ROOT}/agents/` for self-recovery.

2. **Run-id case/esac BEFORE filesystem access** (Task 1, T-08-04 mitigation) — three patterns block the traversal classes: `*/*` (slashes), `*..*` (parent-dir refs, including bare `..` and embedded like `foo..bar`), `.*` (leading dot / hidden names). Re-applied in every shell block (each `!` block runs in its own shell; can't assume state from prior blocks).

3. **Portable `latest` sentinel** (Task 1) — `cd .council && ls -td */` works identically on macOS BSD and Linux GNU. The trailing-slash `*/` glob matches only directories, so `.council/responses.md` (a file from Phase 7 D-69) is excluded automatically. `sed 's:/$::'` strips the trailing slash.

4. **Ephemeral invariant enforced by grep + hash** (Task 2) — two defenses:
   - Static grep in `scripts/test-dig-spawn.sh` rejects `MANIFEST\.json[^"]*>[^&]` and `jq[^|]*>[[:space:]]*[^[:space:]]*MANIFEST\.json` patterns in `commands/dig.md`
   - Fixture MANIFEST.json hashed before/after test body; equality asserted
   The proxy check catches any future regression where someone adds a MANIFEST-write to dig's flow.

5. **No modification to `commands/review.md`** — dig is a fully-standalone command. It does not delegate to review (`on-plan` and `on-code` do); it spawns a single `Agent()` with its own prompt template. Plan 07 + earlier lockdowns preserved byte-for-byte.

## Threat Model Disposition

All 5 threats from plan frontmatter T-08-04{a..e} mitigated or accepted:

| Threat | Status | Evidence |
|--------|--------|----------|
| T-08-04 (persona/run-id arg injection) | mitigated | Persona regex + run-id case/esac BEFORE FS access |
| T-08-04b (files outside .council/) | mitigated | Run-id hardening means `.council/$RUN_ID/` is always a direct child |
| T-08-04c (sibling scorecard listing) | accepted | User's own prior output; not cross-tenant |
| T-08-04d (prompt injection via scorecard) | accepted | Scorecard passed Phase 3 validator + Phase 7 banned-phrase filter before being written; `<previous-scorecard>` XML framing signals context |
| T-08-04e (accidental run-dir creation) | mitigated | Static grep in test harness + prose explicitly enumerates "Do NOT" |
| T-07-04-inherit (dismissal bypass) | accepted | Dig is read-only w.r.t. `.council/responses.md`; Phase 7 mitigation remains sole defense |

## Deviations from Plan

None — plan executed exactly as written. The task `action` blocks in 08-03-PLAN.md prescribed the file contents almost verbatim; the only additions during execution were:

1. **Enriched Path-4 persona-regex assertions in test harness** (Rule 2 — add missing critical functionality). The plan's acceptance criteria required the persona regex to be present in `dig.md` but did not specify test coverage for persona-regex rejection. Added 7 assertions covering accept/reject cases (uppercase, underscore, digits, empty, path-traversal) to match the T-08-04 mitigation claim in the threat model. Not a deviation in behavior — just proving the mitigation via test.

2. **Duplicate `jq>MANIFEST.json` static-grep** (Rule 2) — added alongside the redirect static-grep because a `jq` write is the canonical MANIFEST-write idiom used everywhere else in the plugin. Two patterns = two independent structural checks.

## Authentication Gates

None encountered. All automation completed without user action.

## Deferred Issues

None. All plan success criteria met.

## Test Harness Results

```
$ ./scripts/test-dig-spawn.sh
PASS: Path1 latest resolves to newest subdir
PASS: Path1 latest excludes responses.md file
PASS: Path1 responses.md is a file (not candidate)
PASS: Path2 literal match: valid run-id resolves
PASS: Path2 bogus run-id rejected
PASS: Path3 missing-scorecard detected
PASS: Path3 dig.md lists available scorecards on error
PASS: Path4 rejects ../something (dot-dot-slash)
PASS: Path4 rejects a/b (slash)
PASS: Path4 rejects .hidden (leading dot)
PASS: Path4 rejects bare .. (dot-dot)
PASS: Path4 rejects foo..bar (embedded dot-dot)
PASS: Path4 accepts normal run-id
PASS: Path4 accepts latest sentinel
PASS: Path4 persona: accepts staff-engineer
PASS: Path4 persona: accepts security-reviewer
PASS: Path4 persona: rejects Staff-Engineer (uppercase)
PASS: Path4 persona: rejects staff_engineer (underscore)
PASS: Path4 persona: rejects ../etc (path traversal)
PASS: Path4 persona: rejects 2-letter-digit (digit)
PASS: Path4 persona: rejects empty
PASS: Path5 MANIFEST hash unchanged (ephemeral)
PASS: commands/dig.md has no write-to-MANIFEST redirect pattern
PASS: commands/dig.md has no jq>MANIFEST write pattern
PASS: persona regex [a-z][a-z-]* present
PASS: no-re-critique instruction present
PASS: fixture finding ID matches Phase 5 D-38 format
---
test-dig-spawn: 27 passed, 0 failed
```

Prior suites spot-checked green:
- `scripts/test-hooks-gsd-guard.sh` → PASS
- `scripts/test-on-plan-on-code.sh` → PASS
- `scripts/test-validate-personas.sh` → PASS

`claude plugin validate .` → `✔ Validation passed`.

## Files Touched

| File | Change |
|------|--------|
| `commands/dig.md` | CREATED — 149 lines, slash-command markdown with 3 shell-injection blocks + Agent() spawn prompt template |
| `tests/fixtures/dig-spawn/latest-run/staff-engineer.md` | CREATED — scorecard fixture with D-38 finding ID |
| `tests/fixtures/dig-spawn/latest-run/MANIFEST.json` | CREATED — fixture MANIFEST for ephemeral-invariant hash check |
| `scripts/test-dig-spawn.sh` | CREATED — 225 lines, executable, 27-assertion harness |
| `.github/workflows/ci.yml` | MODIFIED — +14 lines, new existence-gated CI step after on-plan/on-code step |

No other files touched. `commands/review.md` byte-identical to pre-plan state.

## Confirmation: commands/review.md NOT Modified

```
$ git diff 002d65a..HEAD --name-only | grep -E 'review\.md|on-plan\.md|on-code\.md'
(no output — confirmed)
```

The three Phase 8 conductor-delegation commands (review.md, on-plan.md, on-code.md) are byte-identical to their Wave 2 / Phase 7 state. Plan 08-03 adds a standalone command (dig.md) + test harness + fixture + one CI step, without touching the existing review/synthesis/render pipeline.

## Self-Check: PASSED

**Files verified:**
- FOUND: commands/dig.md
- FOUND: scripts/test-dig-spawn.sh
- FOUND: tests/fixtures/dig-spawn/latest-run/staff-engineer.md
- FOUND: tests/fixtures/dig-spawn/latest-run/MANIFEST.json
- FOUND: .github/workflows/ci.yml (modified — `Run dig-spawn test` step present at line 243)

**Commits verified:**
- FOUND: 7ac174f (feat 08-03 dig.md)
- FOUND: d89d50e (test 08-03 dig-spawn + CI)

All plan success criteria satisfied; all acceptance criteria from both task verify blocks PASS.
