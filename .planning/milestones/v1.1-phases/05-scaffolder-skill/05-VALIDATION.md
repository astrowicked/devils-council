---
phase: 5
slug: scaffolder-skill
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-28
updated: 2026-04-28
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Shell (bats-core pattern via plain bash test scripts) |
| **Config file** | none — uses existing `scripts/validate-personas.sh` + `scripts/test-persona-scaffolder.sh` + `scripts/test-scaffolder-skill.sh` |
| **Quick run command** | `bash scripts/validate-personas.sh agents/<slug>.md --signals lib/signals.json` |
| **Full suite command** | `bash scripts/test-persona-scaffolder.sh && bash scripts/test-scaffolder-skill.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/validate-personas.sh` on any modified persona files
- **After every plan wave:** Run `bash scripts/test-persona-scaffolder.sh`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | SCAF-01 | integration | `bash scripts/test-persona-scaffolder.sh` (Group 1: pass case) | ✅ | ✅ green |
| 05-01-02 | 01 | 1 | SCAF-02 | structure | `bash scripts/test-scaffolder-skill.sh` (Test 10: workspace path) | ✅ | ✅ green |
| 05-01-03 | 01 | 1 | SCAF-03 | integration | `bash scripts/test-persona-scaffolder.sh` (Group 1: validates via validate-personas.sh) | ✅ | ✅ green |
| 05-01-04 | 01 | 1 | SCAF-04 | unit | `bash scripts/test-persona-scaffolder.sh` (Group 3: overlap detection) | ✅ | ✅ green |
| 05-02-01 | 02 | 2 | SCAF-01 | integration | `bash scripts/test-persona-scaffolder.sh` (Group 2: reject case) | ✅ | ✅ green |
| 05-02-02 | 02 | 2 | SCAF-05 | manual | `grep "## Custom Personas" README.md` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `scripts/test-persona-scaffolder.sh` — test harness with pass-case + reject-case + overlap-check (3 groups, 20 assertions)
- [x] `scripts/test-scaffolder-skill.sh` — structure tests for SKILL.md (16 tests)
- [x] Golden fixture files: `tests/fixtures/scaffolder/{valid,weak,overlap}-persona.md`

*Note: `validate-personas.sh` already exists and covers R1-R9, W1-W3 rules.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| AskUserQuestion wizard flow completes interactively | SCAF-01 | AskUserQuestion has no scripted-input mode; requires live Claude Code session | 1. Run `/devils-council:create-persona` 2. Enter "test-reviewer" as name 3. Complete all fields with valid data 4. Verify end-preview displays before write 5. Verify workspace files exist |
| Inline coaching flags banned-phrase contradiction | SCAF-04, D-05 | Requires human interaction to trigger coaching response | 1. Enter a banned phrase ("consider") as part of a characteristic_objection 2. Verify scaffolder flags the contradiction immediately 3. Verify re-ask prompt appears |
| Workspace persistence and overwrite prompt | D-07 | Requires running scaffolder twice with same slug | 1. Run scaffolder with slug "test-dup" 2. Complete and write 3. Run scaffolder again with "test-dup" 4. Verify overwrite confirmation appears |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-04-28

## Validation Audit 2026-04-28

| Metric | Count |
|--------|-------|
| Requirements covered | 5 (SCAF-01 through SCAF-05) |
| Automated tests | 36 (20 scaffolder + 16 structure) |
| Manual-only items | 3 (interactive wizard flow) |
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |
