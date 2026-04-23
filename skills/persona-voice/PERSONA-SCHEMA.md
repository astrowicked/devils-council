# PERSONA-SCHEMA

This document defines the YAML frontmatter contract for every file under
`agents/*.md` in this plugin. `scripts/validate-personas.sh`
(Phase 2 Plan 03) enforces this schema deterministically. If this doc
and the validator disagree, the validator is the source of truth for
what fails; this doc is the source of truth for what the contract says
it should be — discrepancies are bugs in one or the other and get fixed
together, not independently.

Read this alongside `skills/persona-voice/SKILL.md`. The voice skill
defines how voice works; this doc defines which fields must be present,
what their values may be, and how the validator will check them.

## Standard Subagent Fields (verified, pass-through)

These fields are Claude Code subagent fields — Claude Code itself reads
them. They are documented in `.planning/research/STACK.md` under
"Subagent (persona) Frontmatter Schema (verified)".

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `name` | string | yes | Kebab-case identifier. Must match the filename without `.md`. |
| `description` | string | yes | One sentence on when to invoke this persona. Keep under 300 chars (`SLASH_COMMAND_TOOL_CHAR_BUDGET` per STACK.md — long descriptions get truncated). |
| `tools` | list | yes | Tool allowlist. Phase 3 decides the default for core personas. |
| `model` | string | yes | One of `inherit`, `sonnet`, `haiku`, etc. Phase 3 decides the default. |
| `skills` | list | yes | MUST include `persona-voice` and `scorecard-schema` for any critiquing persona. May include `codex-deep-scan` for personas that delegate deep scans. |

Plugin-shipped subagents MUST NOT include `hooks`, `mcpServers`, or
`permissionMode` — Claude Code strips these silently for plugin-shipped
agents (see STACK.md "Recent Changes" under "Plugin-shipped agents
cannot set…"). The validator emits a soft warning if any of these three
fields appear, since they indicate the author mistakenly tried to use
them and the persona will not behave as they expect.

## Required Custom Fields (D-11) — Five Fields, All Required

These are not Claude Code reserved fields; they are custom fields read
by `scripts/validate-personas.sh` and by the Phase 3+ review engine via
shell-injection at invocation time.

| Field | Type | Required | Constraint | Validator Check |
|-------|------|----------|------------|-----------------|
| `tier` | enum | yes | One of `core`, `bench`, `chair`, `classifier` (D-12 + Phase 6 D-53 extension). | Exact string match against the enum — any other value is a hard failure. |
| `primary_concern` | string | yes | Non-empty one-sentence statement. The persona's value-system anchor. | Present, non-empty. |
| `blind_spots` | list of strings | yes | Non-empty list. 2-4 entries recommended; neither bound is enforced. | Present, non-empty list. |
| `characteristic_objections` | list of strings | yes | **At least 3 entries** (D-14). No upper bound. | `length >= 3` is a hard failure if violated. |
| `banned_phrases` | list of strings | yes | **Non-empty** (D-15). Should include `consider`, `think about`, `be aware of` at minimum. | `length >= 1` is a hard failure in v1 strict mode. Missing any of the three common bans emits a soft warning only. |

`scripts/validate-personas.sh` (Plan 03) enforces
`characteristic_objections` length ≥ 3 and `banned_phrases` length ≥ 1
as **hard failures**. Missing common bans (`consider`, `think about`,
`be aware of`) is a **soft warning** rather than a hard fail so a
role-specific persona can intentionally allow one of those words if
their `characteristic_objections` quote it — e.g., a persona whose
voice is "I refuse to be the person who says 'consider'" might want
`consider` quoted inside an objection. The validator warns in that case
so the author sees it but does not fail the build.

## Optional Custom Fields

| Field | Type | Required | When Used | Validator Check |
|-------|------|----------|-----------|-----------------|
| `triggers` | list of strings | optional for `core`, optional for `chair`, **required non-empty for `bench`** (D-13) | Bench personas declare the signal IDs that auto-trigger them. Signal IDs are drawn from `lib/signals.json`. | If `tier: bench` → list must be non-empty AND every ID must exist as a key in `lib/signals.json`'s `signals` object. If `tier: core` or `tier: chair` → list must be empty or absent (hard failure otherwise — core/chair personas are not auto-triggered). |
| `tone_tags` | list of strings | optional | 2-3 advisory tags describing prose register (terse, deadpan, asks-one-sharp-question, etc.). Not enforced in v1. | Shape check only — must be a list of strings if present. |

## Tier Semantics (D-12)

- **`core`** — always-on. Spawned on every `/devils-council:review`
  invocation. Phase 3+4 deliver CORE-01..04 personas in this tier.
  `triggers:` is empty or absent.
- **`bench`** — auto-triggered on structural signals. Phase 6 delivers
  bench personas (Security Reviewer, FinOps Auditor, Air-Gap Reviewer,
  Dual-Deploy Reviewer). `triggers:` is a non-empty list of signal IDs
  from `lib/signals.json`.
- **`chair`** — the Council Chair (Phase 5). Runs sequentially after
  core + bench personas complete. `triggers:` is empty or absent.
- **`classifier`** — Haiku-tier subagent invoked by the conductor ONLY when
  lib/classify.py returns `deterministic_match_count == 0`. The classifier
  is not a critic — it emits a structured JSON object naming which bench
  personas to spawn. `triggers:` is empty or absent. Custom critic fields
  (`primary_concern`, `blind_spots`, `characteristic_objections`,
  `banned_phrases`) are FORBIDDEN per R9. Phase 6 delivers
  `agents/artifact-classifier.md` in this tier.

The enum is closed at four values. Adding a tier is a schema change
and requires a coordinated update to this doc plus the validator.

## Worked-Example Body Requirement (D-09)

Every persona markdown file body MUST contain a `## Examples` H2 section
with at least two good-example findings and one bad-example finding (see
`skills/persona-voice/SKILL.md` for the rubric). The validator performs
a **soft check** for the presence of a `## Examples` heading and warns
if absent. Enforcement of the example count is a soft warning, not a
hard fail, because the validator cannot reliably count "findings" in
freeform markdown.

Hard enforcement of example count is deferred. Author discipline plus
the Phase 4 / CORE-05 blinded-reader test catches regressions. If
CORE-05 fails and the root cause is insufficient examples, Plan 03's
soft check becomes a hard check in a v1.1 schema revision.

## Signal Registry Contract (D-13)

Every signal ID referenced in a persona's `triggers:` list MUST appear
as a key in the `signals` object of `lib/signals.json`. The registry
shape is defined in this plan's Task 3. Phase 6 is responsible for
implementing detection in `lib/classify.js`; Phase 2 only guarantees
the IDs exist as a declared vocabulary.

The validator (Plan 03) reads `lib/signals.json` and rejects persona
files that reference undeclared signal IDs. If a bench persona needs a
new signal, the signal must be added to `lib/signals.json` in the same
change — the validator rejects references to undeclared IDs regardless
of whether detection is implemented yet.

## Complete Example (well-formed persona frontmatter — placeholder values)

This is a placeholder skeleton, not a real persona. Real personas are
authored in Phase 3+.

```yaml
---
name: example-persona           # REPLACE — must match filename without .md
description: "One-sentence trigger description under 300 chars."
tools: [Read, Grep, Glob]       # adjust per Phase 3 decision
model: inherit                  # adjust per Phase 3 decision
skills:
  - persona-voice
  - scorecard-schema
tier: core                      # core | bench | chair
primary_concern: "<one-sentence value-system anchor>"
blind_spots:
  - "<what this persona explicitly does not care about>"
  - "<another blind spot>"
characteristic_objections:
  - "<verbatim phrase this persona actually says>"
  - "<another verbatim phrase>"
  - "<at least three entries required by validator>"
banned_phrases:
  - "consider"
  - "think about"
  - "be aware of"
tone_tags: [terse, deadpan]     # optional advisory
# triggers: [...]               # REQUIRED non-empty for tier: bench; empty/absent for core/chair
---
```

The persona's body below the frontmatter supplies the `## Examples`
section (two good + one bad finding minimum) and any prose scoping the
persona's review.

## Validator Summary (what Plan 03 will enforce)

This is the exact check list `scripts/validate-personas.sh` implements,
in the order the validator runs it:

- Frontmatter parses as valid YAML (hard failure otherwise).
- All 5 required custom fields are present: `tier`, `primary_concern`,
  `blind_spots`, `characteristic_objections`, `banned_phrases` (hard
  failure if any are missing).
- `tier ∈ {core, bench, chair, classifier}` (hard failure on any other value).
- `banned_phrases` is a non-empty list (hard failure on empty).
- `characteristic_objections` has ≥ 3 entries (hard failure on fewer).
- Bench personas have non-empty `triggers`; core and chair personas
  have empty or absent `triggers` (hard failure on either mismatch).
- Trigger IDs (when present) exist as keys in `lib/signals.json`'s
  `signals` object (hard failure on any undeclared ID).
- R9: if `tier: classifier`: MUST NOT have `primary_concern`,
  `blind_spots`, `characteristic_objections`, or `banned_phrases`;
  `triggers:` empty or absent (hard failure on any violation — added
  Phase 6 D-53 per RESEARCH.md §Q6 Option 2).
- Soft check: warn if the persona body lacks a `## Examples` section.
- Soft check: warn if any of `consider`, `think about`, `be aware of`
  are missing from `banned_phrases`.
- Soft check: warn if `hooks`, `mcpServers`, or `permissionMode` appear
  in the frontmatter (Claude Code strips these silently for plugin-shipped
  agents, so the author will be surprised if they expect them to work).

Plan 03's validator fixtures exercise every rule above — each rule has
a dedicated malformed-persona fixture that must be rejected for the
rule to be considered tested.

## Revision Policy

Schema changes — adding a required field, changing an enum, tightening
a validator rule from soft to hard, or changing a tier's trigger rule —
are documented revisions that require a coordinated update to
`scripts/validate-personas.sh` and to any personas authored against the
previous schema. Adding optional fields or softening a rule is
backward-compatible.

---

*Contract owner: devils-council Phase 2 (02-02)*
*Companion: skills/persona-voice/SKILL.md*
*Validator: scripts/validate-personas.sh (Plan 03)*
*Signal registry: lib/signals.json (this plan, Task 3)*
