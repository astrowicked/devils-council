---
persona: devils-advocate
artifact_sha256: 4097cffc6d2d2457226f79778b057ddb6614a24989906ac236fc328c144ea708
findings:
  - target: "<objective>"
    claim: "The objective presumes that soft (LLM-readable rules) and hard (TypeScript module) detection must ship in the same phase, but never defends why shipping dead code now — code that cannot be tested against the soft path until Phase 6 — is preferable to delivering the TypeScript module when it actually wires up in Phase 4."
    evidence: |
      in OpenCode v1.2 we deliver both a soft (LLM-readable rules) and hard (TypeScript module) detection path.
    ask: "Name the cost of deferring signals.ts to Phase 4 where it gets wired. The plan delivers a module that exports classify() but no caller imports it, no test exercises it against the same artifact the LLM rules process, and no contract guarantees the two systems agree. If the reason is 'Phase 4 needs it ready,' that is a dependency claim — defend it with the Phase 4 plan's interface contract, not with an assertion that doing two things at once is 'hybrid.'"
    severity: major
    category: unexamined-framing
  - target: "Task 2 <action>"
    claim: "The plan explicitly drops AST-based detection with a one-sentence justification that 'artifacts are typically plan/RFC/diff text, not raw Python source.' But the ROADMAP's OC-SIGNAL-01 requirement says 'Signal detection triggers correct bench personas based on artifact content' — and diff text routinely contains raw Python source (unified diffs of .py files). The justification does not account for the artifact type it dismisses."
    evidence: |
      Skip Python AST-based detection (classify.py uses `ast.parse` for .py files). Use regex-only detection — sufficient for the OpenCode use case where artifacts are typically plan/RFC/diff text, not raw Python source that needs AST parsing.
    ask: "What fraction of real review invocations will pass a code diff as the artifact? If the answer is 'most of them' — because developers review code changes, not plans — then the premise that 'artifacts are typically plan/RFC/diff text' is empirically wrong and the entire simplification that justifies dropping AST detection is built on a false characterization of the input distribution."
    severity: major
    category: unexamined-framing
  - target: "Task 3 <action>"
    claim: "The plan instructs the LLM to 'check for these structural signals' after reading the artifact, but never defends the premise that an LLM will reliably execute a conditional-activation checklist with 13+ pattern categories across 4 bench personas — a task where a single missed pattern is a silent false-negative that no downstream step detects or reports."
    evidence: |
      This gives the council-review agent immediate soft signal detection — the LLM reads the artifact, spots patterns from the rules above, and activates the right bench lenses. Not deterministic like the TypeScript classifier, but functional for v1.2 without needing plugin infrastructure wired.
    ask: "What is the plan's falsification test for 'functional'? If no test artifact ever exercises whether the LLM correctly activates bench personas (verification step 4 only checks the rules section EXISTS, not that it WORKS), then 'functional' is an assertion without evidence. Name a verification that would detect the LLM ignoring the signal rules — if none exists in this phase or the next, the soft path is unverifiable and you are shipping faith, not engineering."
    severity: blocker
    category: unexamined-framing
  - target: "ROADMAP Phase 3 vs. plan scope"
    claim: "The ROADMAP requirement OC-BENCH-01 lists 'Performance/Dual-Deploy' as a single slot with a slash, and the ROADMAP description explicitly lists 5 names: 'Security, FinOps, Air-Gap, Performance, Dual-Deploy.' The plan silently delivers 4 and never states where Dual-Deploy went or which decision authorized dropping it — the reader encounters a 5-to-4 contraction with no defense."
    evidence: |
      Port top 4 bench personas (Security, FinOps, Air-Gap, Performance, Dual-Deploy)
    ask: "Quote the decision record or discussion thread where Dual-Deploy was deprioritized. If none exists, the plan is shipping a scope reduction disguised as a plan that fulfills its own requirement — OC-BENCH-01 names a persona this plan does not deliver. Either the requirement needs amendment or the plan needs a fifth persona."
    severity: major
    category: unexamined-framing
---

## Summary

The load-bearing premise in this plan is that "hybrid" — delivering both soft LLM detection and hard TypeScript detection simultaneously — is the right scoping decision. The plan never defends this against the alternative of shipping the soft path alone (immediate value, verifiable in-session) and the hard path in Phase 4 (where it wires up and can actually be tested). Instead, the plan ships a TypeScript module that nothing calls, nothing tests against the soft path, and nothing will validate for agreement until Phase 6's CI.

The secondary premise — that regex-only detection is sufficient because "artifacts are typically plan/RFC/diff text" — is an empirical claim about user behavior that the plan treats as self-evident. If developers mostly review code diffs (which contain raw Python, Go, TypeScript), the regex-only simplification is calibrated to a minority use case and will silently produce false negatives on the majority case.

Finally, the plan's verification steps only confirm that files exist and contain expected strings. No verification step exercises whether the soft signal detection actually works when the council-review agent processes an artifact. The entire "functional for v1.2" claim rests on the unverified premise that LLMs reliably follow conditional-activation checklists — a premise contradicted by the field's experience with complex instruction-following.
