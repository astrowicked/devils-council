# Phase 5: Scaffolder Skill - Research

**Researched:** 2026-04-28
**Domain:** Interactive Claude Code plugin skill (AskUserQuestion wizard + deterministic validation + workspace write)
**Confidence:** HIGH

## Summary

Phase 5 delivers `skills/create-persona/SKILL.md` — an interactive wizard that scaffolds a custom persona through field-by-field `AskUserQuestion` prompts, coaches voice-kit quality through inline heuristics, validates the output against `scripts/validate-personas.sh`, and writes the result to a `${CLAUDE_PLUGIN_DATA}` workspace.

The implementation is primarily a SKILL.md prompt file (instructing Claude how to behave) plus a helper script for overlap detection. The "render-persona.py" heuristic validator named in the ROADMAP is explicitly redefined by user decision (CONTEXT.md D-05, Specifics section) as inline validation logic within the SKILL.md prompt — not a separate Python script. The scaffolder test harness (`test-persona-scaffolder.sh`) is the only new executable script.

**Primary recommendation:** Implement as two plans: (1) the SKILL.md wizard + inline coaching logic, and (2) test harness + README/CHANGELOG documentation. The skill is self-contained (no agent spawning, no Codex delegation) and uses only tools already proven in the project: `AskUserQuestion`, `Read`, `Write`, `Bash`, `Glob`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Linear wizard — field-by-field in fixed order: name -> tier -> primary_concern -> characteristic_objections -> banned_phrases -> worked examples (good + bad). Each step is one `AskUserQuestion` call.
- **D-02:** End preview only — collect all fields, then show the full agent file + sidecar before writing. One confirmation point. No progressive preview.
- **D-03:** Suggest from existing data — show available signal IDs from `lib/signals.json` for triggers, show baseline banned phrases as starting point to extend, show existing persona primary_concerns as negative examples to avoid duplication.
- **D-04:** Warn with comparison on overlap — when user's banned-phrase set has >30% overlap with a shipped persona, show which phrases overlap, name the conflicting persona, explain why differentiation matters, then ask: "Keep these or diversify?" Non-blocking.
- **D-05:** Inline coaching on objection quality — if a characteristic_objection contains one of the persona's own banned phrases, flag it immediately. Catches contradictions before validation.
- **D-06:** Print ready-to-run commands after writing — display exact `cp` or `mv` commands the user can paste to move files from `${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/` to their plugin directory.
- **D-07:** Persistent workspace by slug — workspace persists across runs. If slug already exists, prompt for overwrite confirmation.
- **D-08:** Translated guidance on validation failure — scaffolder interprets `validate-personas.sh` error codes (R1-R9, W1-W3) into plain-English guidance.
- **D-09:** 3 retries then bail — three attempts to fix validation errors by looping back. After 3, write anyway with warning.

### Claude's Discretion
- Exact wording of AskUserQuestion option labels and descriptions
- Order of suggestions presented for triggers and banned phrases
- Whether to show all 16 existing persona concerns at once or filter to same-tier personas only
- Format of the end-preview (markdown table vs rendered file content)

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCAF-01 | Interactive scaffolder using AskUserQuestion; collects all fields; refuses to write without minimums (3+ objections, 5+ banned phrases, 2 good + 1 bad examples) | AskUserQuestion tool pattern fully documented; field minimums match PERSONA-SCHEMA.md rules R5/R6; note ROADMAP SC-1 says >=5 banned phrases (stricter than validator's R6 >=1) |
| SCAF-02 | Writes to `${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/` with agents/ and persona-metadata/ as siblings | CLAUDE_PLUGIN_DATA expansion confirmed in plugin system; workspace layout mirrors repo root so validate-personas.sh sidecar resolution works unchanged |
| SCAF-03 | Runs validate-personas.sh against output; failed validation loops back to relevant question | Validator exit codes + error format documented; R1-R9 codes map 1:1 to specific fields; D-08 requires translated guidance |
| SCAF-04 | Coaches voice-rubric distinctness (>30% overlap warning) | 16 persona-metadata/*.yml sidecars exist as comparison set; overlap calculation is set-intersection arithmetic on banned_phrases; D-04 makes this non-blocking |
| SCAF-05 | README + CHANGELOG v1.1 document scaffolder workflow | README section needed after existing "Persona Roster" table; CHANGELOG needs [Unreleased] -> v1.1 entry |
</phase_requirements>

## Standard Stack

### Core

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SKILL.md (Claude Code skill format) | Current plugin system | Interactive wizard entrypoint | All project skills follow this format; auto-registers via `skills/` directory convention [VERIFIED: local project structure] |
| `AskUserQuestion` tool | Current Claude Code | Field-by-field user input collection | First-party Claude Code tool for interactive input; documented in official interactive-commands reference [VERIFIED: claude-plugins-official/plugin-dev docs] |
| `validate-personas.sh` | Existing (R1-R9, W1-W3) | Schema validation of scaffolded output | Already exists and is proven; runs deterministically with exit 0/1/2 [VERIFIED: scripts/validate-personas.sh in repo] |
| `${CLAUDE_PLUGIN_DATA}` | Current plugin system | Persistent workspace directory | Expands to per-plugin data dir; survives plugin updates [VERIFIED: CLAUDE.md §plugin references + plugin docs] |

### Supporting

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `lib/signals.json` | Present trigger options to user for bench personas | Read during scaffolder execution to show available signal IDs [VERIFIED: exists at lib/signals.json] |
| `persona-metadata/*.yml` (16 files) | Overlap comparison set for voice coaching | Read to compute banned-phrase overlap percentages [VERIFIED: 16 files exist in persona-metadata/] |
| `yq` / `python3+PyYAML` | Parse sidecar YAML for overlap detection | Used by validate-personas.sh; scaffolder uses same tooling if shell script needed [VERIFIED: both available on system] |
| `jq` | Parse signals.json for trigger ID extraction | Already in project dependency chain [VERIFIED: jq 1.7.1 available] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Inline SKILL.md coaching logic | Separate `render-persona.py` Python script | CONTEXT.md explicitly decides inline logic over separate script; avoids new runtime dependency; keeps coaching within Claude's reasoning |
| AskUserQuestion per-field | Single form-like prompt | Claude Code AskUserQuestion supports 1-4 questions per call but the linear wizard pattern (one per field) gives better coaching opportunities at each step |
| Writing directly to plugin `agents/` | Writing to `${CLAUDE_PLUGIN_DATA}` workspace | D-06 locks the workspace pattern; plugin cache is read-only post-install so direct write would fail for installed plugins |

## Architecture Patterns

### Recommended Project Structure (new files this phase creates)

```
skills/
  create-persona/
    SKILL.md              # Interactive wizard entrypoint
    reference/
      field-minimums.md   # Quick-reference for validation rules (optional supporting file)
scripts/
  test-persona-scaffolder.sh  # Test harness (pass case + reject case)
```

### Pattern 1: Linear Wizard via AskUserQuestion

**What:** Each structured field gets its own `AskUserQuestion` call in fixed order. Claude processes the answer, applies inline coaching checks, then moves to next field.

**When to use:** When fields are ordered with dependencies (e.g., tier determines whether triggers are asked; banned_phrases influences objection validation).

**Example (from official docs, adapted):**

```markdown
---
name: create-persona
description: "Interactive scaffolder for custom devils-council personas. Guides through voice-kit fields, validates against schema, coaches distinctness."
allowed-tools: [AskUserQuestion, Read, Write, Bash, Glob]
user-invocable: true
---

# Create Persona

## Step 1: Persona Name

Use AskUserQuestion:

Question: "What should this persona be named? (kebab-case, e.g., 'cost-hawk')"
Header: "Name"
Options:
  - [no options — free text via "Other"]

## Step 2: Tier Selection

Use AskUserQuestion:

Question: "Which tier is this persona?"
Header: "Tier"
Options:
  - core (Always invoked on every review)
  - bench (Auto-triggered by structural signals)

## Step 3: Primary Concern
...
```

[VERIFIED: AskUserQuestion tool pattern from claude-plugins-official/plugin-dev/skills/command-development/references/interactive-commands.md]

### Pattern 2: Inline Coaching (heuristic validation before disk write)

**What:** Between collecting a field value and proceeding to the next step, Claude checks the value against heuristic rules and flags issues immediately — no disk write needed.

**When to use:** For D-05 (objection-contains-banned-phrase detection) and D-04 (overlap comparison). These are in-memory checks Claude performs on the collected data.

**Implementation:** The SKILL.md body instructs Claude:

```markdown
## Coaching: Objection Quality Check (D-05)

After collecting characteristic_objections, check each objection against the
persona's own banned_phrases collected in the previous step. If ANY objection
contains a banned phrase (case-insensitive substring match):

1. Flag the specific objection and the matching banned phrase
2. Ask: "Your objection '[objection]' uses a phrase you banned ('[phrase]').
   Rephrase or keep as-is?"
3. Use AskUserQuestion with options:
   - Rephrase (Ask me for a replacement)
   - Keep (I intentionally quote it)
```

[ASSUMED — based on Claude Code skill behavior: Claude follows SKILL.md instructions as behavioral directives]

### Pattern 3: Workspace Layout Mirroring Repo Root

**What:** The scaffolder writes to `${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/` with a directory structure that mirrors the repo root for validation:

```
${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/
  agents/<slug>.md
  persona-metadata/<slug>.yml
  lib/signals.json  (symlink or copy from plugin root)
```

**Why:** `validate-personas.sh` resolves sidecars via `REPO_ROOT/persona-metadata/<slug>.yml`. By mirroring the structure, the validator works unchanged when invoked with `--signals` override and the file path pointing to the workspace.

**Implementation detail:** The validator determines `REPO_ROOT` from its own location (`SCRIPT_DIR/..`). When invoked on a workspace file, use the single-file mode: `validate-personas.sh <workspace>/agents/<slug>.md --signals <workspace>/lib/signals.json`. The sidecar resolution uses `REPO_ROOT/persona-metadata/` which won't find the workspace sidecar — so the scaffolder must either:
- (a) Invoke the validator from within the workspace using a copy of the validator script, OR
- (b) Create a temporary symlink structure, OR
- (c) Use the validator's fallback path (when no sidecar exists, it reads frontmatter directly — the "legacy path")

Examining the validator code (line 429-439): if no sidecar file exists at `${REPO_ROOT}/persona-metadata/${persona_slug}.yml`, it falls back to reading custom fields from the agent frontmatter itself ("Legacy: custom fields live in agent frontmatter alongside name/description/model"). This means **the scaffolder can embed all custom fields in the agent frontmatter for validation purposes**, then split into frontmatter + sidecar as a post-validation step. This is the cleanest path.

**Alternative (preferred):** Write the agent file with ALL fields in frontmatter (legacy mode). Run validator in single-file mode. After validation passes, split the file into `agents/<slug>.md` (standard subagent fields only) + `persona-metadata/<slug>.yml` (custom fields only). This avoids sidecar-resolution complexity entirely.

[VERIFIED: validate-personas.sh lines 426-439 confirm legacy fallback path when sidecar is absent]

### Anti-Patterns to Avoid

- **Spawning subagents from the scaffolder:** The scaffolder is a SKILL, not a command that needs Agent spawns. It should use AskUserQuestion directly. Skills CAN use AskUserQuestion when listed in allowed-tools.
- **Writing to `agents/` directly in the plugin cache:** Plugin cache is read-only post-install. Always write to `${CLAUDE_PLUGIN_DATA}` workspace.
- **Relying on Claude's arithmetic for overlap calculation:** D-04 requires >30% overlap detection. Rather than trusting Claude to count correctly, use a Bash tool invocation to do the set-intersection arithmetic deterministically (e.g., a small inline `python3 -c` or shell loop).
- **Skipping the end-preview (D-02):** Users must see the full generated file before it's written. Never write first and show second.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| YAML frontmatter schema validation | Custom regex in SKILL.md | `validate-personas.sh` (already exits 0/1 with rule codes) | 820-line battle-tested validator with edge cases already handled |
| Signal ID enumeration | Hardcoded list in skill | `jq -r '.signals \| keys[]' ${CLAUDE_PLUGIN_ROOT}/lib/signals.json` via Bash | Stays in sync automatically as signals grow |
| Sidecar overlap calculation | Claude mental math | `python3 -c` or shell loop via Bash tool | Deterministic arithmetic; no LLM hallucination risk on set math |
| Existing persona primary_concerns | Hardcoded list | `yq eval '.primary_concern' persona-metadata/*.yml` via Bash/Glob | Always current with the shipped roster |

**Key insight:** The scaffolder is a prompt-engineering artifact (SKILL.md), not a code artifact. Its "logic" is Claude following instructions. But any **arithmetic, string-matching, or file-system operations** should be delegated to Bash/Python via the Bash tool to maintain determinism.

## Common Pitfalls

### Pitfall 1: Validator Sidecar Resolution Mismatch

**What goes wrong:** Scaffolder writes `agents/<slug>.md` + `persona-metadata/<slug>.yml` to workspace, but `validate-personas.sh` looks for the sidecar at `REPO_ROOT/persona-metadata/` (relative to the script's own location), not the workspace.

**Why it happens:** The validator hardcodes `REPO_ROOT` from `SCRIPT_DIR/..`. When invoked on a file outside the repo tree, sidecar resolution breaks.

**How to avoid:** Use the validator's legacy fallback: put ALL custom fields in the agent frontmatter for validation, then split into agent + sidecar after validation passes. OR copy `validate-personas.sh` into the workspace and invoke from there. The legacy-fallback approach is cleaner and requires no script duplication.

**Warning signs:** Validator exits 0 with no errors but the persona is actually incomplete (sidecar fields were never checked because they weren't found).

### Pitfall 2: SCAF-01 Minimum Counts Diverge from Validator

**What goes wrong:** ROADMAP SC-1 requires >=5 banned_phrases and >=3 characteristic_objections for the scaffolder. But `validate-personas.sh` only enforces R5 (>=3 objections) and R6 (>=1 banned phrase). A persona with 3 banned phrases passes the validator but fails the scaffolder's quality bar.

**Why it happens:** The validator enforces the schema minimum; the scaffolder enforces a higher coaching bar.

**How to avoid:** The SKILL.md must enforce its own minimums (>=5 banned_phrases, >=3 objections, 2 good + 1 bad examples) BEFORE invoking the validator. The validator is a safety net, not the quality gate. The scaffolder refuses to proceed to the preview step if its own minimums aren't met.

**Warning signs:** A persona passes `validate-personas.sh` but wouldn't pass the blinded-reader test because it has too few voice anchors.

### Pitfall 3: AskUserQuestion "Other" Response Handling

**What goes wrong:** AskUserQuestion always offers an "Other" option that lets users type freeform text. If the scaffolder doesn't handle unexpected freeform responses gracefully (e.g., user types "skip" or gives a malformed response), it can produce invalid output.

**Why it happens:** Claude Code's AskUserQuestion automatically adds "Other" to every question. The skill cannot prevent this.

**How to avoid:** After each AskUserQuestion response, validate the answer format inline (e.g., check that `name` is kebab-case, check that `tier` is one of core/bench). If invalid, explain the constraint and re-ask.

**Warning signs:** Validator failures on R2 (invalid tier value) or R1 (unparseable YAML) from freeform input that wasn't sanitized.

### Pitfall 4: Shell-Injection in SKILL.md

**What goes wrong:** This project has a `userConfig.shell_inject_guard` that blocks unauthorized `!`<cmd>`` patterns in skills/commands. If the scaffolder SKILL.md uses shell-injection (`` !`...` ``), it must be allowlisted or it will be blocked by the PreToolUse hook.

**Why it happens:** TD-04 (Phase 1) ships a PreToolUse hook that dry-runs shell-inject patterns. New skills with shell-inject need allowlist entries.

**How to avoid:** Use the `Bash` tool for all runtime shell operations rather than `` !`...` `` shell-injection in the SKILL.md. Shell-injection is parse-time (before Claude sees the prompt) — useful for loading data into the prompt but not for interactive runtime behavior. For the scaffolder, all file reads and validation invocations should use the Bash tool.

**Warning signs:** Scaffolder invocation blocked with a PreToolUse hook rejection error.

### Pitfall 5: Workspace Persistence Confusion

**What goes wrong:** D-07 says workspace persists by slug. If a user runs the scaffolder twice with the same slug without confirming overwrite, they lose previous work.

**Why it happens:** `${CLAUDE_PLUGIN_DATA}` is persistent across sessions.

**How to avoid:** At the very start of the scaffolder (after collecting the persona name/slug), check if `${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/` already exists. If it does, use AskUserQuestion to confirm overwrite before proceeding.

**Warning signs:** User reports losing a partially-refined persona they were iterating on.

## Code Examples

### Example 1: SKILL.md Frontmatter (verified pattern)

```yaml
---
name: create-persona
description: "Interactive scaffolder for custom devils-council personas. Collects voice-kit fields, validates schema, coaches voice distinctness. Writes to plugin data workspace."
allowed-tools: [AskUserQuestion, Read, Write, Bash, Glob]
user-invocable: true
argument-hint: "[persona-slug]"
---
```

[VERIFIED: skill frontmatter schema matches existing `skills/*/SKILL.md` patterns in the project + official docs at code.claude.com/docs/en/skills]

### Example 2: Validator Invocation from Workspace (Bash tool pattern)

```bash
# Write the all-in-one agent file (legacy format with custom fields in frontmatter)
# Then validate:
WORKSPACE="${CLAUDE_PLUGIN_DATA}/create-persona-workspace/${SLUG}"
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-personas.sh" \
  "${WORKSPACE}/agents/${SLUG}.md" \
  --signals "${CLAUDE_PLUGIN_ROOT}/lib/signals.json"
```

[VERIFIED: validate-personas.sh accepts single-file positional arg + --signals override; legacy path reads custom fields from frontmatter when sidecar absent]

### Example 3: Overlap Calculation (deterministic via Bash tool)

```bash
# Compare user's banned phrases against all shipped persona sidecars
USER_BANS="consider|think about|be aware of|premature optimization|..."
OVERLAP_REPORT=$(python3 -c "
import yaml, sys, os, glob

user_bans = set(sys.argv[1].lower().split('|'))
baseline = {'consider', 'think about', 'be aware of'}
user_role_specific = user_bans - baseline

metadata_dir = '${CLAUDE_PLUGIN_ROOT}/persona-metadata'
warnings = []
for f in sorted(glob.glob(os.path.join(metadata_dir, '*.yml'))):
    slug = os.path.basename(f).replace('.yml', '')
    with open(f) as fh:
        data = yaml.safe_load(fh) or {}
    shipped_bans = set(b.lower() for b in data.get('banned_phrases', []))
    shipped_role_specific = shipped_bans - baseline
    if not shipped_role_specific:
        continue
    overlap = user_role_specific & shipped_role_specific
    min_set = min(len(user_role_specific), len(shipped_role_specific))
    if min_set > 0:
        pct = len(overlap) * 100 // min_set
        if pct > 30:
            warnings.append(f'{slug}: {pct}% overlap ({sorted(overlap)})')
for w in warnings:
    print(w)
" "$USER_BANS")
```

[ASSUMED — implementation detail; pattern is sound given python3+PyYAML availability confirmed]

### Example 4: Agent File Template (what scaffolder produces)

```markdown
---
name: <slug>
description: "<one-sentence description under 300 chars>"
tools: [Read, Grep, Glob]
model: inherit
skills:
  - persona-voice
  - scorecard-schema
tier: <core|bench>
primary_concern: "<one-sentence ending with ?>"
blind_spots:
  - "<item 1>"
  - "<item 2>"
characteristic_objections:
  - "<verbatim phrase 1>"
  - "<verbatim phrase 2>"
  - "<verbatim phrase 3>"
banned_phrases:
  - "consider"
  - "think about"
  - "be aware of"
  - "<role-specific 1>"
  - "<role-specific 2>"
triggers:     # only for bench tier
  - <signal_id>
tone_tags: [<tag1>, <tag2>]
---

<persona body: value system anchor description>

## How you review

<standard review instructions — can reference staff-engineer.md as template>

## Examples

### Good (what this persona ships)

- target: `<specific line or heading>`
  claim: "<specific failure mode in persona's voice>"
  evidence: |
    <verbatim 8+ char substring>
  ask: "<actionable remediation>"
  severity: major
  category: <free-text>

- target: `<another specific reference>`
  claim: "<another specific finding>"
  evidence: |
    <verbatim evidence>
  ask: "<actionable ask>"
  severity: minor
  category: <free-text>

### Bad (what this persona refuses to ship)

- target: `<vague reference>`
  claim: "<uses banned phrase or is generic>"
  ask: "<vague non-actionable ask>"
  # Rejected: <explanation of why this is bad>
```

[VERIFIED: matches existing persona file structure in agents/staff-engineer.md + PERSONA-SCHEMA.md requirements]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hand-write persona files following AUTHORING.md | Interactive scaffolder with coaching | Phase 5 (this phase) | Lowers barrier to custom persona creation; catches quality issues before commit |
| Custom fields in agent frontmatter (legacy) | Sidecar pattern (persona-metadata/*.yml) | Phase 4 (already shipped) | Scaffolder must produce BOTH files; validator supports both paths |
| `Task` tool name for subagent spawning | `Agent` tool (v2.1.63+) | 2025 | Scaffolder doesn't spawn agents, but note in case future iteration needs it |

**Deprecated/outdated:**
- `agents/README.md` — renamed to `agents/AUTHORING.md` per TD-06; scaffolder should reference AUTHORING.md

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | AskUserQuestion can be listed in `allowed-tools` for a SKILL.md and works correctly (user sees the question UI) | Architecture Patterns | If wrong, scaffolder cannot be interactive; would need to be a `commands/*.md` instead |
| A2 | `${CLAUDE_PLUGIN_DATA}` is writable by the Write tool during skill execution | Architecture Patterns | If wrong, workspace pattern fails entirely; would need alternative write location |
| A3 | Bash tool can invoke `validate-personas.sh` with `${CLAUDE_PLUGIN_ROOT}` path resolution during skill execution | Architecture Patterns | If wrong, validation loop cannot work; would need the model to parse manually |
| A4 | "render-persona.py" named in ROADMAP is confirmed as inline SKILL.md logic per CONTEXT.md Specifics section (no separate Python file) | Don't Hand-Roll | If ROADMAP literal name is enforced by verifier, would need a `render-persona.py` script even if logic is inline |

**Note on A1:** The Claude Code changelog entry (line 1337 in cache/changelog.md) mentions a fix for "Fixed interactive tools (e.g., AskUserQuestion) being silently auto-allowed when listed in a skill's allowed-tools, bypassing the permission prompt and running with empty answers." This confirms AskUserQuestion IS supported in skills' allowed-tools — the fix was about permission handling, not about it being unsupported.

## Open Questions (RESOLVED)

1. **Sidecar split timing in workspace**
   - What we know: Validator supports legacy (frontmatter-only) path. Shipped personas use sidecar pattern.
   - What's unclear: Should scaffolder output in workspace match shipped format (agent + sidecar) for user familiarity, or use legacy format for simpler validation?
   - Recommendation: Write in legacy format for validation, then split into agent + sidecar as final step. Output to user shows the split format (what they'll actually install). Document this in the SKILL.md body.

2. **Test harness for interactive skill**
   - What we know: `test-persona-scaffolder.sh` needs both pass and reject cases per SC-4.
   - What's unclear: How to "script input" to an AskUserQuestion-based skill. Claude Code doesn't expose a test harness for interactive skills.
   - Recommendation: Test the scaffolder's OUTPUT (validate the generated files), not the interaction flow. Create pre-built valid and invalid persona files representing what the scaffolder would produce, then run them through validate-personas.sh. For the reject case, verify that a persona with <3 objections or <5 banned phrases would be rejected by the scaffolder's own minimum checks (test the minimum-enforcement logic by testing the validator against intentionally weak files + documenting that the scaffolder would refuse to produce them).

3. **ROADMAP says >=5 banned_phrases, but REQUIREMENTS.md SCAF-01 says "3+ banned phrases"**
   - What we know: ROADMAP SC-1 says ">=5 banned phrases". REQUIREMENTS.md SCAF-01 says "3+ banned phrases". CONTEXT.md doesn't explicitly resolve this conflict.
   - What's unclear: Which is authoritative for the scaffolder's refusal threshold.
   - Recommendation: Use the ROADMAP SC-1 value (>=5) since success criteria are the verification standard. The REQUIREMENTS.md "3+" appears to be a typo or earlier draft value that was superseded by the more detailed ROADMAP.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| python3 | Overlap calculation, validate-personas.sh fallback | Yes | 3.11.4 | -- |
| PyYAML | Overlap calculation, sidecar parsing | Yes | 6.0.3 | -- |
| yq | validate-personas.sh primary YAML parser | Yes | 4.45.4 | python3+PyYAML (automatic fallback in validator) |
| jq | Signal ID extraction from lib/signals.json | Yes | 1.7.1 | -- |
| Claude Code plugin system | Skill registration, ${CLAUDE_PLUGIN_DATA}, AskUserQuestion | Yes | Current | -- |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Shell scripts (bash + bats-compatible assertions) |
| Config file | None (convention: `scripts/test-*.sh`) |
| Quick run command | `./scripts/test-persona-scaffolder.sh` |
| Full suite command | `for f in scripts/test-*.sh; do bash "$f"; done` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCAF-01 | Scaffolder refuses to write without field minimums | smoke (output validation) | `./scripts/test-persona-scaffolder.sh` (weak-input reject case) | Wave 0 |
| SCAF-02 | Workspace layout makes validate-personas.sh work | unit (validator on workspace output) | `./scripts/test-persona-scaffolder.sh` (pass case validates output) | Wave 0 |
| SCAF-03 | Validator integration (exit 0 before success) | unit (validator invocation) | `./scripts/validate-personas.sh <workspace>/agents/<slug>.md` | Exists |
| SCAF-04 | Voice-rubric coaching (>30% overlap warning) | unit (overlap detection) | `./scripts/test-persona-scaffolder.sh` (overlap fixture) | Wave 0 |
| SCAF-05 | README + CHANGELOG docs | manual-only | Visual inspection of README.md scaffolder section | -- |

### Sampling Rate

- **Per task commit:** `./scripts/test-persona-scaffolder.sh`
- **Per wave merge:** Full test suite (`for f in scripts/test-*.sh; do bash "$f"; done`)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `scripts/test-persona-scaffolder.sh` -- covers SCAF-01, SCAF-02, SCAF-04 (does not exist yet; is a Phase 5 deliverable)
- [ ] `tests/fixtures/scaffolder/valid-input.yml` -- scripted input data for pass case
- [ ] `tests/fixtures/scaffolder/weak-input.yml` -- scripted input data for reject case

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | -- |
| V3 Session Management | no | -- |
| V4 Access Control | no | -- |
| V5 Input Validation | yes | Validator (validate-personas.sh) sanitizes all fields; SKILL.md instructs kebab-case name enforcement |
| V6 Cryptography | no | -- |

### Known Threat Patterns for Plugin Skills

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| YAML injection via user input | Tampering | validate-personas.sh R1 ensures parseable YAML; skill instructs proper quoting |
| Path traversal in slug | Tampering | Skill instructs kebab-case validation (a-z, 0-9, hyphens only); no `../` possible |
| Shell injection via persona name | Elevation | Slug is validated before being used in file paths; Bash tool invocations quote all variables |

## Sources

### Primary (HIGH confidence)
- Local codebase: `scripts/validate-personas.sh` — full validator implementation with sidecar fallback logic (lines 426-439)
- Local codebase: `skills/persona-voice/PERSONA-SCHEMA.md` — authoritative field schema
- Local codebase: `agents/AUTHORING.md` — manual authoring guide the scaffolder automates
- Local codebase: `persona-metadata/*.yml` (16 files) — overlap comparison set
- Local codebase: `lib/signals.json` — signal registry with all IDs
- Claude Code official: `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/plugin-dev/skills/command-development/references/interactive-commands.md` — AskUserQuestion patterns, tool parameters, best practices

### Secondary (MEDIUM confidence)
- Claude Code changelog (`~/.claude/cache/changelog.md`) — confirms AskUserQuestion works in skill allowed-tools (fix for auto-allow behavior)
- CLAUDE.md technology stack section — confirms `${CLAUDE_PLUGIN_DATA}` expansion and skill frontmatter schema

### Tertiary (LOW confidence)
- None. All claims verified against local codebase or official plugin documentation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all components already exist in the project or are verified first-party Claude Code features
- Architecture: HIGH - patterns verified against existing project skills + official interactive-commands reference
- Pitfalls: HIGH - identified from direct code reading of validate-personas.sh sidecar resolution logic + project's shell-inject guard history

**Research date:** 2026-04-28
**Valid until:** 2026-05-28 (stable — no fast-moving external dependencies; all components are local)
