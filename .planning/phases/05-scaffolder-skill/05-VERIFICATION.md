---
phase: 05-scaffolder-skill
verified: 2026-04-28T21:46:04Z
status: human_needed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "Invoke /devils-council:create-persona and step through the full wizard (name, tier, primary_concern, objections, banned phrases, examples). Provide >=3 objections, >=5 banned phrases, 2 good + 1 bad examples. Confirm the skill completes and prints cp commands."
    expected: "Wizard completes all 12 steps with AskUserQuestion calls, performs overlap coaching, runs validate-personas.sh, writes workspace files, and prints ready-to-run cp commands."
    why_human: "AskUserQuestion interactive flow cannot be exercised in a headless verification context. The full wizard path requires a live Claude Code session."
  - test: "Invoke /devils-council:create-persona and deliberately provide <3 characteristic objections. Attempt to proceed."
    expected: "Scaffolder blocks with explanation: 'Three is the minimum because two can be coincidence; three forces a pattern.' Re-asks for more objections without writing any files."
    why_human: "Minimum enforcement is declared in SKILL.md prompt text — verifying it actually fires requires running the interactive wizard."
  - test: "Invoke /devils-council:create-persona and enter banned phrases that have >30% overlap with the staff-engineer persona (e.g., 'best practices', 'industry standard', 'modern approach')."
    expected: "Scaffolder warns 'Your banned-phrase set has >30% overlap with staff-engineer (shared: ...)' and asks the user to confirm or diversify before writing."
    why_human: "Overlap coaching fires from within the interactive wizard prompt — cannot verify LLM execution of the python3 overlap script without a live session."
---

# Phase 5: Scaffolder Skill Verification Report

**Phase Goal:** Users can scaffold a schema-valid persona via an interactive `AskUserQuestion`-driven flow that passes `validate-personas.sh` on first run and coaches voice-kit quality beyond schema validity
**Verified:** 2026-04-28T21:46:04Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SKILL.md uses AskUserQuestion for every structured field; refuses to write without >=3 objections, >=5 banned phrases, 2 good + 1 bad examples | VERIFIED | SKILL.md (475 lines): Step 2 (primary_concern), Step 4 (objections >= 3 with explicit re-ask message), Step 5 (banned phrases >= 5 with re-ask), Step 6 (2 good + 1 bad with re-ask). All AskUserQuestion calls verified in structure test suite (16/16 pass). |
| 2 | Scaffolder writes to CLAUDE_PLUGIN_DATA workspace with agents/ and persona-metadata/ as siblings; validate-personas.sh runs before declaring success | VERIFIED | SKILL.md Step 8 creates `${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/agents` and `.../persona-metadata`. Step 9 runs `scripts/validate-personas.sh` via Bash tool with exit-code handling. `scripts/test-persona-scaffolder.sh` Group 1 confirms valid-persona.md (workspace-format fixture) exits 0 from validate-personas.sh. |
| 3 | Heuristics: primary_concern must end with ?, objections checked against own banned_phrases, >30% overlap warns (formerly labeled render-persona.py) | VERIFIED | Per 05-CONTEXT.md line 107: "ROADMAP SC-3 specifies render-persona.py heuristic validator — this is the inline coaching logic (D-05), NOT a separate Python script." All three heuristics in SKILL.md: (1) `must end with ?` (line 113), (2) D-05 cross-check section (lines 226-241), (3) python3 overlap script with >30% threshold (lines 162-224). |
| 4 | test-persona-scaffolder.sh exercises pass case (schema-valid output) and weak-input reject case (field-level error, no write) | VERIFIED | Group 1: valid-persona.md passes validate-personas.sh (exit 0), has >=3 objections, >=5 banned phrases. Group 2: weak-persona.md fails validate-personas.sh (exit 1) with R5 error (1 objection, <3 minimum). Group 3: overlap-persona.md confirms 66% overlap with staff-engineer. All 20 tests pass; harness exits 0 with "TEST SUITE PASSED". |
| 5 | README + CHANGELOG document scaffolder workflow with CLAUDE_PLUGIN_DATA path, install instructions, and v1.2 note | VERIFIED | README: `## Custom Personas` section at line 177 (after Configuration at 150, before Codex Setup at 228) — contains invocation examples, 7-step field list, coaching features, workspace path `${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/`, cp install commands, `/reload-plugins`, v1.2 note. Commands table row added. CHANGELOG `[Unreleased]` contains scaffolder entry referencing SCAF-01 through SCAF-05. |

**Score:** 5/5 truths verified (automated)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `skills/create-persona/SKILL.md` | Interactive scaffolder wizard; min_lines: 150 | VERIFIED | 475 lines; correct frontmatter (name: create-persona, allowed-tools: [AskUserQuestion, Read, Write, Bash, Glob], user-invocable: true, argument-hint: "[persona-slug]") |
| `scripts/test-persona-scaffolder.sh` | Test harness with pass + reject + overlap cases; min_lines: 80 | VERIFIED | 259 lines; executable; 3 test groups; exits 0 with TEST SUITE PASSED |
| `tests/fixtures/scaffolder/valid-persona.md` | Golden-file valid persona (pass case) | VERIFIED | fixture-scaffolder-valid; bench tier, 3 objections, 5 banned phrases, triggers: [new_cloud_resource]; passes validate-personas.sh exit 0 |
| `tests/fixtures/scaffolder/weak-persona.md` | Weak-input persona for reject case | VERIFIED | fixture-scaffolder-weak; 1 objection (R5 fail), 2 banned phrases; fails validate-personas.sh exit 1 with R5 error |
| `tests/fixtures/scaffolder/overlap-persona.md` | High-overlap persona for coaching detection | VERIFIED | fixture-scaffolder-overlap; 66% banned-phrase overlap with staff-engineer (best practices, industry standard) — well above 30% threshold |
| `README.md` | Scaffolder documentation section | VERIFIED | ## Custom Personas section present, contains create-persona |
| `CHANGELOG.md` | v1.1 scaffolder changelog entry | VERIFIED | Under [Unreleased] > ### Added; references SCAF-01 through SCAF-05 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `skills/create-persona/SKILL.md` | `scripts/validate-personas.sh` | Bash tool invocation in Step 9 | WIRED | grep confirms `validate-personas.sh` referenced at lines 349, 379 with Bash tool execution pattern |
| `skills/create-persona/SKILL.md` | `lib/signals.json` | Bash tool jq read in Step 1b | WIRED | `jq -r '.signals \| to_entries[]...'` with `${CLAUDE_PLUGIN_ROOT}/lib/signals.json` at line 74 |
| `skills/create-persona/SKILL.md` | `persona-metadata/*.yml` | Bash tool python3 read in Step 5 | WIRED | `metadata_dir = "${CLAUDE_PLUGIN_ROOT}/persona-metadata"` + `glob.glob(os.path.join(metadata_dir, '*.yml'))` at lines 181-185 |
| `scripts/test-persona-scaffolder.sh` | `scripts/validate-personas.sh` | Direct invocation on fixtures | WIRED | `$VALIDATOR "$VALID" --signals "$SIGNALS"` and `$VALIDATOR "$WEAK" --signals "$SIGNALS"` in Groups 1 and 2 |
| `README.md` | `skills/create-persona/SKILL.md` | Documentation references skill command | WIRED | `/devils-council:create-persona` referenced in ## Custom Personas section and Commands table |

### Data-Flow Trace (Level 4)

Not applicable — SKILL.md is a prompt file (not a component that renders dynamic data). The fixtures are static test inputs, not data-rendering components.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| valid-persona.md passes validate-personas.sh | `./scripts/validate-personas.sh tests/fixtures/scaffolder/valid-persona.md --signals lib/signals.json` | exit 0 | PASS |
| weak-persona.md fails validate-personas.sh with R5 | `./scripts/validate-personas.sh tests/fixtures/scaffolder/weak-persona.md --signals lib/signals.json` | exit 1, output contains R5/characteristic_objections | PASS |
| Harness exits 0 with all 3 groups passing | `bash scripts/test-persona-scaffolder.sh` | "TEST SUITE PASSED" | PASS |
| Structure test exits 0 with 16/16 | `bash scripts/test-scaffolder-skill.sh` | "TEST SUITE PASSED (all 16 tests)" | PASS |
| overlap-persona.md has >30% overlap with staff-engineer | python3 set-intersection (via harness Group 3) | 66% overlap (best practices, industry standard) | PASS |
| Interactive AskUserQuestion wizard end-to-end | Cannot run headlessly | N/A | SKIP (needs human) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SCAF-01 | 05-01-PLAN.md | Interactive scaffolder using AskUserQuestion; 3+ objections, 3+ banned phrases, 2+1 examples; refuses to write without all fields | SATISFIED | SKILL.md enforces >=3 objections, >=5 banned phrases (stricter than SCAF-01's "3+" per ROADMAP SC1), 2 good + 1 bad examples with re-ask on each minimum |
| SCAF-02 | 05-01-PLAN.md | Writes to CLAUDE_PLUGIN_DATA workspace with agents/ and persona-metadata/ siblings | SATISFIED | Step 8 mkdir + Write to `${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/agents` and `.../persona-metadata`; valid-persona.md fixture confirms workspace-format file passes validate-personas.sh |
| SCAF-03 | 05-01-PLAN.md | Runs validate-personas.sh before declaring success; failed validation loops back to field | SATISFIED | Step 9 runs validator; R-code to field mapping table (R1-R8) implemented; 3-retry bail (D-09) implemented |
| SCAF-04 | 05-01-PLAN.md | Coaches voice-rubric distinctness; >30% overlap warns; objections cross-checked against own banned phrases | SATISFIED | D-04 python3 overlap script in Step 5; D-05 cross-check section in Step 5; overlap-persona.md fixture confirms 66% detection works |
| SCAF-05 | 05-02-PLAN.md | README + CHANGELOG document scaffolder workflow | SATISFIED | README ## Custom Personas section (lines 177-227); CHANGELOG [Unreleased] scaffolder entry (line 13) with SCAF-01 through SCAF-05 |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | — | — | No TODO/FIXME/placeholder/empty-return patterns found in SKILL.md or test harness |

### Human Verification Required

#### 1. Full Wizard End-to-End (Happy Path)

**Test:** Open a Claude Code session with the devils-council plugin loaded. Run `/devils-council:create-persona`. Follow all prompts: choose a name (e.g., `latency-hound`), select bench tier, enter a primary concern ending with `?`, list 2-4 blind spots, provide >=3 characteristic objections, provide >=5 banned phrases (including baseline 3), provide 2 good + 1 bad examples, confirm the preview, and let the scaffolder write.
**Expected:** Wizard presents each AskUserQuestion call in sequence. After confirming the preview, wizard creates `${CLAUDE_PLUGIN_DATA}/create-persona-workspace/latency-hound/agents/latency-hound.md`, runs validate-personas.sh (exit 0), splits into agent + sidecar, and prints exact `cp` commands.
**Why human:** AskUserQuestion interactive flow requires a live Claude Code session. The full 12-step execution path through the LLM cannot be exercised by a headless grep-based verification.

#### 2. Minimum Enforcement Block (Reject Path)

**Test:** Run `/devils-council:create-persona`. When prompted for characteristic objections, provide only 2. Attempt to proceed.
**Expected:** Scaffolder responds with the minimum-enforcement message from SKILL.md Step 4 ("Characteristic objections are the strongest voice differentiation signal. Three is the minimum..."), does NOT write any files, and re-presents the AskUserQuestion for objections.
**Why human:** Minimum enforcement logic is LLM-interpreted prompt text in SKILL.md. A grep confirms the text is present but cannot confirm the LLM actually enforces the block versus proceeding anyway.

#### 3. Overlap Coaching (Coaching Path)

**Test:** Run `/devils-council:create-persona`. When prompted for banned phrases, enter `consider`, `think about`, `be aware of`, `best practices`, `industry standard`, `modern approach` (these are the staff-engineer's banned phrases plus baseline).
**Expected:** After entering banned phrases, scaffolder detects >30% overlap with staff-engineer, reports the specific overlapping phrases (`best practices`, `industry standard`, `modern approach`), and asks "Keep as-is" or "Diversify."
**Why human:** Overlap coaching requires the LLM to execute the python3 Bash tool call and then correctly present the AskUserQuestion coaching prompt — requires live session to verify.

---

## Summary

Phase 5 goal achievement is confirmed at the automated verification level:

- All 5 must-have truths are VERIFIED against actual code
- All 7 required artifacts exist and are substantive
- All key links are wired
- Both test suites pass (16/16 structure tests, 20/20 harness tests)
- No anti-patterns in key deliverables

**The `render-persona.py` artifact named in ROADMAP SC3 was not created as a separate file.** This is an intentional design decision documented in 05-CONTEXT.md (line 107): "ROADMAP SC-3 specifies render-persona.py heuristic validator — this is the inline coaching logic (D-05), NOT a separate Python script despite the name." All three heuristics (question-mark enforcement, objection vs. banned-phrase cross-check, overlap detection) are implemented inline in SKILL.md Steps 2, 5, and 5 respectively.

Status is `human_needed` because the interactive AskUserQuestion wizard flow requires a live Claude Code session to verify end-to-end. The three human verification items above must pass before the phase can be marked `passed`.

---

_Verified: 2026-04-28T21:46:04Z_
_Verifier: Claude (gsd-verifier)_
