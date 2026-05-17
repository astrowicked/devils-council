---
persona: sre
artifact_sha256: 89ab6510fa0b948a7fc33fc00981b047990a3fe073343ca3df6bf89118945b5a
findings:
  - target: "**Threat Model:**"
    claim: "T-02-04 accepts context overflow as 'natural LLM limits' with no plan for what the user sees when it happens. A 5,000-line plan artifact hits the single-context council-review agent and the model silently truncates the 4th persona's scorecard — the user gets a partial review with no error signal, and the missing persona is the one most likely to catch a real issue because it runs last with the least remaining context."
    evidence: |
      T-02-04: Large artifact → context overflow — accepted (natural LLM limits)
    ask: "Define the failure signal: what does the user see when context is exhausted mid-review? Options: (1) emit a structured error in the output YAML when a persona section cannot complete, (2) pre-flight token estimate that refuses artifacts above N tokens with a clear message, (3) truncate artifact with a visible '[TRUNCATED at line N]' marker. Pick one and put it in the plan — 'accepted' is not a mitigation, it's an unmonitored silent-corruption path."
    severity: major
    category: blast-radius
  - target: "**Orchestration Strategy: Option E"
    claim: "Sequential generation of 4 scorecards + synthesis in a single context window means each successive persona reads ALL prior persona output. Persona 4 has 3 full scorecards in its context. The 'CONTEXT RESET' instruction is a prompt-engineering hope, not a hard isolation boundary — there is no mechanism to detect or measure when contamination actually occurs, so you cannot page on it or even know it's happening."
    evidence: |
      "CONTEXT RESET" instruction at the boundary of each persona phase to reduce cross-contamination.
    ask: "What's the detection mechanism? If persona 3 parrots a finding from persona 1, how does the system know? Suggest: post-hoc deduplication check in the Chair synthesis that flags finding-pairs with >80% cosine similarity across personas and emits a `contamination_suspected: true` field. Without a signal, cross-contamination is an invisible quality regression that degrades every review silently."
    severity: major
    category: observability
  - target: "Task 3: Update build.sh"
    claim: "Post-transform validation checks for YAML frontmatter, mode: subagent, no $RUN_DIR — but there's no validation that the council-review agent's output actually produces parseable YAML scorecards. The build validates the input format (the agent file) but not the output contract (the scorecard). A prompt edit to a persona section can silently break scorecard parsing for every subsequent invocation, and you won't know until a user files a bug."
    evidence: |
      Post-transform validation (YAML frontmatter, mode: subagent, no $RUN_DIR)
    ask: "Add a golden-file integration test: run council-review against a fixed test artifact, parse the output YAML for each persona section, assert the `findings:` array is valid YAML with required fields (target, claim, evidence, ask, severity). Run this in CI on every change to council-review.md. Without it, the first broken scorecard is discovered by a user, not by the build."
    severity: major
    category: testing
  - target: "**The council-review agent puts 4 personas + Chair synthesis into a SINGLE context window"
    claim: "The plan specifies '~150-200 line system prompt' but gives no estimate of the total token budget consumed by a typical review. System prompt (200 lines) + artifact (unknown size) + 4 scorecards (each ~40-80 lines generated) + synthesis — at the low end this is 8-12K tokens of generated content on top of the input. At the high end with a real plan artifact (2K-5K tokens), you're at 15-20K generated tokens in a single turn. There is no stated limit on artifact size that this plan commits to supporting, which means no SLO on review completeness."
    evidence: |
      ~150-200 lines, anti-contamination CONTEXT RESET between phases
    ask: "State the supported artifact size range: 'council-review is designed for artifacts up to N tokens; above that, output quality degrades.' Put this in the agent's system prompt so it can refuse or warn. Without a stated ceiling, every large-artifact review is a coin flip on whether persona 4 gets enough context to produce a real scorecard."
    severity: minor
    category: capacity-planning
---

## Summary

The plan's single-context sequential model creates three unmonitored failure modes that will silently degrade review quality with no signal to the user or maintainer. Context overflow produces truncated scorecards with no error marker. Cross-contamination between personas has no detection mechanism — it's a prompt-level hope with no measurement. And the build validates agent file format but not output contract, so a broken scorecard template ships to users without CI catching it. The fix for all three is the same pattern: emit a signal when the failure occurs, so someone knows it happened before a user reports garbage output.

