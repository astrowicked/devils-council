---
persona: devils-advocate
artifact_sha256: f13f65b6a4cd4f799356bb93030e2f2111693c5a597a98bbf3436f39bca0e70b
findings:
  - target: "**Context**"
    claim: "The Context section treats the existence of a working Claude Code plugin as evidence that porting to OpenCode is the correct next move — but never defends the premise that OpenCode's user base, maturity, or ecosystem justifies the engineering investment. A port is only valuable if the destination has users; the artifact assumes destination value without stating it."
    evidence: |
      This is a port from a working Claude Code plugin (v1.1.1, 16 personas, shipped). OpenCode is a newer tool with a different plugin architecture.
    ask: "Name the signal that says OpenCode users exist in sufficient quantity to justify a port. Is it download counts, a request from a specific user, a strategic bet on OpenCode displacing Claude Code, or a personal interest project? If the answer is 'we want to be multi-runtime,' that is a strategy — write it down as the justification, because the artifact currently implies port-worthiness from the mere existence of a working source plugin."
    severity: major
    category: unexamined-framing
  - target: "**Context**"
    claim: "The artifact states the plugin system is 'still maturing' and then builds an entire scaffold on top of it — the plan never reconciles the tension between committing engineering effort to a surface that the artifact itself admits is unstable. The phrase 'still maturing' is doing work the artifact never accounts for."
    evidence: |
      The librarian research found docs from the sst/opencode repo but the plugin system is still maturing.
    ask: "What is the cost of building on a maturing API that breaks? The artifact acknowledges instability in the same breath as the design decision but never prices the rework. Define the threshold at which you would abandon this scaffold and wait — because without that threshold, 'still maturing' is a risk you acknowledged and then ignored."
    severity: blocker
    category: unexamined-framing
  - target: "Key Assumptions #2"
    claim: "Assumption 2 presumes that persona markdown body text is runtime-agnostic — but the entire value of the personas comes from their system prompts triggering specific runtime behaviors (tool restrictions, isolation, context boundaries). If the body text references Claude Code concepts like 'subagent isolation' or 'Agent tool' that OpenCode interprets differently or ignores, the personas will produce degraded critique without any build error to signal the problem."
    evidence: |
      Shared persona markdown (body text) works identically in both runtimes without modification
    ask: "Have you audited the 16 existing persona bodies for Claude-Code-specific terminology that would be semantically null in OpenCode? Phrases like 'you are a subagent,' references to 'Agent tool,' or 'context: fork' are instructions the Claude Code runtime interprets — if OpenCode's runtime ignores them, the personas degrade silently. Listing assumption 2 does not defend it; what evidence supports it?"
    severity: major
    category: unexamined-framing
  - target: "Key Assumptions #5"
    claim: "The plan assumes 'mode: subagent' provides isolation sufficient for adversarial personas, but the specific isolation property needed — preventing one persona from reading another's working context or the parent orchestrator's scratchpad — is never specified. 'Sufficient isolation' is undefined, so assumption 5 is unfalsifiable as written."
    evidence: |
      "mode: subagent" gives sufficient isolation for adversarial personas
    ask: "Define 'sufficient' with a concrete test: can persona A read persona B's in-progress scorecard? Can the Chair read raw persona outputs before synthesis? Can a persona see the user's prior conversation? If you cannot answer these from OpenCode's docs, you do not know whether 'mode: subagent' delivers what the council design requires — and building the scaffold first means you discover the gap after the work is done, not before."
    severity: major
    category: unexamined-framing
---

## Summary

The load-bearing premise in this plan is not any single API assumption (those are at least enumerated) — it is the unstated belief that porting to a self-described "still maturing" plugin system is worth the engineering cost *now*. The artifact acknowledges the instability and then proceeds as if acknowledging a risk is the same as mitigating it. Three further premises compound this: that persona body text is truly runtime-agnostic (unaudited), that "sufficient isolation" is a defined property (it is not), and that the port's destination has users who justify the work (unnamed). Any one of these being wrong does not just change the plan — it questions whether the plan should exist yet.
