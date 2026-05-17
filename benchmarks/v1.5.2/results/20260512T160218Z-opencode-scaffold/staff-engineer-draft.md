---
persona: staff-engineer
artifact_sha256: 5dc76bee216535d7cef1b1bf2dca72a2b5a09561c2a95695b810e83fc29000f7
findings:
  - target: "Task 2: Create OpenCode agent files + build script"
    claim: "A Python3 inline YAML parser inside a shell script is a second build system for a project that doesn't ship compiled code today. The transformation (strip some frontmatter keys, add two new ones) is a sed one-liner or a 15-line yq pipeline — Python adds a runtime dependency and a maintenance surface for no gain."
    evidence: |
      Uses Python3 inline to parse YAML frontmatter, strip Claude Code fields, add OpenCode fields (mode: subagent, permission: {edit: deny, bash: deny})
    ask: "Replace the Python inline with yq (already listed in STACK.md prerequisites) or plain sed. If the transform is too complex for that, the transform is doing too much."
    severity: minor
    category: complexity
  - target: "Task 1: Create npm package scaffold + plugin entry point"
    claim: "A TypeScript plugin entry point with tsconfig.json implies a compile step, a node_modules tree, and a build-before-test loop — but the plan's own 'definePlugin with stub hooks' has zero runtime logic today. A plain .js or .mjs file removes tsc, tsconfig, and the compile step entirely until there is actual typed logic to protect."
    evidence: |
      .opencode/tsconfig.json (strict, ESNext module)
    ask: "Ship a plain .mjs with JSDoc types until the plugin has enough logic to justify a compile step. Delete tsconfig.json from this phase."
    severity: minor
    category: complexity
  - target: "Task 3: Validate npm publishability"
    claim: "npm publish validation is premature — there is no consumer, no registry target, and no CI pipeline to publish through. You are testing a distribution mechanism for a plugin that has stub hooks and zero features. This entire task can be deferred to the phase where you actually ship a first usable version."
    evidence: |
      npm pack --dry-run verification
    ask: "Cut Task 3 entirely. Revisit publishability when there is a feature worth publishing."
    severity: major
    category: complexity
  - target: "Task 2: Create OpenCode agent files + build script"
    claim: "The plan generates exactly 5 agents from a directory that already contains 17 persona files. The selection logic (which 5?) lives only in the build script, creating a second source of truth for 'which personas are core.' If the build script just transforms all of agents/*.md, the selection problem disappears and the script shrinks."
    evidence: |
      Generates 5 agent files: staff-engineer, sre, product-manager, devils-advocate, council-chair
    ask: "Transform all agents/*.md unconditionally. Let OpenCode's entrypoint (or a manifest) decide which to invoke at runtime — same as the Claude Code plugin does today."
    severity: minor
    category: complexity
---

## Summary

The plan introduces two layers of build machinery (Python-in-shell YAML
transformer + TypeScript compilation) and a full npm publish validation pass
for a scaffold that currently does nothing. The real deliverable is: agent
markdown files with different frontmatter live in `.opencode/`. That's a
file-copy-and-sed job. Task 3 is pure speculative packaging work with no
consumer; cut it and reclaim the complexity budget for the phase where you
actually wire up review orchestration in OpenCode.
