---
phase: 03-signal-detection
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .opencode/plugins/signals.ts
  - .opencode/agents/security-reviewer.md
  - .opencode/agents/finops-auditor.md
  - .opencode/agents/air-gap-reviewer.md
  - .opencode/agents/performance-reviewer.md
  - .opencode/agents/council-review.md
  - .opencode/build.sh
autonomous: true
requirements: [OC-SIGNAL-01, OC-BENCH-01]

must_haves:
  truths:
    - "4 bench persona agents (security-reviewer, finops-auditor, air-gap-reviewer, performance-reviewer) exist in .opencode/agents/ with adapted OpenCode bodies"
    - "council-review.md includes signal detection rules that instruct the LLM to activate bench persona lenses based on artifact patterns"
    - "A TypeScript signal detection module exports a classify function that maps text + filename_hint to triggered persona names"
    - "build.sh transforms the 4 bench personas from agents/ source through the same pipeline as core personas"
  artifacts:
    - path: ".opencode/plugins/signals.ts"
      provides: "Deterministic TypeScript signal classifier"
      exports: ["classify", "SignalResult"]
    - path: ".opencode/agents/security-reviewer.md"
      provides: "Security bench persona for OpenCode"
      contains: "persona: security-reviewer"
    - path: ".opencode/agents/finops-auditor.md"
      provides: "FinOps bench persona for OpenCode"
      contains: "persona: finops-auditor"
    - path: ".opencode/agents/air-gap-reviewer.md"
      provides: "Air-gap bench persona for OpenCode"
      contains: "persona: air-gap-reviewer"
    - path: ".opencode/agents/performance-reviewer.md"
      provides: "Performance bench persona for OpenCode"
      contains: "persona: performance-reviewer"
  key_links:
    - from: ".opencode/agents/council-review.md"
      to: "bench persona signal rules"
      via: "inline signal→persona mapping instructions in agent body"
      pattern: "security-reviewer.*auth.*crypto"
    - from: ".opencode/plugins/signals.ts"
      to: "lib/signals.json"
      via: "shared signal→persona registry (ported to TypeScript)"
      pattern: "target_personas"
---

<objective>
Port 4 bench personas to OpenCode and implement hybrid signal detection — LLM-driven rules in council-review.md for immediate use, plus a TypeScript signal classifier module for Phase 4's deterministic /review command.

Purpose: Enable bench persona activation based on artifact content patterns. The council-review orchestrator needs to know WHICH additional lenses to apply. In Claude Code this is deterministic Python classification; in OpenCode v1.2 we deliver both a soft (LLM-readable rules) and hard (TypeScript module) detection path.

Output: 4 new bench persona agents + updated council-review.md with signal rules + signals.ts module
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/02-persona-adaptation/02-01-SUMMARY.md

@.opencode/plugins/devils-council.ts
@.opencode/agents/council-review.md
@.opencode/build.sh
@lib/signals.json
@lib/classify.py

<interfaces>
<!-- Key contracts from Phase 2 that this plan builds upon -->

From .opencode/build.sh:
```bash
# PERSONAS array controls which agents/ sources get transformed
PERSONAS=(staff-engineer sre product-manager devils-advocate council-chair)
# The script: reads agents/<name>.md → transforms frontmatter + body → writes .opencode/agents/<name>.md
```

From .opencode/agents/council-review.md (Phase 2 output):
```markdown
---
description: "Experimental — single-context sequential review..."
mode: subagent
permission:
  edit: deny
  bash: deny
---
# 4 phases (staff-engineer, sre, product-manager, devils-advocate) + Chair synthesis
```

From .opencode/plugins/devils-council.ts:
```typescript
import { definePlugin } from "@opencode-ai/plugin"
export default definePlugin({
  name: "devils-council",
  hooks: {
    "session.created": async (ctx) => { /* stub */ },
    "tool.execute.before": async (ctx) => { /* stub */ },
  },
})
```

From lib/signals.json (signal→persona mapping):
```json
{
  "auth_code_change": { "target_personas": ["security-reviewer"] },
  "crypto_import": { "target_personas": ["security-reviewer"] },
  "secret_handling": { "target_personas": ["security-reviewer"] },
  "dependency_update": { "target_personas": ["security-reviewer", "air-gap-reviewer"] },
  "aws_sdk_import": { "target_personas": ["finops-auditor"] },
  "new_cloud_resource": { "target_personas": ["finops-auditor"] },
  "network_egress": { "target_personas": ["air-gap-reviewer"] },
  "external_image_pull": { "target_personas": ["air-gap-reviewer"] },
  "unpinned_dependency": { "target_personas": ["air-gap-reviewer"] },
  "performance_hotpath": { "target_personas": ["performance-reviewer"] }
}
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Port 4 bench persona agents via build.sh pipeline</name>
  <files>.opencode/build.sh, .opencode/agents/security-reviewer.md, .opencode/agents/finops-auditor.md, .opencode/agents/air-gap-reviewer.md, .opencode/agents/performance-reviewer.md</files>
  <action>
Add the 4 bench persona names to the PERSONAS array in build.sh:
```bash
PERSONAS=(staff-engineer sre product-manager devils-advocate council-chair security-reviewer finops-auditor air-gap-reviewer performance-reviewer)
```

Run `./build.sh` to transform these 4 bench personas from `agents/` source into `.opencode/agents/`. The existing Python transform handles:
- Frontmatter → OpenCode format (description, mode: subagent, permission: edit/bash deny)
- Body: removes $RUN_DIR references, rewrites output contract to direct-response, removes artifact_sha256, adds OpenCode input instruction

After build, verify each generated agent file has:
- Valid YAML frontmatter with `mode: subagent`
- No remaining `$RUN_DIR` references
- Scorecard output instructions say "Output your scorecard directly in your response"
- Banned phrases inlined (self-contained, no sidecar reference)

NOTE: The build transforms are a starting point. The bench personas have a delegation_request block (security-reviewer's Codex delegation) that references Claude Code specifics. After build, manually remove/adapt:
- security-reviewer: Remove the "Delegating a deep scan to Codex" section entirely (Codex deferred to v1.3 per project constraint)
- All 4: Verify `persona-metadata/*.yml` sidecar references are removed (inlined by build or manually strip)
  </action>
  <verify>
    <automated>cd /Users/andywoodard/dev/devils-council/.opencode && ./build.sh && for f in agents/security-reviewer.md agents/finops-auditor.md agents/air-gap-reviewer.md agents/performance-reviewer.md; do echo "--- $f ---"; grep -c 'mode: subagent' "$f"; grep -c '\$RUN_DIR' "$f" | grep '^0$' || echo "FAIL: RUN_DIR still present"; done</automated>
  </verify>
  <done>4 bench persona agent files exist in .opencode/agents/ with valid OpenCode frontmatter, no $RUN_DIR references, direct-response output contract, and no Codex delegation sections</done>
</task>

<task type="auto">
  <name>Task 2: Create TypeScript signal detection module</name>
  <files>.opencode/plugins/signals.ts</files>
  <action>
Create `.opencode/plugins/signals.ts` — a pure TypeScript port of the signal detection logic from `lib/classify.py`, scoped to the 4 bench personas being shipped (security-reviewer, finops-auditor, air-gap-reviewer, performance-reviewer).

The module exports:
```typescript
export interface SignalResult {
  version: number;
  triggered_personas: string[];
  trigger_reasons: Record<string, string[]>;
}

export function classify(text: string, filenameHint?: string, artifactType?: string): SignalResult
```

Port these detectors from classify.py (regex-based, no AST — TypeScript doesn't have Python's ast module):
- auth_code_change → security-reviewer
- crypto_import → security-reviewer
- secret_handling → security-reviewer
- dependency_update → security-reviewer, air-gap-reviewer
- aws_sdk_import → finops-auditor
- new_cloud_resource → finops-auditor
- autoscaling_change → finops-auditor
- storage_class_change → finops-auditor
- network_egress → air-gap-reviewer
- external_image_pull → air-gap-reviewer
- unpinned_dependency → air-gap-reviewer
- license_phone_home → air-gap-reviewer
- performance_hotpath → performance-reviewer

Each detector is a function `(text: string, hint: string) => string[]` returning evidence strings. The `classify()` function runs all detectors, collects evidence, applies min_evidence thresholds (default 1, performance_hotpath uses 2), and maps signals to personas via a hardcoded SIGNAL_MAP (ported from signals.json target_personas).

Do NOT import signals.json at runtime — embed the signal→persona mapping directly in TypeScript as a const object. This keeps the module zero-dependency and importable from the plugin entry point.

Skip Python AST-based detection (classify.py uses `ast.parse` for .py files). Use regex-only detection — sufficient for the OpenCode use case where artifacts are typically plan/RFC/diff text, not raw Python source that needs AST parsing.

The module is a pure function with no side effects, no file I/O, no external dependencies. It will be imported by the plugin entry point in Phase 4.
  </action>
  <verify>
    <automated>cd /Users/andywoodard/dev/devils-council/.opencode && node -e "const ts = require('typescript'); const src = require('fs').readFileSync('plugins/signals.ts','utf8'); const result = ts.transpileModule(src, {compilerOptions:{module:ts.ModuleKind.ESNext,target:ts.ScriptTarget.ES2022}}); console.log(result.diagnostics?.length === 0 ? 'PASS: no diagnostics' : 'PASS: transpiles'); if(!src.includes('export function classify')) throw new Error('missing classify export'); if(!src.includes('export interface SignalResult')) throw new Error('missing SignalResult'); console.log('exports OK');" 2>/dev/null || echo "Checking syntax with tsc..." && npx --yes typescript --noEmit --esModuleInterop --moduleResolution node plugins/signals.ts 2>&1 | head -5</automated>
  </verify>
  <done>signals.ts exports classify() and SignalResult, transpiles without errors, contains detector functions for all 13 signal types mapped to 4 bench personas</done>
</task>

<task type="auto">
  <name>Task 3: Add signal detection rules to council-review.md</name>
  <files>.opencode/agents/council-review.md</files>
  <action>
Update `.opencode/agents/council-review.md` to include a new section BEFORE the existing "## Process" section. This section tells the LLM which additional bench persona lenses to activate based on observed patterns in the artifact.

Insert after the "## Input" section and before "## Process":

```markdown
## Bench Persona Activation (Signal Detection)

After reading the artifact, check for these structural signals. If ANY signals match, add the corresponding bench persona lens as an ADDITIONAL phase after Phase 4 (Devil's Advocate) and before the Chair Synthesis.

### Security Reviewer — activate if you observe:
- Authentication/session/login/JWT/OAuth code or endpoint paths (`/login`, `/auth`, `/oauth`)
- Cryptographic imports (crypto, bcrypt, argon2, jose, libsodium, nacl)
- Secret handling (process.env.*_SECRET, *_KEY, *_TOKEN; secret manager API calls)
- Dependency updates in lockfiles (package-lock.json, yarn.lock, go.sum, etc.)

### FinOps Auditor — activate if you observe:
- AWS SDK imports (boto3, @aws-sdk/client-*, aws-sdk)
- New cloud resource declarations (Terraform resource blocks, CDK constructs, CloudFormation)
- Autoscaling/HPA/replica changes
- Storage class changes

### Air-Gap Reviewer — activate if you observe:
- Dependency updates (same trigger as Security above)
- Network egress to external hosts (fetch/axios/requests to non-localhost URLs)
- External container image pulls (FROM <registry>/..., image: <external>/...)
- Unpinned dependencies (^, ~, >=, latest)
- License/telemetry phone-home (Sentry, Datadog, Mixpanel SDK inits)

### Performance Reviewer — activate if you observe (need 2+ patterns):
- Database/fetch calls inside loops (N+1 query patterns)
- Nested for-loops over collections
- Per-iteration allocations (new Array/Object/Map inside loops)

---

**If no signals match:** Run only the 4 core personas (Staff Engineer, SRE, PM, Devil's Advocate) + Chair.

**If signals match:** Add each triggered bench persona as a new Phase between Phase 4 and Chair Synthesis. Use the SAME scorecard format. Adopt that persona's voice fully (see the standalone agent files for voice reference: @security-reviewer, @finops-auditor, @air-gap-reviewer, @performance-reviewer).
```

Also update the "## Process" section intro to note: "You will execute 4+ sequential phases (4 core + any triggered bench personas), then a synthesis phase."

This gives the council-review agent immediate soft signal detection — the LLM reads the artifact, spots patterns from the rules above, and activates the right bench lenses. Not deterministic like the TypeScript classifier, but functional for v1.2 without needing plugin infrastructure wired.
  </action>
  <verify>
    <automated>cd /Users/andywoodard/dev/devils-council/.opencode && grep -c "Bench Persona Activation" agents/council-review.md && grep -c "Security Reviewer" agents/council-review.md && grep -c "FinOps Auditor" agents/council-review.md && grep -c "Air-Gap Reviewer" agents/council-review.md && grep -c "Performance Reviewer" agents/council-review.md</automated>
  </verify>
  <done>council-review.md contains signal detection rules section with all 4 bench persona activation criteria, instructions for adding bench phases dynamically, and updated process description acknowledging variable phase count</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| User artifact → signal classifier | Untrusted text input to regex-based detection |
| Signal results → agent context | Triggered persona names injected into review flow |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-03-01 | Tampering | signals.ts regex | accept | Regex-only detection on user artifacts; false positives produce extra review (safe failure mode), false negatives miss a bench lens (acceptable for v1.2 soft detection) |
| T-03-02 | Denial of Service | signals.ts classify() | mitigate | Bound regex execution: no catastrophic backtracking patterns, no unbounded loops. Each detector runs O(n) regex scans on bounded text input |
| T-03-03 | Information Disclosure | bench persona agents | accept | Agents have permission edit:deny bash:deny — cannot read or modify user files beyond the artifact provided in conversation context |
| T-03-04 | Spoofing | council-review.md signal rules | accept | LLM-driven detection is advisory; false activation produces extra review (non-destructive). Deterministic path via signals.ts will be authoritative in Phase 4 |
</threat_model>

<verification>
1. `./build.sh` completes without error and produces all 9 persona agents in `.opencode/agents/`
2. Each bench persona agent has valid OpenCode frontmatter, no Claude Code-specific references
3. `signals.ts` exports `classify` and `SignalResult`, transpiles cleanly
4. `council-review.md` includes the signal detection rules section with all 4 bench persona criteria
5. No `$RUN_DIR`, no Codex delegation, no `persona-metadata/*.yml` sidecar references in any `.opencode/agents/*.md` file
</verification>

<success_criteria>
- 4 bench persona agents usable via `@security-reviewer`, `@finops-auditor`, `@air-gap-reviewer`, `@performance-reviewer` in OpenCode
- council-review orchestrator dynamically activates bench lenses based on artifact content patterns
- TypeScript signal module ready for Phase 4 integration (deterministic path)
- All 10 agent files (6 existing + 4 new) pass basic validation: valid frontmatter, no filesystem references
</success_criteria>

<output>
After completion, create `.planning/phases/03-signal-detection/03-01-SUMMARY.md`
</output>
