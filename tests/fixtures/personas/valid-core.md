---
name: fixture-valid-core
description: "Test fixture — well-formed core persona for validator self-tests. Not a real persona."
tools: [Read, Grep]
model: inherit
skills:
  - persona-voice
  - scorecard-schema
tier: core
primary_concern: "Placeholder primary concern; this persona optimizes for fixture-testing only."
blind_spots:
  - "actual critique content"
  - "real-world applicability"
characteristic_objections:
  - "this is a test fixture, not a real persona"
  - "the validator must accept this file"
  - "three entries is the minimum per rule R5"
banned_phrases:
  - "consider"
  - "think about"
  - "be aware of"
tone_tags: [test, fixture]
---

<!-- Well-formed core persona fixture. Every hard rule R1-R8 passes;
     every soft warning W1-W3 is silent. Used by the self-test harness
     to assert the validator exits 0 on valid input. -->

## Examples

### Good

- target: `tests/fixtures/personas/valid-core.md:1`
  claim: "fixture frontmatter satisfies every hard rule"
  evidence: "tier: core; 3 characteristic_objections; non-empty banned_phrases"
  ask: "accept this file"
  severity: nit
  category: fixture

- target: `tests/fixtures/personas/valid-core.md:18`
  claim: "banned_phrases lists the three recommended bans"
  evidence: 'banned_phrases includes "consider", "think about", "be aware of"'
  ask: "none — recommended shape"
  severity: nit
  category: fixture

### Bad

- claim: "consider improving"
  # Intentionally contains a banned phrase; illustrates what NOT to write.
