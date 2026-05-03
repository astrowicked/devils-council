# Phase 5: Scaffolder Skill - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Interactive `skills/create-persona/SKILL.md` that scaffolds a schema-valid custom persona via `AskUserQuestion`, validates it against `validate-personas.sh`, coaches voice-rubric distinctness, and writes to a `CLAUDE_PLUGIN_DATA` workspace with ready-to-run install commands.

**In scope:** SCAF-01 (interactive scaffolder), SCAF-02 (workspace layout), SCAF-03 (validator integration), SCAF-04 (voice-rubric coaching), SCAF-05 (README + CHANGELOG docs).

**Out of scope:**
- `userConfig.custom_personas_dir` (deferred to v1.2)
- Codex schema rollout (Phase 6)
- Real-artifact UAT (Phase 7)
- Persona authoring (Phase 4 — complete)

**Depends on:**
- Phase 4 (9-persona roster informs scaffolder's calibration examples and overlap targets) — complete
- Phase 4 voice-distinctness validator and adversarial fixture design inform coaching heuristics — complete

</domain>

<decisions>
## Implementation Decisions

### Question flow design

- **D-01:** Linear wizard — field-by-field in fixed order: name → tier → primary_concern → characteristic_objections → banned_phrases → worked examples (good + bad). Each step is one `AskUserQuestion` call. Matches `agents/AUTHORING.md` order and PERSONA-SCHEMA.md field sequence.
- **D-02:** End preview only — collect all fields, then show the full agent file + sidecar before writing. One confirmation point. No progressive preview.
- **D-03:** Suggest from existing data — show available signal IDs from `lib/signals.json` for triggers, show baseline banned phrases as starting point to extend, show existing persona primary_concerns as negative examples to avoid duplication. Helps user without constraining.

### Voice coaching depth

- **D-04:** Warn with comparison on overlap — when user's banned-phrase set has >30% overlap with a shipped persona, show which phrases overlap, name the conflicting persona, explain why differentiation matters, then ask: "Keep these or diversify?" User decides. Non-blocking. Matches Phase 4 D-09 warn-mode policy.
- **D-05:** Inline coaching on objection quality — if a characteristic_objection contains one of the persona's own banned phrases, flag it immediately: "Your objection uses a phrase you banned — rephrase?" Catches contradictions before validation. Matches ROADMAP SC-3 `render-persona.py` heuristic requirement.

### Workspace & install UX

- **D-06:** Print ready-to-run commands after writing — display exact `cp` or `mv` commands the user can paste to move files from `${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/` to their plugin directory. Clear, explicit, no magic. User has full control over timing.
- **D-07:** Persistent workspace by slug — workspace persists across runs. User can re-run scaffolder to refine an existing persona. If slug already exists, prompt for overwrite confirmation before proceeding.

### Validation loop behavior

- **D-08:** Translated guidance on validation failure — scaffolder interprets `validate-personas.sh` error codes (R1-R9, W1-W3) into plain-English guidance: "Your primary_concern must end with a question mark (R5)". Maps each error to the specific field question to loop back to.
- **D-09:** 3 retries then bail — three attempts to fix validation errors by looping back to the relevant question. After 3 failures, write the persona anyway with a warning and let the user fix manually. Prevents infinite loops.

### Claude's Discretion

- Exact wording of AskUserQuestion option labels and descriptions
- Order of suggestions presented for triggers and banned phrases
- Whether to show all 16 existing persona concerns at once or filter to same-tier personas only
- Format of the end-preview (markdown table vs rendered file content)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Persona schema and authoring
- `skills/persona-voice/PERSONA-SCHEMA.md` — authoritative frontmatter schema for agents/*.md files; every field name, required rule, and validator check
- `skills/persona-voice/SKILL.md` — tone rubric, voice kit discipline, worked-example requirements
- `skills/scorecard-schema/SKILL.md` — output contract personas target; scaffolder must teach this shape in examples
- `agents/AUTHORING.md` — manual authoring guide the scaffolder automates; field order and required reading list

### Validation and voice quality
- `scripts/validate-personas.sh` — the validator to run against scaffolder output; R1-R9 hard rules + W1-W3 soft warnings
- `lib/signals.json` — signal registry; bench persona triggers must reference IDs from this file

### Existing sidecars (overlap comparison targets)
- `persona-metadata/*.yml` — all 16 existing sidecars; scaffolder compares user's banned_phrases against these for overlap coaching

### Plugin conventions
- `CLAUDE.md` §"Directory Layout" — where skills live, `${CLAUDE_PLUGIN_DATA}` expansion rules
- `.claude-plugin/plugin.json` — plugin manifest; scaffolder skill auto-registers via `skills/` directory convention

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/validate-personas.sh` — run against scaffolder output to verify schema compliance; exit 0 = pass, exit 1 = hard fail with error codes
- `skills/persona-voice/PERSONA-SCHEMA.md` — field definitions the scaffolder's questions map to 1:1
- `lib/signals.json` — signal IDs the scaffolder should present as trigger options for bench-tier personas
- 16 `persona-metadata/*.yml` files — overlap comparison set for voice coaching

### Established Patterns
- Skills live in `skills/<name>/SKILL.md` with optional supporting files in the same directory
- `AskUserQuestion` is the first-party tool for interactive input (used throughout GSD workflows)
- `${CLAUDE_PLUGIN_DATA}` expands to a persistent per-plugin data directory managed by Claude Code

### Integration Points
- Scaffolder output must produce `agents/<slug>.md` + `persona-metadata/<slug>.yml` in a sibling layout so `validate-personas.sh` sidecar resolution works unchanged
- README.md needs scaffolder workflow documentation
- CHANGELOG needs v1.1 entry listing scaffolder as new capability

</code_context>

<specifics>
## Specific Ideas

- ROADMAP SC-1 specifies minimum field counts: ≥3 characteristic objections, ≥5 banned phrases, 2 good-finding + 1 bad-finding worked examples. Scaffolder must refuse to write without all fields meeting minimums.
- ROADMAP SC-3 specifies `render-persona.py` heuristic validator — this is the inline coaching logic (D-05), NOT a separate Python script despite the name. Implement as validation logic within the SKILL.md prompt.
- ROADMAP SC-4 specifies scripted-input pass AND weak-input reject test cases for `test-persona-scaffolder.sh`.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-scaffolder-skill*
*Context gathered: 2026-04-28*
