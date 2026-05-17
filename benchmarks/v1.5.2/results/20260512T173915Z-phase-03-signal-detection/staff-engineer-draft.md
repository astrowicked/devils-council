---
persona: staff-engineer
artifact_sha256: 4097cffc6d2d2457226f79778b057ddb6614a24989906ac236fc328c144ea708
findings:
  - target: "Task 2: Create TypeScript signal detection module"
    claim: "signals.ts duplicates 270 lines of working Python detection logic into a second language that nothing in the plugin consumes today. The plan explicitly says Phase 4 will wire it — meaning this phase ships dead code."
    evidence: |
      The module is a pure function with no side effects, no file I/O, no external dependencies. It will be imported by the plugin entry point in Phase 4.
    ask: "Delete Task 2 entirely. Write signals.ts in Phase 4 when the consumer exists — you will know the actual interface requirements by then instead of guessing them now."
    severity: major
    category: complexity
  - target: "Task 3: council-review.md signal rules"
    claim: "The plan ships two detection mechanisms that cover the same signals for the same personas. The LLM-readable rules in council-review.md do the job today; the TypeScript module is supposed to do the same job deterministically tomorrow. That means either the rules become dead prose once Phase 4 lands, or you maintain two parallel truth sources for signal→persona mapping indefinitely."
    evidence: |
      This gives the council-review agent immediate soft signal detection — the LLM reads the artifact, spots patterns from the rules above, and activates the right bench lenses. Not deterministic like the TypeScript classifier, but functional for v1.2 without needing plugin infrastructure wired.
    ask: "State explicitly which one wins after Phase 4 ships. If the TypeScript classifier becomes authoritative, plan to delete the rules section from council-review.md in Phase 4's tasks. If both survive, explain why two detection paths that can disagree is better than one."
    severity: minor
    category: complexity
  - target: "Task 2 verify block"
    claim: "The verification command uses `require('typescript')` as a runtime dependency but the project has no `typescript` in its `package.json` — it falls through to `npx --yes typescript` which downloads the compiler at verify time. That's not a hermetic test; it's a prayer that npx works."
    evidence: |
      node -e "const ts = require('typescript'); const src = require('fs').readFileSync('plugins/signals.ts','utf8'); const result = ts.transpileModule(src, {compilerOptions:{module:ts.ModuleKind.ESNext,target:ts.ScriptTarget.ES2022}}); console.log(result.diagnostics?.length === 0 ? 'PASS: no diagnostics' : 'PASS: transpiles');
    ask: "If you keep Task 2 (I would not): add `typescript` as a devDependency and use `npx tsc --noEmit` as the single verify step. Drop the `require('typescript')` inline script."
    severity: minor
    category: correctness
---

## Summary

The plan has one structural waste problem: Task 2 creates a TypeScript module
with no consumer in this phase. The plan itself says Phase 4 will import it,
which means this phase ships dead code and then Phase 4 will inevitably
refactor the interface once it discovers what it actually needs from the
classifier. Tasks 1 and 3 are fine — porting the bench personas via
build.sh is mechanical and well-verified, and the LLM-readable signal
rules in council-review.md are immediately useful without infrastructure.
Ship Tasks 1 and 3 now; defer Task 2 to the phase that needs it.
