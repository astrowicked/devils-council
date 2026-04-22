---
name: scorecard-schema
description: |
  Canonical scorecard contract every persona targets and the Phase 3 review
  engine enforces. Defines finding fields (target, claim, evidence, ask,
  severity, category), the 4-tier severity enum, the verbatim-evidence
  grounding rule, and the structural drop rule for banned vague verbs.
  Consumed by every persona via the subagent `skills:` preload field.
user-invocable: false
---

# scorecard-schema

The load-bearing output contract for every persona in devils-council. This
skill is **not** user-invocable; it is preloaded into every persona subagent
via the `skills:` frontmatter field. The Phase 3 review engine validates
every scorecard file produced by a persona against the schema defined here.

> **Decision anchors:** D-01 (markdown + YAML frontmatter with `findings:` list),
> D-02 (finding fields: `id`, `target`, `claim`, `evidence`, `ask`, `severity`,
> `category`), D-03 (4-tier severity, no `praise`), D-04 (verbatim evidence,
> ≥8 chars), D-05 (free-text category), D-06 (`templates/SCORECARD.md`
> mirrors this schema), D-07 (banned-phrase structural drop, not advisory).
> Anchors are defined in
> `.planning/phases/02-persona-format-voice-scaffolding/02-CONTEXT.md`.

## When to Use

This skill is not invoked directly. It is preloaded into every persona
subagent so the persona's system prompt carries the contract it must
produce. Every scorecard a persona writes at
`.council/<ts>-<slug>/<persona>.md` MUST conform to the schema below.

The Phase 3 review engine validates scorecards against this schema.
Non-conforming output is dropped with a structural error logged, never
silently included in council output. This is the single mechanism that
makes "non-generic critique" (PITFALLS.md §Pitfall 1) and "voice collapse"
(PITFALLS.md §Pitfall 3) enforceable rather than aspirational.

Do **not** use this skill for: defining persona voice (that is
`skills/persona-voice/SKILL.md` in Phase 2 Plan 02), classifying signals
(that is Phase 6), or synthesizing findings across personas (that is the
Chair in Phase 5).

## Scorecard File Shape

A scorecard is a single markdown file. YAML frontmatter at top carries
the structured, machine-validated findings. The markdown body below the
frontmatter carries a persona-voice prose summary — advisory context, not
the load-bearing contract.

Minimal complete example:

```markdown
--- # YAML doc delimiter
persona: staff-engineer
run_id: 2026-04-22T14-23-01Z-add-caching-layer
findings:
  - id: "sha256:placeholder"        # deterministic hash — Phase 5 / CHAIR-06 defines the recipe
    target: "src/cache.ts:42-48"    # line reference OR quote anchor
    claim: "Cache eviction policy is implicit and unbounded"
    evidence: |
      42:   const cache = new Map();
      43:   function put(k, v) { cache.set(k, v); }   // no max size, no TTL
    ask: "Declare a max-size and eviction policy, or document why unbounded is safe"
    severity: major
    category: complexity
--- # YAML doc delimiter

## Summary

One-paragraph persona-voice prose here. The persona's frame on the
artifact as a whole. Structured findings above are the load-bearing
part; this summary is advisory context, not the contract.
```

If a persona has no findings, `findings:` MAY be empty — but the prose
summary below MUST explain why (e.g. "out of scope for this persona").
An empty-findings scorecard with no explanation fails validation.

## Finding Fields (required)

Every entry in `findings[]` MUST carry all seven fields below. Extra
fields are silently ignored by the validator; missing required fields
drop the finding.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Deterministic hash of persona + target + claim. Phase 5 (CHAIR-06) defines the hashing recipe; Phase 2 only declares the field exists. Phase 3 engine may emit a placeholder (`sha256:placeholder`) until the hashing is wired. |
| `target` | string | yes | Line reference (`path:line` or `path:start-end`) for code, heading anchor (`## Heading`) for plans/RFCs, or a short quote-anchor phrase for unstructured prose. |
| `claim` | string | yes | One-sentence statement of the specific failure mode. Must name the thing that is wrong; no generic "consider edge cases" language. |
| `evidence` | string | yes | Verbatim substring of INPUT.md, **minimum 8 characters**. See Evidence Grounding Rule below. |
| `ask` | string | yes | Concrete remediation the author can act on. Answers "what should I change?" in a single line or short block. |
| `severity` | enum | yes | One of `blocker` \| `major` \| `minor` \| `nit`. See Severity Tiers below. |
| `category` | string | yes | Free-text persona-suggested tag (examples: `complexity`, `observability`, `cost`, `business`, `auth-bypass`). No fixed enum in v1. Chair synthesizes top-3 categories across all personas in Phase 5. |

## Severity Tiers (D-03)

Exactly four tiers. The enum is closed; any other value fails validation.

- **`blocker`** — the artifact should not land in this form. The issue is
  correctness, safety, or contract-breaking. Named personas can and
  should use this sparingly; a scorecard that flags everything as
  `blocker` has no signal.
- **`major`** — substantial concern the author should address before
  landing or explicitly accept (e.g., missing observability, unbounded
  growth, silent failure mode).
- **`minor`** — real issue but not landing-blocking; improves quality if
  addressed.
- **`nit`** — stylistic or small-scope. Collapsed by default in the
  Phase 7 severity-tiered output rendering.

There is **no `praise` tier**. Adversarial discipline first — a persona
is not required to say anything positive, and the schema does not give
them a slot to do so. This is a deliberate constraint on voice, per
PITFALLS.md §Pitfall 3.

## Evidence Grounding Rule (D-04)

The contract that makes non-generic critique enforceable at schema
level, not at prompt-engineering level.

- `evidence` MUST be a verbatim substring of
  `.council/<ts>-<slug>/INPUT.md` (the snapshotted artifact for this
  run). INPUT.md is the single source of truth for what the persona
  reviewed; evidence that does not appear in INPUT.md cannot be trusted.
- Minimum length: **8 characters**. Prevents meaningless one-word or
  one-token evidence like `evidence: "the"` or `evidence: "// TODO"`.
- Phase 2 states the rule. The Phase 3 review engine enforces it via a
  literal substring check (`grep -F`-equivalent) of the evidence string
  against INPUT.md. Findings that fail evidence-grounding are **dropped
  from the scorecard with a structural error logged**, never silently
  retained.
- The evidence block MAY include leading whitespace and line-number
  prefixes to make quoted code readable (see the cache example above).
  Normalization policy (whitespace collapsing, line-prefix stripping)
  is a Phase 3 engine-design concern; Phase 2 declares the rule, not
  the normalization policy.

## Banned-Phrase Drop Rule (D-07)

The structural defense against voice collapse and vacuous critique.
This rule is schema-level, not advisory. It is independent of any
LLM-based tone check.

- Each persona declares a `banned_phrases` list in its agent frontmatter
  (authored in Phase 3+). Every persona bans at minimum: `consider`,
  `think about`, `be aware of` — the three phrases PITFALLS.md §Pitfall 1
  identifies as the strongest generic-critique markers.
- A finding whose `claim` or `ask` field contains a banned phrase —
  case-insensitive word-boundary match, e.g. `\bconsider\b` —
  is **dropped from the scorecard**. Not flagged advisorily; not
  rewritten; dropped. The Phase 3 engine logs a structural error
  recording which phrase matched.
- Downstream policy (whether the Phase 3 engine regenerates the persona's
  scorecard, asks for a retry, or ships the remaining findings with a
  count of drops) is a Phase 3 engine-design decision — **not** Phase 2's
  call. This schema only commits that the drop rule exists and is
  structural.

## Category Guidance (D-05)

`category` is free-text, persona-suggested. There is no fixed enum in v1
by design: letting each persona surface its own framings is what lets the
Chair's top-3 clustering in Phase 5 discover emergent categories that a
fixed enum would have pre-committed away.

Non-exhaustive seed list personas may draw from:

`complexity, observability, cost, business, auth-bypass, race-condition,
iam-wildcard, air-gap, egress, blast-radius`

Personas MAY invent new categories when the seed list does not fit. A
persona that always reaches for the same category across varied
artifacts is a voice-collapse signal (see PITFALLS.md §Pitfall 3) — but
that is a Phase 4 blinded-reader concern, not a Phase 2 validator
concern.

## Template Reference (D-06)

The canonical copy-paste template for a scorecard file is at
`templates/SCORECARD.md`. Copy it to `.council/<ts>-<slug>/<persona>.md`,
fill in the frontmatter, write the prose summary.

The template mirrors this schema exactly. If the two disagree, **the
schema wins and the template must be updated**. Schema drift is caught
by Phase 3's validator fixtures exercising the template shape.

## Relationship to Codex Deep-Scan (shape compatibility)

`skills/codex-deep-scan/SKILL.md` already declares that its Response
Schema `findings[]` array conforms to this scorecard finding shape. The
two schemas MUST stay in sync. Adding a required field here is a
breaking change to both.

**One-field delta to resolve:** codex-deep-scan currently documents
severities as `blocker | high | medium | low | nit`. Phase 2
canonicalizes the severity enum to `blocker | major | minor | nit` (no
`high` / `medium` / `low`). Phase 6, when it wires Codex delegation into
personas, owns the mapping from Codex output severities into this
canonical enum. One reasonable mapping:

- `high` → `major`
- `medium` → `minor`
- `low` → `nit`

This mapping is documented here as a note; **it is not implemented in
Phase 2 and `skills/codex-deep-scan/SKILL.md` is not edited by this
plan**. Phase 6 is the correct place to wire the translation and to
either update codex-deep-scan or implement the mapping at the conductor
layer.

## Revision Policy

Schema changes require a documented revision, not a silent edit. Adding
an optional field is backward-compatible; adding a required field,
renaming a field, or removing a field is a breaking change. The
scorecard schema and `templates/SCORECARD.md` MUST stay in sync —
drift between them silently weakens validation and must be caught by
Plan 03's validator fixtures.

---

*Contract owner: devils-council Phase 2 (02-01)*
*Consumers: all personas authored from Phase 3 onward; Phase 3 review
engine validator; Phase 5 Chair synthesis; Phase 6 Codex delegation.*
