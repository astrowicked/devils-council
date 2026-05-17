---
persona: sre
artifact_sha256: 6cc365799ebb60dbf27c441d297db8a1b834bc223db6f4407ecd4ae5532bcc23
findings:
  - target: "**Threat model says:**"
    claim: "The threat model says 'no catastrophic backtracking' but doesn't name a specific regex timeout or kill mechanism. If even one of the 13 detectors hits a degenerate input, the review hangs the user's session with zero signal about what's stuck — no timeout, no circuit breaker, no log line naming which detector is spinning."
    evidence: |
      Bound regex execution: no catastrophic backtracking patterns, no unbounded loops. Each detector runs O(n) regex scans on bounded text input
    ask: "Name the wall-clock timeout per detector (50ms? 200ms?). If a detector exceeds it, what happens — skip and log, or abort the whole classify() call? Without a timeout, 'no catastrophic backtracking' is a claim about author intent, not a runtime guarantee."
    severity: major
    category: blast-radius
  - target: "**Operational concerns to evaluate:**"
    claim: "build.sh going from 5 to 9 personas with no added validation for the 4 new bench personas' unique characteristics (e.g., Codex delegation stripping) means a silent transform failure ships a broken persona file that silently produces garbage output at review time. There's no smoke test that the stripped persona still produces valid scorecard-shaped output."
    evidence: |
      Build.sh now transforms 9 personas (was 5) — more surface area for transform bugs
    ask: "Add a build-time assertion for each new bench persona: after stripping Codex delegation blocks, the persona body must still contain the ## Output contract section and the persona: field in the worked example. One grep per persona in the validation loop — takes 5 minutes, prevents a class of silent-corruption bugs."
    severity: major
    category: blast-radius
  - target: "**Operational concerns to evaluate:**"
    claim: "signals.ts is dead code until Phase 4 — meaning it ships untested against real artifacts for an entire phase. When Phase 4 wires it in, any bugs in the 13 detectors surface as persona-selection failures at runtime, not as build failures during this phase. The gap between 'code exists' and 'code runs in anger' is exactly where integration bugs hide."
    evidence: |
      "Not wired yet" — signals.ts exists but isn't called by anything until Phase 4. Dead code in the meantime?
    ask: "Ship at least one integration test that calls classify() against each of the 13 detector trigger patterns and asserts the expected SignalResult. Run it in this phase's CI, not Phase 4's. Dead code without tests is debt with compound interest."
    severity: major
    category: observability
  - target: "**Tasks:**"
    claim: "13 regex detectors with min_evidence thresholds but no mention of what happens when signal detection itself fails — a malformed regex, a null input, an artifact that's 200KB of binary garbage. The plan describes the happy path (classify returns SignalResult) but not the error path (classify throws or returns garbage and the orchestrator has no fallback)."
    evidence: |
      13 regex detectors, classify(text, hint?) → SignalResult. Regex-only (no AST). min_evidence threshold (default 1, performance uses 2). Pure function.
    ask: "Define the contract: if classify() throws or returns an empty/malformed SignalResult, does the orchestrator fall back to core-4-only? Or does the whole review abort? 'Pure function' describes purity constraints, not failure semantics."
    severity: minor
    category: blast-radius
---

## Summary

The plan's operational surface has three gaps that will bite at integration time. The regex timeout claim is an assertion about code style, not a runtime guarantee — one degenerate input to any of 13 detectors hangs the session with no kill signal. The build validation doesn't cover the new stripping behavior unique to bench personas, so a transform bug ships silently. And shipping 13 detectors as dead code for an entire phase means integration bugs compound until Phase 4 unwraps them all at once. None of these require architectural rework — they need a wall-clock timeout, two grep assertions in build.sh, and a test file that exercises classify() before Phase 4 wires it in.
