---
name: fixture-invalid-too-few-objections
description: "Test fixture — characteristic_objections has only 2 entries."
tools: [Read, Grep]
model: inherit
skills:
  - persona-voice
  - scorecard-schema
tier: core
primary_concern: "Placeholder primary concern used only for validator fixture tests."
blind_spots:
  - "actual critique content"
  - "real-world applicability"
characteristic_objections:
  - "only two entries here"
  - "that is one fewer than rule R5 requires"
banned_phrases:
  - "consider"
  - "think about"
  - "be aware of"
tone_tags: [test, fixture]
---

<!-- Intentionally has 2 characteristic_objections entries. Validator
     should reject with R5 error naming `characteristic_objections`
     and the >= 3 threshold. All other hard rules pass so the failure
     is scoped to R5 alone. -->

## Examples

### Good

- target: `tests/fixtures/personas/invalid-too-few-objections.md:15`
  claim: "characteristic_objections has 2 entries"
  evidence: "only two list items under characteristic_objections"
  ask: "reject with R5 error"
  severity: blocker
  category: fixture

### Bad

- claim: "be aware of the minimum"
  # Banned phrase illustration.
