---
phase: 03-one-working-persona-end-to-end-review-engine-core
plan: 03
subsystem: persona
tags: [persona, staff-engineer, agent-file, core-01, voice-kit]
requires:
  - skills/persona-voice/SKILL.md        # preloaded by frontmatter `skills:`
  - skills/persona-voice/PERSONA-SCHEMA.md # R1-R8 + W1-W3 compliance
  - skills/scorecard-schema/SKILL.md     # preloaded; defines finding shape
  - templates/SCORECARD.md               # draft file shape
  - scripts/validate-personas.sh         # hard-gate validator (exit 0)
  - tests/fixtures/plan-sample.md        # good example 1 evidence source
  - tests/fixtures/diff-sample.patch     # good example 2 evidence source
provides:
  - agents/staff-engineer.md             # first real CORE-01 persona subagent
affects:
  - Phase 4 (plans add SRE, PM, Devil's Advocate personas — copy this file as the template)
  - Phase 3 Plan 02 (conductor-side validator tests banned-phrase drops against this persona's list)
  - Phase 3 Plan 04 (conductor-side evidence verbatim check uses this persona's examples as positive cases)
tech-stack:
  added: []     # no new runtime deps; persona is a markdown file
  patterns:
    - value-system-anchor prose (not role-label prose) per PITFALLS §13
    - file-based subagent handoff ($RUN_DIR/staff-engineer-draft.md) per 03-RESEARCH Pattern 2
    - negative few-shot (1 bad example) for generation-time banned-phrase avoidance
key-files:
  created:
    - agents/staff-engineer.md
  modified: []
decisions:
  - Body paragraph uses value-system prose only (no job-description framing) — the PITFALLS §3 / §13 defense
  - Included all six D-13 banned phrases verbatim (consider, think about, be aware of, best practices, industry standard, modern approach); no role-specific additions in this pass — keeps the phrase set stable across Phase 4 personas for easier cross-persona drift checks
  - Good example 1 cites "## Risks" as target (the heading above the flag mention) but evidence quotes the Approach-section line; keeps target anchored to a plan structural element while evidence is the verbatim substring the validator will match
  - Good example 2 omits the diff `+` prefix from evidence (per plan comment on validator whitespace normalization); grep -F confirmed the stripped line is present in diff-sample.patch so runtime substring check will still pass
  - Bad example concentrates four banned phrases in one finding (consider, think about, be aware of, best practices) plus missing evidence — a single ultra-clear negative teaches the subagent more than a subtle one
metrics:
  duration: "~10 minutes"
  completed: "2026-04-22T22:00:24Z"
  tasks_total: 1
  tasks_completed: 1
  files_created: 1
  files_modified: 0
  commits: 1
---

# Phase 3 Plan 03: Staff Engineer Persona Summary

**One-liner:** Authored `agents/staff-engineer.md` — the first real CORE-01 persona subagent — with the full D-13 voice kit, file-based handoff contract to `$RUN_DIR/staff-engineer-draft.md`, and worked examples grounded verbatim in Phase 2's `plan-sample.md` and `diff-sample.patch` fixtures, clearing `scripts/validate-personas.sh` with exit 0 and zero soft warnings.

## What was built

One markdown file, 87 lines, `agents/staff-engineer.md`. It contains:

1. **Frontmatter** — `name`, `description` (<300 chars per STACK.md `SLASH_COMMAND_TOOL_CHAR_BUDGET` guidance), `tools: [Read, Grep, Glob]`, `model: inherit`, `skills: [persona-voice, scorecard-schema]`, `tier: core`, plus the full voice kit verbatim from D-13 (primary_concern, blind_spots ×3, characteristic_objections ×3, banned_phrases ×6, tone_tags ×3).
2. **Value-system anchor paragraph** — 6 sentences, second-person, no hedging, no catchphrases. Opens with "You reduce the surface area of the artifact in front of you." Leads with what the persona optimizes for, not what the persona *is*.
3. **`## How you review`** — 5 bullets covering: read only INPUT.md, cite verbatim ≥8 chars, phrase `claim`/`ask` without banned phrases (but `evidence` may quote them), severity enum + restraint on `blocker`, empty-findings acceptance.
4. **`## Output contract`** — Single paragraph naming the draft file path (`$RUN_DIR/staff-engineer-draft.md`), citing `templates/SCORECARD.md` for shape, and explicitly prohibiting self-write-of-final and self-validation. Enforces file-based handoff per D-15 single-pass architecture.
5. **`## Examples`** — Two good findings (one per Phase 2 fixture) + one bad finding concentrating four banned phrases and missing evidence.
6. **Closing one-liner** — "If the artifact survives your review, say so plainly. Silence is acceptable. Flattery is not."

## Examples grounding

| Example | Fixture | Verbatim evidence substring | grep -F match |
|---------|---------|----------------------------|---------------|
| Good 1  | `tests/fixtures/plan-sample.md` | `` Feature-flag via `RATE_LIMIT_ENABLED=true`. `` | ✓ confirmed |
| Good 2  | `tests/fixtures/diff-sample.patch` | `expiresAt: now + 24 * 3600_000, // bumped from 1h to 24h per product request` | ✓ confirmed (diff `+` prefix ignored by `grep -F` line-contains; runtime validator's whitespace normalization policy per Pitfall 2 handles this) |
| Bad     | n/a | (deliberately absent — that's what makes it bad) | N/A |

Both good examples pass the future runtime evidence-substring check (ENGN-05). The bad example is a negative few-shot: it concentrates `consider`, `think about`, `be aware of`, and `best practices` across its `claim` and `ask` fields, and omits any `evidence:`. The persona learns at generation time what the validator would drop at review time.

## Discretion calls

- **Tone-tags kept to three** (`terse, deadpan, asks-one-sharp-question`) — D-13 mandates these three verbatim; no additions.
- **Banned-phrases kept to D-13's six** — did not add Staff-Engineer-specific bans (e.g. "best practice", "scalable", "robust") in this pass. Keeping the list stable across Phase 4 personas makes cross-persona drift easier to detect. Flag for Phase 4 authors: if they want persona-specific bans, add them per persona file, not to a shared base list.
- **Closing one-liner included** — optional per STEP 6 of the task action; kept because it reinforces the "empty findings OK, flattery not OK" discipline the `How you review` bullets establish.
- **Target strings in examples** — Good 1 target is `"## Risks"` (the Risks section heading in plan-sample.md), not the Approach heading where the evidence line actually lives. Rationale: target is meant to anchor the critique to a structural element of the artifact; evidence is the specific line. The two don't have to point at the same heading. Good 2 target is `"src/auth/session.ts:11"` — line-reference style per scorecard-schema's "line reference OR quote anchor" rule.
- **File length** — 87 lines, well under agents/README.md's ~200 line guidance and the plan's ~150 line guidance.

## Validator output

```
$ bash scripts/validate-personas.sh agents/staff-engineer.md
exit=0
```

**Soft warnings (W1/W2/W3):** none.
- W1 (missing baseline bans): clean — all three baseline bans present.
- W2 (missing `## Examples`): clean — section present with 2 good + 1 bad finding.
- W3 (forbidden keys `hooks`/`mcpServers`/`permissionMode`): clean — none present.

```
$ bash scripts/validate-personas.sh    # whole agents/ directory
exit=0
```

## Deviations from Plan

None — plan executed exactly as written. No Rule 1-3 auto-fixes triggered; no Rule 4 architectural question reached. The task action's STEP 1-6 were followed verbatim, with discretion calls documented above.

## Self-Check: PASSED

Verified:
- [x] `agents/staff-engineer.md` exists (87 lines)
- [x] Validator exits 0 on the new file
- [x] Validator exits 0 on the whole `agents/` directory
- [x] All D-13 frontmatter values present verbatim (confirmed by `awk` extraction)
- [x] `## Examples` H2 present (clears W2)
- [x] Good example 1 evidence `` `Feature-flag via `RATE_LIMIT_ENABLED=true`.` `` is a substring of `tests/fixtures/plan-sample.md` (confirmed by `grep -F`)
- [x] Good example 2 evidence is a substring of `tests/fixtures/diff-sample.patch` (confirmed by `grep -F`)
- [x] Bad example contains four banned phrases (`consider`, `think about`, `be aware of`, `best practices`)
- [x] File contains the string `staff-engineer-draft.md` (file-based handoff contract per D-15)
- [x] File contains `$RUN_DIR` placeholder (conductor substitutes at invocation time)
- [x] No `hooks:` / `mcpServers:` / `permissionMode:` keys (W3 clean)
- [x] Commit `834c6ab` exists with message `feat(03-03): add Staff Engineer persona (first CORE-01 subagent)`

## Commits

| Commit | Files | Message |
|--------|-------|---------|
| `834c6ab` | `agents/staff-engineer.md` | `feat(03-03): add Staff Engineer persona (first CORE-01 subagent)` |

## Threat Flags

None. The persona file sits entirely within the Phase 3 `<threat_model>` threat register (T-03-16 through T-03-19) — no new trust boundaries, no new auth paths, no new network or file-access patterns. Content is authored by the project, committed in the repo, and reviewed at PR time per T-03-16's mitigation plan.

## Known Stubs

None. The persona is fully wired:
- Frontmatter values are concrete D-13 content, not placeholders.
- Examples cite real fixture lines, not "TODO: add real example".
- Handoff contract names the exact draft file path (`$RUN_DIR/staff-engineer-draft.md`); the `$RUN_DIR` variable is a conductor-side substitution documented in 03-RESEARCH.md Pattern 1, not an unresolved placeholder.

The one deliberate future-work item — the conductor (`commands/review.md` in Plan 03-01) and the draft-validator (`bin/dc-validate-scorecard.sh` in Plan 03-02) — consume this persona but are scoped to sibling plans in this same wave. They are not stubs in this plan's deliverable.
