---
phase: 02-codex-output-schema-spike
verified: 2026-04-25
status: passed
score: 7/7 must-haves verified
verifier: gsd-verifier
requirements_coverage: 1/1
overrides_applied: 1
overrides:
  - must_have: ".planning/research/codex-schema-spike-runs.jsonl exists with exactly 21 lines"
    reason: "JSONL and spike-fixtures were lost when executor worktree was force-removed (gitignored files die with the worktree under commit_docs: false). The load-bearing deliverables — verdict, metrics, Phase 6 Wiring Rubric — were captured in the executor's detailed return message and reconstructed into the memo. Phase 6 consumes the memo, not the raw JSONL. Workflow fix documented in 02-01-SUMMARY.md § Deviations for future gitignored-artifact preservation."
    accepted_by: "andy (orchestrator, per verifier escalation context)"
    accepted_at: "2026-04-25T00:00:00Z"
---

# Phase 2: Codex `--output-schema` Spike — Verification Report

**Phase Goal:** Produce a measured GO/NO-GO/WRAPPER memo on whether Codex CLI's `--output-schema` flag is production-ready for Security persona deep scans. Negative result is a valid outcome.

**Verified:** 2026-04-25
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

The phase goal was to produce a measured verdict unlocking or closing Phase 6 scope. The executor ran 21 real `codex-cli 0.122.0` invocations (ChatGPT OAuth) across a 7-item corpus × 3 modes and produced verdict = **WRAPPER** with `validation_rate=0.857`, `latency_ratio=0.635`. The memo captures the verdict, aggregated metrics, four key findings (including the load-bearing "OpenAI strict-mode JSON Schema subset" discovery), and a complete Phase 6 Wiring Rubric with feature-detect + fallback + two error-class definitions. Phase 6 has everything it needs to scope CODX-02/03/04.

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | Tracked v1 Security scorecard schema at `templates/codex-security-schema.json` exists, parses as JSON, conforms to draft-2020-12, declares 6 required fields (target, claim, evidence, ask, severity, category) and severity enum {blocker, major, minor, nit} | VERIFIED | `jq -e .` passes; `$schema: https://json-schema.org/draft/2020-12/schema`; required=`ask,category,claim,evidence,severity,target`; severity enum matches; `python3 -c "jsonschema.Draft202012Validator.check_schema(...)"` prints `schema-ok` |
| 2  | Tracked harness at `scripts/test-codex-schema-spike.sh` exists, is executable, has clean bash syntax, implements 3 modes and the `--output-schema` flag | VERIFIED | `test -x` ok; `bash -n` clean; 3-mode loop (wrapped_no_schema / stripped / with_schema) visible; 6 `--output-schema` references; 324 lines |
| 3  | Memo at `.planning/research/CODEX-SCHEMA-MEMO.md` exists with `verdict: WRAPPER` pinned in frontmatter, plus numeric `validation_rate: 0.857` and `latency_ratio: 0.635` | VERIFIED | Frontmatter contains all three fields; body `## Verdict` section opens `**WRAPPER.**` and cites both numbers against the rubric |
| 4  | Memo contains `## Phase 6 Wiring Rubric` section with feature-detect pattern, fallback path, and error-class definition (`codex_schema_validation_error` + `codex_schema_invalid`) per D-51 extension | VERIFIED | `## Phase 6 Wiring Rubric` heading present; "Feature-detect" probe on `codex --help` grep documented; "Unstructured fallback" section lists three fallback triggers; "Error class additions" subsection defines both error classes with MANIFEST.json enum wiring (CODX-04) |
| 5  | Memo's `## Execution Notes` section documents Wrapped-baseline methodology and the LOWER BOUND caveat on wrapper overhead (verbatim per Task 5 requirement) | VERIFIED | `grep -c 'Wrapped-baseline methodology'` = 1; `grep -c 'LOWER BOUND'` = 1; full D-10 rationale preserved |
| 6  | Memo documents the strict-mode JSON Schema subset finding that motivates the WRAPPER verdict (schema rejected at submit on first run; subset discipline must ship with Phase 6) | VERIFIED | Finding 1 "OpenAI strict structured-outputs has a JSON Schema subset" lists all rejected constructs (oneOf/anyOf/allOf, minLength, format, pattern, default, optional properties); "Schema discipline going forward" subsection codifies the constraint for future milestone schemas |
| 7  | No regression in prior-phase artifacts: `bin/dc-codex-delegate.sh` and `agents/security-reviewer.md` untouched; Phase 1 regression suites still green | VERIFIED | `git log` on both files shows most recent commits predate Phase 2 (9cee750 / 61795e0); `validate-personas.sh` exits 0 (only warn-level W1/W2 noise from legacy personas); `test-shell-inject.sh` 6/6 pass; `test-chair-strictness.sh` 6/6 pass |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `templates/codex-security-schema.json` | v1 Security scorecard schema mirroring scorecard contract (D-03) | VERIFIED | Valid JSON + valid draft-2020-12 schema; 6 required finding fields; strict-mode-compatible (no oneOf/minLength/format/pattern/default per Finding 1); committed in `2971eab` on `main` |
| `scripts/test-codex-schema-spike.sh` | 21-invocation harness: 7 corpus × 3 modes, JSONL emitter | VERIFIED | Executable; `bash -n` clean; 3-mode × 7-item loop; Python-embedded JSON emission; 120s per-run timeout wrapper; committed in `2971eab` on `main` |
| `.planning/research/CODEX-SCHEMA-MEMO.md` | Verdict memo with pinned version, verdict, rubric (D-13) | VERIFIED (reconstructed) | Pinned `codex-cli 0.122.0`; verdict WRAPPER (frontmatter + body agree); Wrapped-baseline methodology + LOWER BOUND present; Phase 6 Wiring Rubric complete; reconstructed from executor return after worktree artifact loss (authoritative data preserved) |
| `.planning/research/codex-schema-spike-runs.jsonl` | 21 raw per-invocation JSONL records | OVERRIDDEN | Lost during `git worktree remove --force --force` cleanup. Aggregated metrics + verdict carried forward in memo. See override in frontmatter; workflow fix documented in SUMMARY § "Workflow Fix Required" |
| `.planning/research/spike-fixtures/*` | 7 corpus prompts + 4 context fixtures + adversarial schema | OVERRIDDEN | Same worktree-cleanup loss path. Corpus is one-shot; not required for Phase 6 decisioning. Re-run cost ~15 min + 21 Codex calls if needed for future debugging |
| `.planning/phases/02-codex-output-schema-spike/02-01-SUMMARY.md` | Plan summary with verdict, deviations, workflow-fix | VERIFIED | Frontmatter carries verdict/metrics; § Deviations documents artifact loss + root cause + recommended orchestrator fix (rsync `--ignore-existing` snapshot before worktree force-remove) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `scripts/test-codex-schema-spike.sh` | `bin/dc-codex-delegate.sh:205` exec shape | `wrapped_no_schema` mode replicates wrapper exec flags verbatim | VERIFIED | Harness inline comment (lines 7-13, 97-99) documents replication; same flag set `--json --sandbox read-only --skip-git-repo-check --ephemeral -o`; deviation from strict D-06 surfaced in memo § Execution Notes |
| `scripts/test-codex-schema-spike.sh` | `templates/codex-security-schema.json` | `with_schema` mode passes `--output-schema` for items 1-6 | VERIFIED | `SCHEMA_V1` var binds to schema path; harness line 311-315 selects v1 for items 1-6, adversarial for item 7 |
| `CODEX-SCHEMA-MEMO.md` verdict | Phase 6 scope gate | Phase 6 Wiring Rubric section | VERIFIED | Rubric section present; verdict WRAPPER unlocks Phase 6 with feature-detect + fallback + 2-error-class design; SC-4 satisfied |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Schema is valid JSON + valid draft-2020-12 | `python3 -c "...Draft202012Validator.check_schema(...)"` | prints `schema-ok` | PASS |
| Harness script syntax valid | `bash -n scripts/test-codex-schema-spike.sh` | exit 0 | PASS |
| Schema validator covers 6 required fields | `jq -r '[.properties.findings.items.required[]] | sort' ...` | `ask,category,claim,evidence,severity,target` | PASS |
| Severity enum matches canonical 4-tier | `jq -r '.properties.findings.items.properties.severity.enum'` | `blocker,major,minor,nit` | PASS |
| Shell-inject regression gate | `bash scripts/test-shell-inject.sh` | 6/6 pass, exit 0 | PASS |
| Chair strictness regression gate | `bash scripts/test-chair-strictness.sh` | 6/6 pass, exit 0 | PASS |
| Persona validator baseline | `bash scripts/validate-personas.sh` | exit 0 (warn-only output) | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CODX-01 | 02-01-PLAN.md | Phase 2 spike produces CODEX-SCHEMA-MEMO.md with 5+ delegation measurements (validation-rate + latency delta) + verdict + rubric | SATISFIED | Memo exists with pinned `codex-cli 0.122.0`, 21 invocations (far exceeds 5+ floor), validation_rate 0.857, latency_ratio 0.635, unambiguous WRAPPER verdict, and complete Phase 6 Wiring Rubric (feature-detect + fallback + 2 error-class definitions) |

### ROADMAP Success Criteria (Phase 2)

| SC | Requirement | Status | Evidence |
|----|-------------|--------|----------|
| SC-1 | Memo exists with pinned `codex --version`, v1 schema at `templates/`, 5+ measured delegations | SATISFIED | Memo at `.planning/research/CODEX-SCHEMA-MEMO.md` pins `codex-cli 0.122.0`; schema at `templates/codex-security-schema.json` committed on main; 21 measured invocations exceed the 5+ floor |
| SC-2 | Unambiguous verdict: GO / NO-GO / WRAPPER | SATISFIED | Verdict = WRAPPER; rubric math: 0.857 in [0.80, 0.95] → WRAPPER (GO requires >0.95); 0.635 < 1.25 satisfies latency but validation-rate dominates; frontmatter + body verdict agree |
| SC-3 | If NO-GO: documented reasons + v1.0 path preserved + CHANGELOG line | N/A | Verdict = WRAPPER, not NO-GO |
| SC-4 | If GO or WRAPPER: Phase 6 Wiring Rubric with feature-detect + fallback + error-class | SATISFIED | Rubric section present with: (a) feature-detect on `codex --help grep --output-schema`, (b) strict-mode pre-check + unstructured fallback on 3 failure modes, (c) two new error classes `codex_schema_validation_error` + `codex_schema_invalid` for D-51 MANIFEST.json extension |

### Anti-Patterns Found

None. The memo is reconstructed but the executor's return message provided authoritative verdict, metrics, and findings that are captured verbatim in the memo body. No TODO/FIXME/placeholder markers in tracked artifacts. No stub implementations in the harness script (324 lines of real Bash + Python logic).

### Gaps Summary

None blocking Phase 2 goal. The only deviation from the plan's must-haves frontmatter is the JSONL + spike-fixture artifact loss from worktree cleanup, which is:

1. Documented in SUMMARY § Deviations with root cause + recommended orchestrator fix
2. Accepted as an override because the load-bearing data (verdict, metrics, Phase 6 rubric) survived via the reconstructed memo
3. Not blocking for Phase 6 scope, which consumes the memo, not the raw JSONL

The workflow fix (rsync snapshot of gitignored `.planning/` artifacts before `git worktree remove --force`) is informational guidance for future spike/memo-producing phases and does not affect Phase 2 goal achievement.

### Human Verification Required

None. All verification was programmatic:

- Tracked artifacts verified via file existence, `jq`/`jsonschema` parsers, and `bash -n` syntax check
- Memo structure verified via `grep` section-heading presence + frontmatter field extraction + value matching
- Git history verified via `git log` + `git branch --contains` showing `2971eab` and `a0ab613` on `main`
- Regression prevention verified by re-running Phase 1 test suites (shell-inject, chair-strictness, persona validation) — all green

The verdict itself was produced by the executor running real Codex invocations; re-running the spike would cost ~15 minutes and 21 Codex calls with no expected verdict change. The memo's reconstructed state is authoritative per the executor's detailed return context.

---

*Verified: 2026-04-25*
*Verifier: Claude (gsd-verifier)*
