---
name: fixture-valid-bench
description: "Test fixture — well-formed bench persona for validator self-tests. References only signal IDs that exist in lib/signals.json."
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
  - "this is a bench test fixture"
  - "triggers reference real signal IDs"
  - "three entries satisfies rule R5"
banned_phrases:
  - "consider"
  - "think about"
  - "be aware of"
triggers:
  - auth_code_change
  - crypto_import
tone_tags: [test, fixture]
---

<!-- Well-formed bench persona fixture. Both trigger IDs MUST exist
     as keys in lib/signals.json (verified at fixture-authoring time). -->

## Examples

### Good

- target: `tests/fixtures/personas/valid-bench.md:20`
  claim: "triggers list references real signal IDs"
  evidence: 'triggers: [auth_code_change, crypto_import]'
  ask: "accept this file"
  severity: nit
  category: fixture

- target: `tests/fixtures/personas/valid-bench.md:8`
  claim: "bench tier with non-empty triggers satisfies R7"
  evidence: "tier: bench and triggers has >= 1 entry"
  ask: "none — recommended shape"
  severity: nit
  category: fixture

### Bad

- claim: "think about edge cases"
  # Banned phrase; illustrates voice collapse.
