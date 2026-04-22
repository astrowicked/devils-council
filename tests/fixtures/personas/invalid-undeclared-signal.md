---
name: fixture-invalid-undeclared-signal
description: "Test fixture — bench tier referencing a signal ID absent from lib/signals.json."
tools: [Read, Grep]
model: inherit
skills:
  - persona-voice
  - scorecard-schema
tier: bench
primary_concern: "Placeholder bench-tier concern used only for validator fixture tests."
blind_spots:
  - "actual critique content"
  - "real-world applicability"
characteristic_objections:
  - "triggers references an undeclared signal ID"
  - "validator should reject with R7 error"
  - "three entries satisfies R5"
banned_phrases:
  - "consider"
  - "think about"
  - "be aware of"
triggers:
  - not_a_real_signal_xyz
tone_tags: [test, fixture]
---

<!-- Intentionally references signal ID `not_a_real_signal_xyz` which
     is absent from lib/signals.json. Validator should reject with R7
     naming the undeclared ID. -->

## Examples

### Good

- target: `tests/fixtures/personas/invalid-undeclared-signal.md:22`
  claim: "triggers references undeclared ID"
  evidence: "triggers: [not_a_real_signal_xyz]"
  ask: "reject with R7 error naming the ID"
  severity: blocker
  category: fixture

### Bad

- claim: "think about the signal registry"
  # Banned phrase illustration.
