---
# Scorecard template — see skills/scorecard-schema/SKILL.md for the contract.
# Copy this file to `.council/<ts>-<slug>/<persona>.md`, replace placeholders,
# and keep the schema fields in the exact shape below. Fields wrapped in
# angle brackets (<...>) are placeholders the persona fills in.

persona: "<persona-name>"              # e.g. staff-engineer, sre, product-manager
run_id: "<YYYY-MM-DDTHH-MM-SSZ>-<slug>"

findings:
  - id: "sha256:placeholder"           # deterministic hash; Phase 5 / CHAIR-06 fills this
    target: "<path:line OR ## heading OR quote-anchor>"
    claim: "<one-sentence specific failure mode>"
    evidence: |
      <verbatim substring of INPUT.md, minimum 8 characters>
    ask: "<concrete remediation the author can act on>"
    severity: "<blocker | major | minor | nit>"
    category: "<free-text tag, e.g. complexity | observability | cost | business>"

  # Add more findings as additional list entries with the same shape.
  # If the persona has no findings, the findings list MAY be empty — but then
  # the Summary below MUST explain why (e.g. "out of scope for this persona").
---

## Summary

<One-paragraph persona-voice prose. The persona's overall frame on the
artifact. This is advisory context; the structured findings above are
the load-bearing part that the Phase 3 review engine validates.>
