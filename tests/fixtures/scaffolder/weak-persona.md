---
name: fixture-scaffolder-weak
description: "Incomplete persona for testing reject path."
tools: [Read, Grep, Glob]
model: inherit
skills: [persona-voice, scorecard-schema]
tier: core
primary_concern: "Is this good enough?"
blind_spots:
  - nothing
characteristic_objections:
  - "Seems fine."
banned_phrases:
  - consider
  - think about
---

Generic reviewer with intentionally insufficient fields.
This persona exists only to test the scaffolder's reject path.
It has 1 characteristic objection (R5 requires >= 3) and only
2 banned phrases (scaffolder requires >= 5).
