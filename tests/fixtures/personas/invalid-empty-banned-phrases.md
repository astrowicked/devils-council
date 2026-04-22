---
name: fixture-invalid-empty-banned-phrases
description: "Test fixture — banned_phrases is an empty list."
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
  - "this fixture has an empty banned_phrases list"
  - "validator should reject with R6 error"
  - "three entries satisfies R5 on its own"
banned_phrases: []
tone_tags: [test, fixture]
---

<!-- Intentionally has banned_phrases: []. Validator should reject
     with R6 error naming `banned_phrases`. All other hard rules
     pass so the failure is scoped to R6 alone. -->

## Examples

### Good

- target: `tests/fixtures/personas/invalid-empty-banned-phrases.md:17`
  claim: "banned_phrases is empty"
  evidence: "banned_phrases: []"
  ask: "reject with R6 error"
  severity: blocker
  category: fixture

### Bad

- claim: "think about banning something"
  # Banned phrase illustration (ironic, given the fixture).
