---
name: codex-deep-scan
description: |
  Delegation envelope for routing deep code scans to the OpenAI Codex CLI.
  Defines the request shape personas emit, the normalized response the
  conductor reconciles back into the persona's scorecard, and the complete
  error taxonomy. Phase 6 Security and Dual-Deploy Reviewer personas consume
  this unchanged. Shell-primary via `codex exec --json --sandbox read-only`;
  MCP deferred to v1.1.
user-invocable: false
---

# codex-deep-scan

The load-bearing contract between personas and the Codex CLI. This skill is
**not** user-invocable; it is consumed by persona prompts and the conductor
orchestrator. Phase 6 wires personas to it; Phase 1 only defines the shape.

> **Decision anchors:** D-02 (read-only, no network default), D-11 (full
> schema defined in Phase 1), D-12 (shell-primary; MCP deferred), D-13
> (`delegation_failed` envelope — never silent-fail).

## When to Use

Personas use this skill when their critique needs **line-level grounding**
that the persona's own context window cannot provide efficiently. Examples:

- **Security reviewer** scanning 2,000 LoC of authentication code for bypass,
  IDOR, or broken session handling — needs line-cited findings.
- **Dual-Deploy reviewer** correlating Helm `values.yaml` keys against actual
  template usage across a chart — needs cross-file reference tracking.
- **Code reviewer** diffing a refactor for subtle behavioral regressions when
  the diff is too large to hold in context alongside architectural critique.

Do **not** use this skill for: generic "what does this code do" questions,
style/formatting critique, or anything a persona can answer from its own
read of the artifact. Delegation has latency and token cost; it is for
deep scans only.

## Request Schema

Every delegation request MUST conform to this shape. Personas emit this
object; the conductor fulfills it by shelling out to Codex.

```json
{
  "persona": "security-reviewer",
  "target": "src/auth/login.ts",
  "question": "Find auth bypass, IDOR, and broken session handling. Cite line numbers.",
  "context_files": [
    "src/auth/login.ts",
    "src/auth/session.ts"
  ],
  "sandbox": "read-only",
  "timeout_seconds": 60
}
```

**Field reference:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `persona` | string | yes | Persona name (matches `agents/<name>.md`). Used to route the response back into the right scorecard. |
| `target` | string | yes | Primary file or path the question is about. May include `:line` suffix when relevant. |
| `question` | string | yes | Natural-language question Codex will answer. Be specific; include what to look for AND what to cite. |
| `context_files` | string[] | yes | Additional files Codex may read. Keep small — every file costs tokens and time. Empty array is valid. |
| `sandbox` | enum | yes | One of `read-only` (default, D-02), `workspace-write`, `danger-full-access`. **v1 only permits `read-only`.** Widening is out of scope for v1 and requires a dedicated threat-model review. |
| `timeout_seconds` | integer | no | Wall-clock limit for Codex invocation. Default 60. On exceedance, conductor emits `codex_timeout` error per taxonomy below. |

**D-02 default:** `sandbox: read-only` is the documented default. Requests that
omit the field are interpreted as `read-only`. Requests that specify
`workspace-write` or `danger-full-access` MUST be rejected by the conductor
in v1 and routed to `codex_sandbox_violation`.

## Response Schema

The conductor normalizes every Codex invocation into this shape before
reconciling it back into the persona's scorecard. The `findings[]` array
MUST conform to the scorecard finding shape (Phase 2 will formalize this as
`skills/scorecard-schema/SKILL.md` — the two MUST match).

```json
{
  "delegation_id": "sha256:4a7c...",
  "persona": "security-reviewer",
  "status": "ok",
  "findings": [
    {
      "target": "src/auth/login.ts:42",
      "claim": "JWT signature verification is skipped when `skipVerify=true` is passed",
      "evidence": "  42:   if (opts.skipVerify) return jwt.decode(token);",
      "severity": "blocker",
      "category": "auth-bypass",
      "ask": "Remove the skipVerify shortcut or gate it behind a test-only flag"
    }
  ],
  "metadata": {
    "codex_version": "0.122.0",
    "model": "gpt-5-codex",
    "duration_ms": 1234,
    "tokens_in": 0,
    "tokens_out": 0,
    "sandbox": "read-only"
  }
}
```

**Field reference:**

| Field | Type | Description |
|-------|------|-------------|
| `delegation_id` | string | Deterministic hash of the request (sha256 of canonicalized JSON). Lets the conductor correlate async/parallel delegations. |
| `persona` | string | Echoed from request; the scorecard router key. |
| `status` | enum | `ok` on success, `failed` on any error (see taxonomy). |
| `findings[]` | Finding[] | Present when `status == ok`. Shape conforms to scorecard schema. |
| `findings[].target` | string | File and optional line (`path:line` or `path:line-line`). |
| `findings[].claim` | string | One-sentence statement of the issue. |
| `findings[].evidence` | string | Verbatim code excerpt Codex is pointing at. MUST be quoted from `target`. |
| `findings[].severity` | enum | `blocker` \| `high` \| `medium` \| `low` \| `nit`. |
| `findings[].category` | string | Free-form domain tag (`auth-bypass`, `idor`, `race-condition`, `iam-wildcard`, ...). |
| `findings[].ask` | string | Concrete remediation the persona proposes to the author. |
| `metadata.codex_version` | string | `codex --version` output captured at invocation. |
| `metadata.model` | string | Model Codex used (from JSONL preamble). |
| `metadata.duration_ms` | integer | Wall-clock time for the invocation. |
| `metadata.tokens_in` | integer | Input tokens consumed (if reported by Codex). |
| `metadata.tokens_out` | integer | Output tokens generated (if reported by Codex). |
| `metadata.sandbox` | string | Sandbox actually used (should always equal request `sandbox` in v1). |

When `status == failed`, `findings` is absent; see **Failure Handling Contract**.

## Error Taxonomy

Every delegation failure maps to exactly one of these classes and surfaces
as a `delegation_failed` entry inside the persona's scorecard per D-13. The
class string is the canonical identifier; the scorecard message is
user-facing and MUST be actionable.

| Class | Trigger | `delegation_failed.class` value | Scorecard message |
|-------|---------|--------------------------------|-------------------|
| CLI not installed | `command -v codex` fails | `codex_not_installed` | "Codex CLI not found on PATH. Install via `brew install --cask codex` (macOS) or `npm install -g @openai/codex`. Then run `codex login`." |
| Auth expired | `codex login status` exits non-zero | `codex_auth_expired` | "Codex authentication expired or missing. Run `codex login` to re-auth, or set `OPENAI_API_KEY` and run `echo \"$OPENAI_API_KEY\" \| codex login --with-api-key`." |
| Timeout | invocation exceeds `timeout_seconds` | `codex_timeout` | "Codex timed out after {N}s. Narrow `context_files`, simplify the `question`, or raise `timeout_seconds`." |
| Sandbox violation | request asks for non-`read-only` sandbox, or Codex attempts write/net | `codex_sandbox_violation` | "Codex was invoked with or requested a non-read-only sandbox. Widening the sandbox is out of scope for v1 and requires a dedicated threat-model review." |
| JSON parse error | `codex exec --json` output unparseable | `codex_json_parse_error` | "Codex returned malformed JSON. Raw output logged to `.council/<run>/codex-errors.log` for inspection." |
| Unknown | any other non-zero exit | `codex_unknown` | "Codex exited with code {N}. See `.council/<run>/codex-errors.log` for details." |
| Schema invalid | Schema rejected at Codex/OpenAI submit (HTTP 400) -- disallowed JSON Schema keywords | `codex_schema_invalid` | "Schema at {path} contains OpenAI strict-mode disallowed keywords. Falling back to schemaless delegation." |
| Schema validation error | Schema submittable but model output failed validation | `codex_schema_validation_error` | "Codex output failed schema validation: {error}. Findings still merged from raw output." |

These eight classes are the v1.1 minimum per D-11 + CODX-04. Adding a class
is a schema change and MUST be documented; removing or renaming one is a
breaking change.

## Failure Handling Contract

**D-13 verbatim:** when delegation fails, the persona's scorecard receives a
`delegation_failed` entry with `class` and `message` from the taxonomy above.
The persona **continues** with whatever it has already concluded; the
conductor **never aborts the whole review over one delegation error**.

This means:

1. Every persona scorecard MAY contain zero, one, or many `delegation_failed`
   entries — they coexist with `findings[]` the persona produced on its own.
2. The user sees explicitly what didn't run (no silent-fail, no hidden
   degradation).
3. The Council Chair treats a `delegation_failed` entry as a gap in
   coverage, not a verdict. Synthesis proceeds; the scorecard is honest
   about what was and was not scanned.

**Example scorecard fragment:**

```yaml
persona: security-reviewer
findings:
  - target: src/auth/login.ts:17
    claim: "password compared with `==` instead of constant-time compare"
    severity: high
delegation_failed:
  - class: codex_timeout
    message: "Codex timed out after 60s. Narrow context_files or raise timeout."
    attempted_at: "2026-04-22T14:23:01Z"
    request:
      target: "src/auth/session.ts"
      question: "Find session-fixation risks"
```

The persona reported what it saw directly; the deeper scan it tried to
delegate failed; both facts are visible.

## Invocation Pattern (shell-primary, v1)

Per D-12, v1 ships **shell-primary** delegation. The conductor invokes Codex
by running `scripts/smoke-codex.sh`'s flag pattern against a per-request
prompt:

```bash
cat "$PROMPT_FILE" | codex exec \
  --json \
  --sandbox read-only \
  --skip-git-repo-check \
  --ephemeral \
  -o "$OUT_FILE" \
  -
```

The smoke-test script `scripts/smoke-codex.sh` is the **canonical
invocation** — any divergence in Phase 6 (e.g., adding `--output-schema`)
MUST start by extending the smoke script so the pattern stays verified.

**MCP is deferred to v1.1** (`mcp__codex__spawn_agent` as seen in
`~/.claude/skills/reviewing-code-skill/SKILL.md`). The envelope above is
designed to be convertible without schema churn: MCP would fulfill the same
request shape and return the same response shape; only the transport
changes. If Phase 6 measurement shows shell is a bottleneck, MCP is the
documented upgrade path.

## Schema Enforcement (v1.1 WRAPPER Path)

Per Phase 2 spike verdict (WRAPPER), `bin/dc-codex-delegate.sh` invokes
`codex exec --output-schema <path>` when:

1. A schema file exists at `lib/codex-schemas/<persona-stem>.json` (e.g.,
   `security.json` for `security-reviewer`)
2. The installed Codex version supports `--output-schema` (feature-detected
   via `codex --help | grep '--output-schema'`)
3. The schema passes a strict-mode pre-check (no `oneOf`/`anyOf`/`allOf`,
   no `minLength`/`format`/`pattern`/`default`, all properties required)

When any condition fails, delegation silently falls back to the v1.0
schemaless path. Schema validation failures on model output are logged
as `codex_schema_validation_error` but findings are still merged from
raw output -- the persona never loses its deep scan results.

**Schema authoring rules** (OpenAI strict structured-outputs subset):
- Every property in `required` (no optional fields)
- No `oneOf`/`anyOf`/`allOf` inside `properties`
- No `minLength`/`minimum`/`pattern`/`format`/`default`
- Use `enum` for constrained string sets (enum IS supported)
- Nested objects: all children in `required`, `additionalProperties: false`

## Sandbox Default

The envelope pins `sandbox: read-only` as the default per D-02. This means:

- No writes to the filesystem (Codex reads only).
- No network access beyond Codex's own API call home to OpenAI.
- No shell execution side-effects on the host.

Widening the sandbox (`workspace-write` for autofix-suggestion workflows,
`danger-full-access` for anything) is **deferred to post-v1** and requires
a dedicated threat-model review that explicitly documents:

1. Which persona needs it and why.
2. What files/network resources become reachable.
3. How the conductor prevents cross-persona contamination.
4. How the user is informed that a widened sandbox is in use.

Until that review lands, non-`read-only` sandbox requests are rejected as
`codex_sandbox_violation`.

---

*Contract owner: devils-council Phase 1 (01-02)*
*Consumers: Phase 6 Security / Dual-Deploy / Code personas*
*Revision policy: Schema changes require a documented revision, not a
silent edit. Adding fields is backward-compatible; renaming or removing
fields is a breaking change.*
