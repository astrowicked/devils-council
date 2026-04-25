# Phase 1: Tech-Debt Foundation - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Close all 7 tech-debt items from the v1.0 milestone audit (TD-01..07) so Phase 4 (Six Personas + Atomic Conductor Wiring) can safely edit `commands/review.md`, add new `agents/*.md` files without plugin-loader mis-classification, and produce 10-persona Chair synthesis runs without composite-target rejection. Phase 1 ships no new features — it hardens the ground Phase 4 will build on.

**In scope:** TD-01..07 (VERIFICATION/VALIDATION flips, shell-inject dry-run pre-parser, Chair Top-3 strictness, `agents/README.md` rename, README `/plugin marketplace update` docs, CHANGELOG v1.1 entry).

**Out of scope:** Any new persona work (Phase 4), classifier extensions (Phase 3), scaffolder skill (Phase 5), Codex schema work (Phase 2/6).

</domain>

<decisions>
## Implementation Decisions

### TD-04: Shell-inject dry-run pre-parser

- **D-01:** Enforcement = **hard-block** via PreToolUse hook on Write/Edit matching `commands/*.md`. Hook exits 1 on unexpected `!<cmd>` patterns, author must fix or add allowlist entry. Matches existing persona-validator hook pattern so authors recognize the discipline.
- **D-02:** Allowlist = **both file-based and inline marker**.
  - File: `scripts/shell-inject-allowlist.txt` with `<filepath>:<line>:<pattern>` entries — greppable, reviewable in PRs, home for ship-time known-good.
  - Inline marker: `<!-- dc-shell-inject-ok: <reason> -->` comment directly above intentional uses — documents *why* at the occurrence.
  - Parser honors either; CI step asserts allowlist file is not empty without justification and inline markers have non-empty reasons.
- **D-03:** Hook shipping = **default-true `userConfig.shell_inject_guard` flag**. Enabled by default; users can opt out via `userConfig.shell_inject_guard: false`. Matches v1.0's `userConfig.gsd_integration` opt-out convention.
- **D-04:** Parser approach per research (STACK.md §Q3) = ~50-line Python regex + fence-state machine, NOT full Markdown AST. Detects `` !`<cmd>` `` inline AND `` ```! `` fenced opener. Triple-backtick non-`!` fences treated as exemption zones (prose inside a generic code fence ≠ shell-inject).

### TD-05: Chair Top-3 target-field strictness

- **D-05:** Enforcement layer = **prompt + validator backstop** (defense in depth).
  - Chair prompt in `agents/council-chair.md` gets explicit forbidden-language examples: "DO NOT emit composite targets. Good: 'session token storage'. Bad: 'session token storage and refresh rotation'."
  - `bin/dc-validate-synthesis.sh` gains `top3_composite_target` check as regression backstop.
  - Matches v1.0 pattern for banned-phrase discipline (prompt sets direction, validator catches drift).
- **D-06:** Validator regex threshold = **medium strictness**. Rejects:
  - `\s+(and|or)\s+\w+` — catches "A and B", "A or B"
  - `,\s*\w+,\s*\w+` — catches "A, B, C" (3+ comma-separated)
  - **Does NOT reject** `/` (so "client/server", "A/B testing" pass), single commas (so "Foo, the bar" descriptions pass), or `&` (so "Q&A workflow" passes).
- **D-07:** Remediation on validator rejection = **fail synthesis with diagnostic hint**. Exit 1, surface message: `Top-3 entry #N rejected: composite target '<target>'. Chair must name one concept per entry. Re-run or amend.` Silent drop forbidden (matches v1.0 schema-enforced-drop discipline).
- **D-08:** Regression test required — re-run Phase 8 08-UAT known-good Chair synthesis through updated `dc-validate-synthesis.sh` before merge; must still exit 0. Prevents P-08 regression class from PITFALLS.md.

### TD-06: `agents/README.md` → `agents/AUTHORING.md` rename

- **D-09:** Scope = single-file rename + 1-line edit in `scripts/validate-personas.sh:638` (change `README.md` to `AUTHORING.md` in the exclusion case statement) + reference sweep across `.planning/ agents/ scripts/ --include="*.md" --include="*.sh" --include="*.yml"` (grep already confirmed zero external refs exist).
- **D-10:** Post-rename validator check: `claude plugin validate` must still pass; `scripts/validate-personas.sh` must still exclude the renamed file from persona validation (it's authoring docs, not a subagent).

### TD-01/02/03: VERIFICATION / VALIDATION retroactive flips

- **D-11:** Evidence discipline = **hybrid**.
  - **TD-01** (Phase 1 VERIFICATION `human_needed` → `passed`): **liberal** citation — reference v1.0.x release chain (every `/plugin install` since v1.0.0 is a live PLUG-01 test) + 08-UAT.md install/reinstall sign-off. No fresh install run needed.
  - **TD-02** (Phase 4 VERIFICATION `human_needed` → `passed` + 04-HUMAN-UAT.md `partial` → `resolved-by-downstream`): **liberal** citation — 3 pendings (live 4-persona fan-out, blinded-reader, order-swap) are functionally proven by Phase 5+ depending on Phase 4's 4-persona output + Phase 7 PQUAL-03 (blinded-reader ≥80% at 6+ personas) supersedes. Add note: "superseded by Phase 7 UAT scope."
  - **TD-03** (Phase 5 VALIDATION `nyquist_compliant: false` → `true`): **conservative** — actually run `/gsd-validate-phase 5` retroactively. The CI test suite is already green (17/17); re-running the validator is cheap and produces a clean audit artifact for next milestone's audit.
- **D-12:** Citation location = **both**.
  - Edit archived files in place (`.planning/milestones/v1.0-phases/<phase>-VERIFICATION.md` etc.) — they're the source of truth for audit status; flipping them is the actual debt closeout.
  - Also record flip summary in Phase 1 01-SUMMARY.md: "TD-01/02/03 closed with evidence X; citations in archived files." Traceability stays in the v1.1 audit trail.
  - `commit_docs: false` means flips aren't committed anyway; local source-of-truth stays clean.

### TD-07: README `/plugin marketplace update` docs

- **D-13:** Scope = add README "Troubleshooting" subsection documenting that `/plugin marketplace update` must run before `/plugin install` picks up a newer tag. Include the failure symptom ("install shows old version") and the fix. CHANGELOG v1.1 entry explicitly notes this as a new troubleshooting item.

### Phase 1 plan order + parallelization

- **D-14:** Batch structure = **3 batches (smart sequencing)**.
  - **Batch 1 (parallel):** TD-01, TD-02, TD-03, TD-07 — doc-only flips + README/CHANGELOG update. Land in a single commit: `docs(01-batch-1): close TD-01/02/03/07 tracking debt`.
  - **Batch 2 (parallel, after Batch 1 green):** TD-04 (smoke-test fixture → parser → hook wire → CI step) and TD-06 (file rename + validate-personas.sh edit + reference sweep). TD-04 has its own internal gate: smoke-test must exit 0 on clean `commands/review.md` AND exit 1 on v1.0.0 P0 regression fixture before the hook wires in; violating this regresses P-05 prevention.
  - **Batch 3 (isolated):** TD-05 Chair strictness (prompt update + validator regex + regression test). Isolated from TD-04 so any Chair regression is attributable, not confused with pre-parser work.
- **D-15:** Batch 1 ships as one commit; Batches 2 and 3 ship as per-TD commits (separate commits for TD-04/TD-06/TD-05 since code changes merit blame granularity).
- **D-16:** Phase 1 is parallelizable with Phase 2 (Codex spike) at the milestone level — no code dependencies. Can interleave or run Phase 2 in a separate session.

### Claude's Discretion

- Exact regex syntax in `dc-validate-synthesis.sh` for composite-target detection — as long as it honors D-06's medium threshold (reject `and/or/\s*,\s*\w+,`; allow `/`, `&`, single commas).
- Exact directory layout for fixture dirs — `tests/fixtures/shell-inject/` and `tests/fixtures/chair-strictness/` with test runner scripts alongside existing `scripts/test-*.sh` pattern (per v1.0 convention).
- `userConfig.shell_inject_guard` schema entry shape in `.claude-plugin/plugin.json` — mirror existing `userConfig.gsd_integration` structure.
- Exact wording of the Chair prompt's forbidden-language examples (must be explicit but not so verbose it dilutes signal).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1.1 milestone context
- `.planning/REQUIREMENTS.md` — TD-01..07 requirements with success criteria
- `.planning/ROADMAP.md` §Phase 1 — phase goal and success criteria (5 SCs)
- `.planning/research/SUMMARY.md` — synthesis of all 4 research outputs; roadmapper input
- `.planning/research/STACK.md` §Q3 — shell-inject pre-parser design (Python regex + fence-state machine, ~50 LOC)
- `.planning/research/ARCHITECTURE.md` — integration points for TD-04 hook, TD-05 validator, TD-06 rename
- `.planning/research/PITFALLS.md` P-05 (pre-parser bypass culture), P-08 (TD-05 regression on 08-UAT), P-10 (TD-06 reference sweep)

### v1.0 audit + archived phase artifacts (source of truth for TD closeouts)
- `.planning/milestones/v1.0-MILESTONE-AUDIT.md` — authoritative definition of all 7 TD items with `action` field
- `.planning/milestones/v1.0-phases/01-plugin-scaffolding-codex-setup/01-VERIFICATION.md` — file to flip for TD-01
- `.planning/milestones/v1.0-phases/04-remaining-core-personas/04-VERIFICATION.md` — file to flip for TD-02
- `.planning/milestones/v1.0-phases/04-remaining-core-personas/04-HUMAN-UAT.md` — partial → resolved-by-downstream for TD-02
- `.planning/milestones/v1.0-phases/05-council-chair-synthesis/05-VALIDATION.md` — file to flip for TD-03
- `.planning/milestones/v1.0-phases/08-gsd-hook-integration-dig-in-docs-release/08-UAT.md` — evidence source for TD-01/02; Option (b) recommendation for TD-05

### v1.0 code surfaces being modified
- `agents/council-chair.md` — Chair prompt (TD-05 D-05, D-08)
- `agents/README.md` → rename to `agents/AUTHORING.md` (TD-06 D-09)
- `bin/dc-validate-synthesis.sh` — composite-target check to add (TD-05 D-05, D-06, D-07)
- `hooks/hooks.json` — PreToolUse matcher to extend for TD-04 D-01 (currently only matches `agents/*.md`)
- `scripts/validate-personas.sh:638` — exclusion list edit for TD-06 D-09
- `README.md` — troubleshooting section (TD-07 D-13)
- `CHANGELOG.md` — v1.1 entry (TD-07 D-13)
- `.claude-plugin/plugin.json` — `userConfig.shell_inject_guard` schema (TD-04 D-03)

### External refs
- Claude Code docs on PreToolUse hooks + `userConfig` — https://code.claude.com/docs/en/plugins-reference (v1.0 STACK.md already sourced)
- No external specs for TD-01/02/03 (milestone-internal process items)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **PreToolUse hook pattern** in `hooks/hooks.json` — existing matcher for `agents/*.md` → `validate-personas.sh` is the exact template for TD-04's `commands/*.md` → shell-inject parser hook. Copy the `case "$file" in` branch, add a new case.
- **Chair prompt structure** in `agents/council-chair.md` — already has a "Forbidden language (CHAIR-04)" section. TD-05 extends this with composite-target examples; insertion point is clean.
- **`dc-validate-synthesis.sh`** — already has per-check exit-1 pattern with diagnostic stderr messages. Add composite-target check following existing check structure.
- **`userConfig` schema** — v1.0 ships `userConfig.gsd_integration` as the opt-in flag pattern. TD-04's `userConfig.shell_inject_guard` is a direct parallel (same shape, default flipped to true).
- **Fixture directory convention** — `tests/fixtures/injection-corpus/`, `tests/fixtures/classifier-negatives/` already exist. TD-04 and TD-05 fixtures follow same layout: one subdir per regression class, test runner in `scripts/test-<class>.sh`.

### Established Patterns

- **Hard-block > warn** — every v1.0 validator fails loudly (persona schema, scorecard, synthesis, injection corpus). TD-04 follows suit; no new pattern introduced.
- **Prompt + validator defense in depth** — v1.0 banned-phrase list is enforced by both persona prompts (guidance) and `validate-scorecard.sh` (backstop). TD-05 D-05 replicates this for Chair.
- **Regression tests against known-good fixtures** — v1.0 uses `tests/fixtures/contradiction-seed.md` for Chair; TD-05 D-08 adds the 08-UAT Chair output as a known-good regression fixture.
- **`commit_docs: false`** — planning artifacts (including archived phase files) are local-only. Flipping archived VERIFICATION/VALIDATION files is a local edit; no commit required.

### Integration Points

- TD-04 hook extends `hooks/hooks.json` PreToolUse array — same file as persona validator hook. Single bash command, added case branch.
- TD-04 parser lives in `scripts/validate-shell-inject.sh` (new) — invoked by hook AND by new CI step in `.github/workflows/ci.yml`.
- TD-05 validator check extends `bin/dc-validate-synthesis.sh` — no new file; new function or inline check in existing validator.
- TD-06 rename touches `agents/` tree + `scripts/validate-personas.sh:638` + reference-sweep verification.
- TD-07 edits `README.md` + `CHANGELOG.md` — CHANGELOG v1.1 section may not exist yet; D-13 should create it if missing.

</code_context>

<specifics>
## Specific Ideas

- **TD-04 smoke-test gate is load-bearing.** The smoke test MUST exit 0 on current clean `commands/review.md` AND MUST exit 1 on a fixture reproducing the v1.0.0 P0 pattern, BEFORE the hook wires into `hooks/hooks.json`. If the smoke gate is skipped or reversed, we reintroduce the exact class of bug that shipped in v1.0.0. This is the regression proof.

- **TD-05 regression gate is load-bearing.** The updated `dc-validate-synthesis.sh` MUST exit 0 against the Phase 8 08-UAT known-good Chair synthesis before merge. If it doesn't, either the Chair prompt update broke something or the validator regex is too strict — either way, ship-blocker.

- **TD-06's 1-line edit is trivial but do the reference sweep anyway.** Grep confirmed zero external refs today, but before Phase 4 adds 6 new persona files, confirm the sweep result on Phase 1 merge day (another developer may have landed a reference between now and then).

- **TD-01/02 liberal citations are honest because the evidence is real** — every `/plugin install` since v1.0.0 has tested PLUG-01 in production; Phase 5+ depending on Phase 4's output is structural proof of Phase 4 working. The audit itself said this was valid retroactive evidence. Don't over-engineer fresh test runs where release telemetry already answers.

- **TD-03 conservative re-run gives Phase 1 a clean audit artifact.** `/gsd-validate-phase 5` exists, runs fast, and outputs a proper VALIDATION record. Next milestone's audit will thank us.

</specifics>

<deferred>
## Deferred Ideas

- **Fixture directory convention `tests/fixtures/td-regression/`** (Q2.2 option C): considered then rejected for v1.1. Current convention (one subdir per regression class) is the established pattern; introducing a meta-directory is speculative. Revisit if v1.2 surfaces a third regression class.

- **TD-05 pure-prompt enforcement (Q3.1 option B):** considered then rejected. LLM self-enforcement under budget pressure isn't reliable; validator backstop stays.

- **TD-04 warn-only mode (Q1.1 option B):** considered then rejected. Warn-only would have shipped the v1.0.0 P0; we're solving for that exact failure mode.

- **Per-TD-item commits for Batch 1 (Q4.2 option):** considered then rejected for doc-only batch. Revisit if future TD batches have meaningful semantic separation.

- **Strict sequential plan order (Q4.1 option D):** considered then rejected as over-cautious. Batches 1/2/3 respect real dependencies without over-sequencing.

</deferred>

---

*Phase: 01-tech-debt-foundation*
*Context gathered: 2026-04-24*
