---
persona: staff-engineer
run_id: 20260424T120000Z-latest-run
findings:
  - id: staff-engineer-a3f2c1d8
    severity: major
    category: complexity
    target: "src/config.ts"
    claim: "Introducing a new ConfigLoader class when a plain object suffices"
    evidence: "class ConfigLoader { constructor() { this.data = {}; } }"
    ask: "Replace ConfigLoader with a plain object literal; eliminates 23 lines of boilerplate."
---

# Staff Engineer scorecard

Fixture content for dig-spawn test. Real scorecards are longer; this stub is sufficient to prove dig can locate, read, and preload the file.

The finding ID `staff-engineer-a3f2c1d8` follows the Phase 5 D-38 hash format:
`<persona-slug>-<sha256(persona + target_lc + claim_lc)[:8]>`.

This ID is evidence-excluded (per D-38) so the identity remains stable across re-runs
even if the persona picks a different verbatim quote for the `evidence:` field.
