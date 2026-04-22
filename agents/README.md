# Persona Authoring

Every file in this directory is a persona subagent. To add a persona,
follow the steps below — the schema and validator will catch anything
you miss. Do not try to hand-derive the rules from memory: read the
referenced docs, author against them, and let the validator fail loudly
on anything wrong.

## Before You Write — Required Reading

- `skills/persona-voice/SKILL.md` — the tone rubric, the voice kit, and
  the worked-example discipline. Read this first.
- `skills/persona-voice/PERSONA-SCHEMA.md` — the authoritative
  frontmatter schema. Every field name, every required rule, every
  validator check lives here. Your persona is wrong if it does not
  match this doc.
- `skills/scorecard-schema/SKILL.md` — the output contract personas
  target. Your persona emits findings in the scorecard shape; this doc
  is what the shape is.
- `templates/SCORECARD.md` — the per-run scorecard template. This is
  what a persona's output looks like on disk at `.council/<ts>/<persona>.md`.
- `lib/signals.json` — if your persona is `tier: bench`, your
  `triggers:` list must reference IDs that already exist in this file.
  If you need a new signal, add it there in the same change.

## The Five Required Custom Fields

Point at `PERSONA-SCHEMA.md` for full details; this is a summary only.

- `tier` — one of core, bench, chair. Core is always-on; bench is
  auto-triggered; chair is the Council Chair.
- `primary_concern` — one sentence, the value-system anchor. What this
  persona optimizes for above all else.
- `blind_spots` — 2-4 items you explicitly do not care about. Declaring
  blind spots is the single strongest lever against generic-reviewer
  voice.
- `characteristic_objections` — at least 3 verbatim phrases this
  persona actually says. Not paraphrases. Exact strings.
- `banned_phrases` — non-empty. Must include `consider`, `think about`,
  `be aware of` at minimum. Role-specific bans may be added.

`tone_tags` (optional, advisory) and `triggers` (required non-empty for
bench; empty or absent for core and chair) round out the custom
fields. See the schema doc.

## Body Content Rules

- Include a `## Examples` section with at least **two good findings**
  and at least **one bad finding** (per the voice skill's worked-example
  discipline). The subagent loads the examples on every invocation —
  they are few-shot voice anchors, not decoration.
- Do not describe the role. Describe the value system. "You optimize
  for 3am pages" beats "you are a senior SRE" every time.
- Keep the whole persona file under roughly 200 lines. Few-shot
  examples are the point; manifesto-length prose is not.

## Validate Before Committing

```bash
# Validate a single persona
./scripts/validate-personas.sh agents/your-persona.md

# Or validate all personas
./scripts/validate-personas.sh
```

The pre-commit hook in `hooks/hooks.json` (shipped in Plan 04) runs the
validator automatically on edits to `agents/*.md`. CI runs it on every
push. If you bypass the local hook, CI will catch you — the validator
is the source of truth for what passes.

## For Bench Personas Only

If your persona is `tier: bench`, you must provide a non-empty
`triggers:` list referencing IDs that already exist in
`lib/signals.json`. Phase 6's classifier (`lib/classify.js`) consumes
the same IDs and routes artifacts to your persona when they fire.

If you need a new signal, add it to `lib/signals.json` in the same
change that introduces the persona. The validator rejects references
to undeclared signal IDs regardless of whether detection is implemented
yet.

## What Not to Include

- `hooks`, `mcpServers`, `permissionMode` — stripped by Claude Code for
  plugin-shipped agents. Setting them does not work and will confuse
  you when behavior does not match the frontmatter.
- Personality gimmicks, catchphrases, emojis — undermine credibility
  and produce caricature (PITFALLS.md Pitfall 13).
- Generic checklist language — if your critique would apply to any
  artifact, rewrite it with evidence from the specific artifact.
- Findings without verbatim evidence or containing banned phrases —
  structurally dropped at review time by the scorecard-schema drop
  rule.

## Reference

- `.planning/ROADMAP.md` — Phase 3 authors the first core persona
  (Staff Engineer).
- `.planning/REQUIREMENTS.md` — PFMT-01 through PFMT-05 are the
  requirements this directory delivers against.
- `.planning/PROJECT.md` — the non-generic quality bar that motivates
  every rule here.
