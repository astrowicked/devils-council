---
persona: staff-engineer
findings:
  - target: "Task 2: council-review.md"
    claim: "A 150–200 line single-agent that role-plays four distinct voices sequentially is a context-compression trick, not real isolation. The LLM will bleed tone from Phase 1 into Phase 4 regardless of a 'CONTEXT RESET' line — you are shipping a known cross-contamination risk as a feature."
    evidence: |
      "CONTEXT RESET" instruction at start of each phase (anti-contamination)
    ask: "Ship the 4 standalone persona agents first. Defer the orchestrator until you have evidence that users actually want single-invocation council review rather than invoking @staff-engineer or @sre directly. If they do, measure contamination before calling it solved."
    severity: major
    category: complexity
  - target: "Task 1"
    claim: "The existing build.sh already transforms agents to OpenCode format but leaves $RUN_DIR and INPUT.md references in the body text. Task 1 describes removing these references, but the plan never says what replaces them — if the user pastes the plan in the message, the persona instructions still say 'Read INPUT.md at the run directory' which is now wrong."
    evidence: |
      Remove $RUN_DIR references (input from user message instead)
    ask: "Define the concrete replacement instruction text: 'Review the artifact the user provided in their message' or equivalent. Without this, Task 1 produces personas that reference nothing."
    severity: major
    category: correctness
  - target: "Task 3"
    claim: "council-review is described as 'OpenCode-native (no Claude Code source) — preserved during build, not transformed' — this means it sidesteps the very validation the plan also mandates ('no $RUN_DIR, no Agent tool refs'). You now have two categories of agent (transformed vs native) with different lifecycle rules, for one extra file."
    evidence: |
      council-review is OpenCode-native (no Claude Code source) — preserved during build, not transformed
    ask: "Drop the special-case. Either all agents in .opencode/agents/ are build outputs (source of truth in agents/) or all are hand-maintained. A mixed model adds a category you have to document and defend for every future contributor."
    severity: minor
    category: complexity
  - target: "Success Criteria"
    claim: "Byte-compatible scorecard format between Claude Code and OpenCode output is a constraint that buys nothing — no downstream consumer exists that requires byte-level identity across two different runtimes. Semantic compatibility (same YAML schema, same fields) is the actual need."
    evidence: |
      Scorecard format byte-compatible with Claude Code output
    ask: "Relax to 'structurally compatible: same YAML schema, same field names, parseable by the same validator.' Byte-compatibility will constrain whitespace and key ordering for no consumer."
    severity: minor
    category: complexity
---

## Summary

The plan has one real design question it doesn't answer: whether a single-agent sequential orchestrator actually produces meaningfully differentiated output across four personas, or just four sections that read like one voice with four headings. The "CONTEXT RESET" instruction is a hope, not a mechanism. Ship the four standalone agents, observe whether anyone asks for a bundled invocation, and build the orchestrator only with contamination evidence in hand. The $RUN_DIR removal (Task 1) is correct work but underspecified — the replacement instruction text matters and isn't written down.
