# Milestones: devils-council

## v1.1 Expansion + Hardening (Shipped: 2026-05-03)

**Phases completed:** 7 phases, 21 plans, 28 tasks

**Key accomplishments:**

- File flipped (local-only):
- Git-tracked (committed in `2971eab feat(codex-spike): TD/CODX-01 Codex --output-schema spike harness + memo`):
- 5 new signal detectors with artifact_type pipeline propagation, min_evidence gating, and 9-entry bench priority order -- all 17 v1.0 fixtures still green
- 17 negative fixtures with inverted-TDD ordering, 5 new positive assertions, Haiku whitelist expanded to 8 bench slugs, CI split into negatives-first/positives-second two-step pipeline
- Compliance Reviewer bench persona citing GDPR/HIPAA/SOC2/PCI control IDs, with 10-citation repertoire and 9-phrase banned-word discipline
- Performance Reviewer bench persona with workload-characterization-first voice, algorithmic lens differentiated from SRE's operational lens, triggered by performance_hotpath signal
- Atomic conductor wiring: bench whitelist 4-to-9, display-name map 8-to-14, always_invoke_on bypass for Junior Engineer on code-diff artifacts
- 1. [Rule 1 - Bug] Fixed REPO_ROOT path resolution in test-exec-sponsor-adversarial.sh
- 1. [Rule 1 - Bug] Shell-inject pattern in explanatory text
- 1. [Rule 2 - Missing critical functionality] Added codex_schema_invalid post-check (section 7b)
- 1. [Rule 1 - Bug] jq false-vs-null in schema_used assertion
- 1. [Rule 2 - Missing critical functionality] Created verify-uat-live-run.sh

---

## v1.0 MVP — SHIPPED 2026-04-24

**Tags:** `v1.0.0` (initial release) → `v1.0.1` (review.md shell-inject hotfix) → `v1.0.2` (incomplete-hotfix cleanup)
**Phases:** 1-8 (48 plans)
**Requirements:** 63/63 v1 functionally satisfied (post-amendment net 61)
**Audit:** `.planning/milestones/v1.0-MILESTONE-AUDIT.md` (status: `tech_debt`, no code blockers)

### Delivered

A Claude Code plugin shipping a persona-driven adversarial review layer: 10 personas (4 always-on core + 4 signal-triggered bench + Council Chair + Haiku classifier), 4 user-facing commands (`review`, `dig`, `on-plan`, `on-code`), deterministic 16-detector classifier, hard budget cap, Codex deep-scan delegation, 9-fixture injection corpus, response-suppression workflow, severity-tiered render, and opt-in GSD hook integration. CI runs `claude plugin validate` + persona validation + injection corpus + quality tests + coexistence matrix on every push.

### Key Accomplishments

1. Plugin scaffolding + Codex CLI integration verified end-to-end (Phase 1)
2. Structurally enforced non-generic critique via persona-voice + scorecard schemas + banned-phrase validator (Phase 2)
3. `/devils-council:review` end-to-end with XML-nonce injection defense + verbatim-quote evidence enforcement (Phase 3)
4. 4 always-on core personas with distinct voices + parallel-fan-out conductor (Phase 4)
5. Council Chair contradictions-first synthesis with deterministic finding IDs (Phase 5)
6. 4 bench personas + 16-detector classifier + Codex delegation + hard budget cap + prompt-cache observability (Phase 6)
7. 9-fixture injection corpus + schema-enforced drops + response annotations + severity-tiered render + GSD/Superpowers coexistence matrix (Phase 7)
8. `/devils-council:on-plan`, `/devils-council:on-code`, `/devils-council:dig` + opt-in GSD hooks + README + CHANGELOG + v1.0.0 marketplace install (Phase 8)

### Stats

- Phases: 8
- Plans: 48 (100% functionally delivered)
- Git range: initial commit → `1b6c31f` (v1.0.2)
- Timeline: 2026-04-22 → 2026-04-24 (3 calendar days)
- Decisions logged: ~81 across phase CONTEXT files

### Real-World Validation

08-UAT.md: reviewed Phase 3 03-00-PLAN.md (real plan artifact), produced 13 findings across 4 personas with voice-differentiated output. Anti-generic property confirmed.

### Hotfix Timeline

- v1.0.0 released, shell-inject P0 detected within minutes
- v1.0.1 hotfix shipped within 35 minutes (`Bash` tool replaced shell-inject in review.md)
- v1.0.2 cleanup shipped same day (incomplete hotfix residue)

### Known Gaps / Tech Debt

Tracking-only (flipped during milestone close): REQUIREMENTS.md 63/63 checkboxes + ROADMAP headline 65 → 63.

Carried forward to future milestones (see `v1.0-MILESTONE-AUDIT.md`):

- TD-02: Phase 1 + Phase 4 VERIFICATION.md formal flip (`human_needed` → `passed`, cite release chain + 08-UAT.md)
- TD-03: Phase 5 Nyquist validation retroactive run (CI is green; just never formally audited)
- TD-04 → v1.1: Slash-command shell-inject dry-run pre-parser smoke test
- TD-05 → v1.0.3: Chair Top-3 target-field strictness
- TD-06 → v1.1: Rename `agents/README.md` → `agents/AUTHORING.md`
- TD-07 → v1.0.3: README `/plugin marketplace update` refresh step documentation

---

*Full details: `.planning/milestones/v1.0-ROADMAP.md`*
*Requirements archive: `.planning/milestones/v1.0-REQUIREMENTS.md`*
