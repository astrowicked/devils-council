---
phase: 06-codex-schema-rollout
plan: 01
subsystem: codex-delegation
tags: [codex, schema, structured-output, feature-detect, wrapper]
dependency_graph:
  requires: [templates/codex-security-schema.json, bin/dc-codex-delegate.sh, skills/codex-deep-scan/SKILL.md]
  provides: [lib/codex-schemas/security.json, schema-enforced-delegation, 8-class-error-taxonomy]
  affects: [MANIFEST.json delegation blocks, persona drafts]
tech_stack:
  added: [--output-schema flag (conditional), python3 jsonschema validation (optional)]
  patterns: [feature-detect-before-use, silent-fallback-to-schemaless, non-degrading-error-logging]
key_files:
  created: [lib/codex-schemas/security.json]
  modified: [bin/dc-codex-delegate.sh, skills/codex-deep-scan/SKILL.md]
decisions:
  - Feature-detect via codex --help grep is the sole schema-enable gate; CODEX_VERSION is telemetry-only
  - Strict-mode pre-check uses err() + silent fallback, not write_failure(), because schemaless will succeed
  - codex_schema_invalid catches HTTP 400 at submit; codex_schema_validation_error catches output mismatch post-invoke
  - Section 10 merge checks findings-array format FIRST (more specific) before message-envelope
metrics:
  duration: 284s
  completed: 2026-04-29T00:39:53Z
  tasks_completed: 3
  tasks_total: 3
  files_created: 1
  files_modified: 2
---

# Phase 06 Plan 01: Codex Schema Rollout -- Schema-Enforced Delegation Summary

Schema-enforced Codex delegation via `--output-schema` with feature-detect gate + schemaless fallback, production schema at `lib/codex-schemas/security.json`, two new error classes (codex_schema_invalid, codex_schema_validation_error), and dual-format merge logic handling both findings-array and message-envelope output.

## Tasks Completed

### Task 1: Ship production schema + strict-mode pre-check linter
- **Commit:** 47eb0f2
- **Files:** lib/codex-schemas/security.json (created)
- Copied templates/codex-security-schema.json to lib/codex-schemas/security.json (byte-identical)
- 47-line strict-mode-compatible schema with 6 required finding fields
- jq structural checks verified: top-level `findings` required, 6 per-finding required fields

### Task 2: Wire --output-schema into dc-codex-delegate.sh with feature-detect + fallback + error classes + MANIFEST version capture
- **Commit:** 1ce4aab
- **Files:** bin/dc-codex-delegate.sh (modified, 321 -> 487 lines)
- Section 4b: CODEX_VERSION capture for MANIFEST telemetry (not used in enable decision)
- Section 4c: Schema resolution from lib/codex-schemas/ + feature-detect via `codex --help | grep '--output-schema'`
- Section 4d: Strict-mode pre-check greps schema for 12 disallowed keywords; silent fallback on violation
- Section 6: SCHEMA_ARGS conditionally adds `--output-schema` to all 3 invocation branches (timeout, gtimeout, portable)
- Section 7b: codex_schema_invalid post-check for HTTP 400 on schema submit (non-zero exit + schema in stderr)
- Section 8b: codex_schema_validation_error post-check with Python validator (jsonschema if available, manual fallback otherwise)
- Section 10: Dual-format merge -- findings-array format (schema path) checked first, then message-envelope (schemaless), then direct-text fallback
- MANIFEST success/failure writes both include codex_schema_version and schema_used fields
- Header comment updated: 6 -> 8 error classes with full enum list

### Task 3: Update codex-deep-scan SKILL.md error taxonomy with 2 new classes
- **Commit:** 46c2e35
- **Files:** skills/codex-deep-scan/SKILL.md (modified)
- Added codex_schema_invalid and codex_schema_validation_error rows to Error Taxonomy table
- Updated class count: "six classes" -> "eight classes" (D-11 + CODX-04)
- Added "Schema Enforcement (v1.1 WRAPPER Path)" section documenting the 3 conditions for schema use
- Documented OpenAI strict structured-outputs authoring rules (enum OK, no oneOf/anyOf/allOf, etc.)

## Decisions Made

1. **Feature-detect is sole gate:** `codex --help | grep '--output-schema'` directly tests capability. CODEX_VERSION is captured for MANIFEST reporting but never compared against a minimum version, avoiding brittle semver assumptions.

2. **err() for pre-check, not write_failure():** The strict-mode pre-check failure (section 4d) uses `err()` + silent fallback because the schemaless path will succeed. Using `write_failure()` would write `delegation.status=failed` to MANIFEST, which would be contradicted by the subsequent schemaless success.

3. **Findings-array checked first in merge:** The `isinstance(msg.get("findings"), list)` branch must precede the message-envelope branch because it is the more specific format. Without this ordering, Plan 02 test case 8 would fail.

4. **codex_schema_invalid as write_failure (not silent fallback):** Unlike the pre-check which falls back silently, an HTTP 400 at submit means Codex rejected the schema at runtime -- this is a genuine delegation failure worth recording in MANIFEST.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Added codex_schema_invalid post-check (section 7b)**
- **Found during:** Task 2
- **Issue:** The plan's section C (strict-mode pre-check) catches disallowed keywords before submission, but `codex_schema_invalid` is also described as "HTTP 400 on schema-submit" which happens when Codex itself rejects the schema at runtime. The pre-check alone would not catch all rejection scenarios.
- **Fix:** Added section 7b between sandbox violation check (section 7) and JSON parse check (section 8) to detect schema rejection via non-zero exit code + "schema" in stderr. Uses `write_failure()` since this is a genuine delegation failure.
- **Files modified:** bin/dc-codex-delegate.sh
- **Commit:** 1ce4aab

## Verification Results

All 8 plan verification checks passed:
1. `bash -n bin/dc-codex-delegate.sh` -- syntax OK
2. `diff templates/codex-security-schema.json lib/codex-schemas/security.json` -- byte-identical
3. `grep 'output-schema' bin/dc-codex-delegate.sh` -- present (6 occurrences)
4. `grep 'codex_schema_validation_error' bin/dc-codex-delegate.sh` -- present (3 occurrences)
5. `grep 'codex_schema_invalid' bin/dc-codex-delegate.sh` -- present (4 occurrences)
6. `grep 'codex_schema_version' bin/dc-codex-delegate.sh` -- present (4 occurrences)
7. `grep 'eight classes' skills/codex-deep-scan/SKILL.md` -- present
8. `grep 'isinstance.*findings.*list' bin/dc-codex-delegate.sh` -- present

## Known Stubs

None. All code paths are fully wired -- schema resolution resolves to real files, feature-detect runs real commands, merge logic handles both actual output formats.

## Threat Flags

None. All security-relevant surfaces match the plan's threat model (T-06-01 through T-06-05). No new endpoints, auth paths, or trust boundary crossings introduced beyond what was specified.

## Self-Check: PASSED

- All 3 created/modified files exist on disk
- All 3 task commits verified in git log (47eb0f2, 1ce4aab, 46c2e35)
