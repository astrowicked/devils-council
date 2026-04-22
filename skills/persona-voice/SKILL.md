---
name: persona-voice
description: |
  Tone rubric and value-system-anchor discipline every persona preloads.
  Defines the voice kit (primary_concern, blind_spots, characteristic_objections,
  banned_phrases, tone_tags), the worked-example requirement, and why v1
  ships no LLM-based tone validation. Consumed by every persona subagent
  via the `skills:` preload field. Companion doc: PERSONA-SCHEMA.md.
user-invocable: false
---

# persona-voice

The tone rubric and value-system-anchor discipline every persona in this
plugin preloads. This skill is **not** user-invocable; it is declared in
each persona subagent's `skills:` list and injected into that persona's
system prompt at invocation time. Personas are authored in Phase 3+; this
skill is the contract they all obey.

> **Decision anchors:** D-08 (full voice kit: `primary_concern`,
> `blind_spots`, `characteristic_objections`, `banned_phrases`,
> `tone_tags`), D-09 (worked examples are inline in each persona body,
> good-vs-bad pairs), D-10 (no LLM-based tone validation in v1 —
> deterministic schema + worked examples + banned-phrase regex only),
> D-19 (no LLM snapshot validation in Phase 2; voice differentiation is
> verified by the Phase 4 / CORE-05 blinded-reader test).

## When to Use

This skill is not user-invocable. Every persona subagent under
`agents/<persona>.md` (authored Phase 3+) declares `persona-voice` in its
`skills:` preload list. At persona invocation, Claude Code loads this
skill's body into the persona's system prompt so the voice rubric and
worked-example discipline live in-context whenever the persona generates
a critique.

Do **not** reach for this skill from other contexts. It has no runtime
behavior on its own — it is a shared rubric document that shapes
persona output.

## The Three Failure Modes This Skill Prevents

This skill exists because persona review fails in three specific,
named ways if left to Claude's default voice. Each has a pointer into
`.planning/research/PITFALLS.md`.

- **Generic critique** (§Pitfall 1) — personas emit platitudes:
  "have you considered security?", "think about edge cases", "this
  might not scale". Nothing is actionable, nothing cites the artifact.
- **Voice collapse** (§Pitfall 3) — four personas produce interchangeable
  output in the same measured, hedged, bullet-pointed tone. The persona
  names are labels on identical prose. A blinded reader cannot tell
  them apart.
- **Caricature** (§Pitfall 13) — personas regress to internet-meme
  versions of the role. PM says "North Star". SRE says "works on my
  machine". Devil's Advocate asks "but what if Google builds this?".
  Content becomes unserious; the user stops reading.

The thesis of this skill is plain: all three failures collapse to one
defense. Each persona file carries a **value-system anchor**, a **voice
kit**, and **worked examples** that the subagent reads on every
invocation. Fix the persona file and you fix all three.

## The Voice Kit (D-08) — Five Required Fields Per Persona

Every persona's frontmatter declares these five fields. Their names are
canonical — `skills/persona-voice/PERSONA-SCHEMA.md` enforces them and
`scripts/validate-personas.sh` (Plan 03) regex-checks them.

| Field | Required | Purpose | Example (role-agnostic) |
|-------|----------|---------|-------------------------|
| `primary_concern` | yes | One sentence: what this persona optimizes for above all else. The value-system anchor. | "Pages at 3am — nothing else is real until on-call is protected." |
| `blind_spots` | yes | Short list (2-4): what this persona explicitly does NOT care about. Declaring blind spots is the single strongest lever against universal-checklist voice. | `[developer ergonomics, build-time aesthetics, code-style preferences]` |
| `characteristic_objections` | yes | 3-5 verbatim phrases this persona actually says. Exact strings the persona will reach for at critique time — not paraphrases. Validator rejects fewer than 3. | `["what's the runbook?", "how does this page?", "what's the blast radius?"]` |
| `banned_phrases` | yes | Non-empty list. Phrases that, if they appear in `claim` or `ask` of a finding, cause the finding to be structurally dropped per scorecard-schema. Every persona bans at minimum `consider`, `think about`, `be aware of`. Role-specific bans may be added. | `["consider", "think about", "be aware of", "it depends"]` |
| `tone_tags` | optional but strongly recommended | 2-3 tags describing prose register. Advisory only in v1 (no LLM check). Guides the author when writing worked examples. | `[terse, deadpan, asks-one-sharp-question]` |

**Intent per field:**

- `primary_concern` is the sentence the persona would put on a tombstone.
  It is the lens every finding must track back to. If a finding does not
  serve the primary concern, the persona should not have shipped it.
- `blind_spots` are not weaknesses — they are discipline. A persona that
  tries to cover everything becomes a generic reviewer. Declaring what
  the persona does not care about narrows output and amplifies voice.
- `characteristic_objections` are few-shot voice anchors. The persona
  reads its own objections on every invocation and reaches for them.
  Three is the minimum because two can be coincidence; three forces a
  pattern.
- `banned_phrases` are a structural drop rule, not a style suggestion.
  The scorecard-schema drops any finding containing a banned phrase.
  Listing the phrase in the persona file is both a cue to the subagent
  and a contract the validator enforces.
- `tone_tags` are advisory in v1. They shape how the author writes
  worked examples but are not validator-enforced. Phase 4 / CORE-05
  is the behavioral test for whether tone is discriminable.

Do NOT invent per-persona values here. Values are authored in Phase 3+
inside each `agents/<persona>.md` file.

## Worked Examples Are Inline (D-09) — Non-Negotiable

Every persona markdown file body MUST include a `## Examples` section with
at least **two good-example findings** and **one bad-example finding**.
The examples are few-shot context the subagent reads on every invocation
and are the single strongest lever against voice collapse per
PITFALLS.md §Pitfall 3. Do not put examples in a separate file — they
must be in the persona body so the subagent loads them.

A **good example** is a finding written in this persona's voice, citing a
line or heading or quote-anchor, naming the specific failure mode, with
an actionable ask. A **bad example** is a finding this persona would
refuse to ship — generic language, no evidence, uses a banned phrase,
could apply to any artifact.

Skeleton (leave persona-specific content for Phase 3+ authors):

```markdown
## Examples

### Good (what this persona ships)

- target: `src/handler.ts:17-24`
  claim: "Request timeout is unbounded; a slow downstream stalls the whole pool"
  evidence: `17:   const resp = await fetch(url);   // no timeout, no abort signal`
  ask: "Add an AbortController with a 2s timeout or document why unbounded is safe"
  severity: major
  category: operability

### Bad (what this persona refuses to ship)

- target: `src/handler.ts`
  claim: "Consider edge cases around error handling"
  ask: "Think about what could go wrong"
  # Rejected: contains banned phrase `consider`, contains banned phrase `think about`,
  # no line reference, no verbatim evidence, no specific failure mode.
```

The bad example is illustrative only. At runtime, the scorecard-schema
drop rule dispatches findings of that shape structurally — the engine
does not rely on the bad-example block at validation time. Personas
include the bad example in their body so the subagent **learns what to
avoid at generation time**, which is cheaper than regenerating after a
drop.

## Value-System Anchors, Not Role Labels (Pitfall 3 defense)

Describing a persona as "you are a Senior SRE" produces measured,
hedged, role-label output that sounds like every other LinkedIn comment
about SRE. Describing the same persona as "you optimize for 3am pages,
you do not care about developer ergonomics, and you ask 'what's the
runbook?' before anything else" produces discriminable voice.

Phase 3+ persona authors must prioritize the **value-system anchor**
(`primary_concern` + `blind_spots` + `characteristic_objections`) over
the role title. The role title is a label; the value system is the
voice. A persona whose body opens with its value system will produce
different output than one whose body opens with its job description,
even when both are given the same artifact.

## Why No LLM Tone Check in v1 (D-10, D-19)

v1 uses three deterministic defenses only:

- **Worked examples in the persona body** — few-shot at generation time.
  Cheap, in-context, and unbiased by the next turn's artifact.
- **Banned-phrase structural drop at review time** — per scorecard-schema,
  any finding containing a banned phrase is dropped with a structural
  error. Deterministic, regex-based, no LLM in the loop.
- **Phase 4 CORE-05 blinded-reader test** — offline, manual. A human
  reads the full persona set's output against real fixtures (authored in
  Plan 03) with persona names redacted and must identify each persona's
  critique. This is the v1 validator for voice differentiation. If
  blinded-reader accuracy drops below the CORE-05 threshold, Phase 3+
  persona files need rewriting — not the engine.

Tone fingerprints (`tone_tags`) are **authored-advisory**. They shape
prose style in the persona file and guide the author when writing
examples, but they are not validator-enforced in v1. Snapshot-voice
tests are explicitly deferred per D-19 — LLM output is non-deterministic
and snapshot drift is the wrong signal. LLM-as-judge is deferred to v1.1
per PITFALLS.md only if CORE-05 reveals voice collapse that examples +
banned phrases alone cannot prevent.

The failure mode this design accepts: a persona can still drift if its
author writes weak examples. The failure mode this design avoids: a
flaky LLM judge that rejects valid persona output and drives authors
to bland-but-passing prose.

## How Personas Load This Skill

Each persona declares this skill in its frontmatter `skills:` list. The
subagent runtime preloads the body into the persona's system prompt
before the persona sees the artifact. This is the verified Claude Code
plugin pattern (see `.planning/research/STACK.md` under
"`skills:` preload in subagents").

Minimal frontmatter fragment (from a future `agents/<persona>.md`
authored in Phase 3+):

```yaml
---
name: example-persona
description: "One-sentence trigger description."
tools: [Read, Grep, Glob]
model: inherit
skills:
  - persona-voice
  - scorecard-schema
tier: core
# ... voice kit fields follow ...
---
```

The persona's own body then supplies `primary_concern`, `blind_spots`,
`characteristic_objections`, `banned_phrases`, `tone_tags`, and the
`## Examples` section. This skill supplies the rubric; the persona
supplies the values.

## Companion Document — PERSONA-SCHEMA.md

`skills/persona-voice/PERSONA-SCHEMA.md` (authored in the same plan as
this file) is the authoritative persona frontmatter schema. This skill
defines **how voice works**; the schema doc defines **what fields are
required on every persona file** and the exact rules the validator
enforces. If the two disagree, the schema doc wins for field names and
validator rules — the validator is implemented directly against it —
and this skill updates to match.

Companions: read them together. Author personas against the schema; use
this skill's rubric to fill in the values.

## Revision Policy

Schema changes to this skill — adding a required voice-kit field,
changing the worked-example requirement, or changing the
no-LLM-tone-check stance — are documented revisions that require a
corresponding update to `PERSONA-SCHEMA.md` and `scripts/validate-personas.sh`
(Plan 03). Adding advisory guidance — tone-tag vocabulary, new example
categories, new failure-mode references — is backward-compatible and
does not require a coordinated validator change.

---

*Contract owner: devils-council Phase 2 (02-02)*
*Consumers: every persona authored in Phase 3+ (core, bench, chair tiers)*
*Companion: skills/persona-voice/PERSONA-SCHEMA.md*
*Phase 4 / CORE-05 blinded-reader test is the v1 behavioral validator
for voice differentiation.*
