---
phase: 06-classifier-bench-personas-cost-instrumentation
plan: 04
subsystem: persona-files
tags: [bench-personas, voice-kits, codex-delegation, dual-deploy, air-gap, finops, security]
dependency_graph:
  requires:
    - skills/persona-voice/PERSONA-SCHEMA.md (tier:bench rules)
    - skills/codex-deep-scan/SKILL.md (delegation_request schema — D-02 read-only, D-13 failure envelope)
    - lib/signals.json (16 signal IDs bench triggers reference)
    - scripts/validate-personas.sh (R7 cross-check against signals.json)
    - agents/staff-engineer.md (structural template for agent body)
    - persona-metadata/staff-engineer.yml (sidecar template)
  provides:
    - agents/security-reviewer.md (BNCH-03; emits delegation_request)
    - agents/finops-auditor.md (BNCH-04; no delegation in v1)
    - agents/air-gap-reviewer.md (BNCH-05; no delegation in v1)
    - agents/dual-deploy-reviewer.md (BNCH-06; emits delegation_request)
    - persona-metadata/security-reviewer.yml (voice kit, 4 triggers, 9 banned phrases)
    - persona-metadata/finops-auditor.yml (voice kit, 4 triggers, 9 banned phrases)
    - persona-metadata/air-gap-reviewer.yml (voice kit, 5 triggers, 9 banned phrases)
    - persona-metadata/dual-deploy-reviewer.yml (voice kit, 6 triggers, 9 banned phrases)
  affects:
    - Plan 05 (conductor wiring reads delegation_request: from security-reviewer + dual-deploy-reviewer drafts)
    - Plan 06 (budget cap priority_order references these slugs)
    - Plan 07 (prompt-cache test fixture fans out across 4 bench personas)
tech_stack:
  added: []
  patterns:
    - "Schema-clean agent frontmatter (name / description / model only) + voice-kit sidecar in persona-metadata/*.yml — established pattern preserved"
    - "Bench persona body H2 section set: intro, How you review, [Delegating to Codex], Output contract, Complete worked example, What NOT to do, Banned-phrase discipline, Examples"
    - "Delegation contract lives in persona body + emits as draft-frontmatter top-level sibling of findings: (D-50, D-51)"
key_files:
  created:
    - agents/security-reviewer.md
    - agents/finops-auditor.md
    - agents/air-gap-reviewer.md
    - agents/dual-deploy-reviewer.md
    - persona-metadata/security-reviewer.yml
    - persona-metadata/finops-auditor.yml
    - persona-metadata/air-gap-reviewer.yml
    - persona-metadata/dual-deploy-reviewer.yml
  modified: []
decisions:
  - "Dual-Deploy banned_phrases substitution: `just works in both modes` → `ships in both modes unmodified`. Rationale: Task 2 acceptance criterion demands `grep -l 'just works' persona-metadata/*.yml` return exactly one file (air-gap). The RESEARCH.md §Q5 starter kit placed `just works in both modes` in dual-deploy, which substring-matches air-gap's `just works` ban and would have failed the voice-non-overlap check. `ships in both modes unmodified` preserves the vague-portability register the ban is meant to block without sharing substring with air-gap's ban. All three persona body references updated to match."
metrics:
  duration_minutes: 8
  tasks_completed: 2
  files_created: 8
  files_modified: 0
  completed_date: "2026-04-23"
---

# Phase 6 Plan 4: Bench Personas (Security / FinOps / Air-Gap / Dual-Deploy) Summary

Shipped four bench persona files + four voice-kit sidecars per BNCH-03..06, using the RESEARCH.md §Q5 starter drafts as the baseline. Security and Dual-Deploy persona bodies include explicit `delegation_request:` emission instructions — the contract Plan 05's conductor wiring consumes per D-50 / CDEX-03.

## Deliverables

### Persona slugs + final trigger lists

| Persona slug | Tier | Triggers | Emits delegation_request |
|--------------|------|----------|--------------------------|
| `security-reviewer` | bench | `auth_code_change`, `crypto_import`, `secret_handling`, `dependency_update` | Yes |
| `finops-auditor` | bench | `aws_sdk_import`, `new_cloud_resource`, `autoscaling_change`, `storage_class_change` | No (explicitly "Do NOT emit") |
| `air-gap-reviewer` | bench | `dependency_update`, `network_egress`, `external_image_pull`, `unpinned_dependency`, `license_phone_home` | No (explicitly "No `delegation_request:`") |
| `dual-deploy-reviewer` | bench | `helm_values_change`, `chart_yaml_present`, `kots_config_change`, `new_cloud_resource`, `external_image_pull`, `saas_only_assumption` | Yes |

Every trigger ID resolves against `lib/signals.json` (R7 cross-check).

### Voice non-overlap proof

`grep -l <phrase> persona-metadata/*.yml` returned exactly one sidecar for each persona-specific banned phrase:

| Persona-specific banned phrase | Sidecar hit |
|-------------------------------|-------------|
| `defense in depth` | `persona-metadata/security-reviewer.yml` (only) |
| `cloud-native` | `persona-metadata/finops-auditor.yml` (only) |
| `just works` | `persona-metadata/air-gap-reviewer.yml` (only) |
| `tenant-aware` | `persona-metadata/dual-deploy-reviewer.yml` (only) |

Each persona's banned list blocks the vague register of its own concern lens — security's marketing/architecture phrases (`defense in depth`, `harden`, `industry standard`, `encrypted at rest`), finops' adjective-level cost register (`cost-effective`, `elastic`, `optimize costs`), air-gap's assumed-connectivity register (`just works`, `works anywhere`, `minimal dependencies`, `typical deployment`), and dual-deploy's plausible-portability register (`tenant-aware`, `deployment-agnostic`, `configurable`, `one codepath`).

### Delegation contract emission

**Emitters (Security + Dual-Deploy):** Both persona bodies contain:

- A `## Delegating a deep scan to Codex (D-50, CDEX-03)` H2 section explaining when to delegate and what cross-file concern justifies it.
- Full YAML skeleton of the `delegation_request:` block with all six fields (`persona`, `target`, `question`, `context_files`, `sandbox`, `timeout_seconds`).
- Explicit statement that `sandbox: read-only` is the only v1-valid value, and any other value is rejected as `codex_sandbox_violation` by the conductor.
- Fail-loud contract per D-51: on Codex failure, conductor injects a `category: delegation_failed` finding with the `delegation_failed` envelope in `evidence`; persona proceeds with what it already concluded.
- A `## Complete worked example` that emits ONE valid delegation_request block alongside two findings — the shape Plan 05's conductor reads.

**Non-emitters (FinOps + Air-Gap):**

- FinOps `## Output contract` contains: `Do NOT emit `delegation_request:` — FinOps in v1 does not delegate to Codex (deferred to v1.1 per Phase 6 planning).`
- Air-Gap `## Output contract` contains: `No `delegation_request:` — air-gap does not delegate to Codex in v1.`

No bare column-0 `delegation_request:` block exists in either FinOps or Air-Gap (verified via `grep -q '^delegation_request:'`).

## Verification

- `bash scripts/validate-personas.sh agents/security-reviewer.md` → exit 0
- `bash scripts/validate-personas.sh agents/finops-auditor.md` → exit 0
- `bash scripts/validate-personas.sh agents/air-gap-reviewer.md` → exit 0
- `bash scripts/validate-personas.sh agents/dual-deploy-reviewer.md` → exit 0
- `bash scripts/validate-personas.sh` (full-dir) → exit 0 (pre-existing W1/W2 advisory warnings on core personas `devils-advocate`, `product-manager`, `sre`, `staff-engineer` are out of scope for this plan — they flag missing `consider|think about|be aware of` baseline bans in some core sidecars and missing `## Examples` H2 in some core bodies)
- R7 cross-check: every trigger ID in all four new sidecars resolves as a key in `lib/signals.json`
- R5 cross-check: every new sidecar has `characteristic_objections` length >= 3 (Security=4, FinOps=4, Air-Gap=4, Dual-Deploy=4)
- R6 cross-check: every new sidecar has non-empty `banned_phrases` (all four have 9 entries)
- W1 cross-check: every new sidecar includes `consider`, `think about`, `be aware of` baselines — no W1 warning fires for these four
- W2 cross-check: every new persona body contains a `## Examples` H2 — no W2 warning fires for these four

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Dual-Deploy banned_phrases substring collision with Air-Gap**

- **Found during:** Task 2 voice non-overlap acceptance check
- **Issue:** RESEARCH.md §Q5 starter draft and Plan 06-04-PLAN.md Task 2 action block both placed `just works in both modes` in `persona-metadata/dual-deploy-reviewer.yml`. This substring-matches Air-Gap's `just works` ban (in `persona-metadata/air-gap-reviewer.yml`), so `grep -l 'just works' persona-metadata/*.yml` returned two files — failing the Task 2 acceptance criterion that requires exactly one file (air-gap only). Plan's own acceptance criterion and Plan's own action block contradicted each other.
- **Fix:** Changed Dual-Deploy's banned phrase from `just works in both modes` to `ships in both modes unmodified`. The replacement preserves the vague-portability register the ban is meant to block (a plausible-sounding claim that evades naming any specific Helm value or KOTS field) without sharing substring with Air-Gap's ban. All three references in `agents/dual-deploy-reviewer.md` (one in the What-NOT-to-do example claim, one in the drop explanation, one in the Banned-phrase discipline prose) were updated to match.
- **Files modified:** `persona-metadata/dual-deploy-reviewer.yml`, `agents/dual-deploy-reviewer.md`
- **Commit:** 1c6b5e2

### Deviations from RESEARCH.md §Q5 starter drafts

The §Q5 drafts were used verbatim for persona-metadata YAML except for the single-line substitution noted above. All `primary_concern`, `blind_spots`, and `characteristic_objections` lists ship unchanged from §Q5. All agent-body prose is original work authored to match the `agents/staff-engineer.md` structural template (frontmatter + intro + How-you-review + [Delegating] + Output-contract + Complete-worked-example + What-NOT-to-do + Banned-phrase-discipline + Examples).

## Known Stubs

None. Every finding in every worked example cites verbatim evidence, names a specific line or file, and proposes a concrete remediation. The `What NOT to do` blocks intentionally show dropped-by-validator findings — those are counter-examples, not stubs.

## Threat Flags

None. All four persona files are markdown documents that the conductor reads at `/devils-council:review` invocation time; they introduce no new network endpoints, no new file access patterns, and no new schema surface beyond what `scripts/validate-personas.sh` already enforces. The security-relevant surface (delegation_request `sandbox: read-only` pinning) is covered by `skills/codex-deep-scan/SKILL.md` D-02 + D-51 + Plan 05's conductor rejection; this plan's persona bodies merely document the contract the conductor enforces downstream.

## Commits

- `61795e0` — feat(06-04): add Security + FinOps bench personas
- `1c6b5e2` — feat(06-04): add Air-Gap + Dual-Deploy bench personas

## Self-Check

Verified files exist:

- FOUND: agents/security-reviewer.md
- FOUND: agents/finops-auditor.md
- FOUND: agents/air-gap-reviewer.md
- FOUND: agents/dual-deploy-reviewer.md
- FOUND: persona-metadata/security-reviewer.yml
- FOUND: persona-metadata/finops-auditor.yml
- FOUND: persona-metadata/air-gap-reviewer.yml
- FOUND: persona-metadata/dual-deploy-reviewer.yml

Verified commits exist:

- FOUND: 61795e0 (feat(06-04): add Security + FinOps bench personas)
- FOUND: 1c6b5e2 (feat(06-04): add Air-Gap + Dual-Deploy bench personas)

## Self-Check: PASSED
