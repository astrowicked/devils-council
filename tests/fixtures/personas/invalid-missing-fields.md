---
name: fixture-invalid-missing-fields
description: "Test fixture — intentionally omits primary_concern so the validator rejects it."
tools: [Read, Grep]
model: inherit
skills:
  - persona-voice
  - scorecard-schema
tier: core
blind_spots:
  - "actual critique content"
  - "real-world applicability"
characteristic_objections:
  - "this fixture intentionally omits primary_concern"
  - "validator should reject with field-specific error"
  - "three entries satisfies the R5 threshold on its own"
banned_phrases:
  - "consider"
  - "think about"
  - "be aware of"
tone_tags: [test, fixture]
---

<!-- Intentionally missing primary_concern; validator should reject
     with an error naming the field `primary_concern` per rule R3.
     All other required fields are present so the failure is
     scoped to a single rule. -->

## Examples

### Good

- target: `tests/fixtures/personas/invalid-missing-fields.md:1`
  claim: "fixture frontmatter omits exactly one required field"
  evidence: "no primary_concern key anywhere in frontmatter"
  ask: "reject with R3 error"
  severity: blocker
  category: fixture

### Bad

- claim: "consider adding primary_concern"
  # Banned phrase illustration.
