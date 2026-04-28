---
phase: 04-six-personas-atomic-conductor-wiring
plan: 08
subsystem: validation-infrastructure
tags: [pqual, voice-distinctness, adversarial-fixture, blinded-reader, chair-synthesis, ci]
dependency_graph:
  requires: [04-07, 04-01, 04-02, 04-03, 04-04, 04-05, 04-06]
  provides: [PQUAL-01, PQUAL-02, PQUAL-03, SC-6]
  affects: [scripts/validate-personas.sh, scripts/test-chair-synthesis.sh, .github/workflows/ci.yml]
tech_stack:
  added: []
  patterns: [pairwise-overlap-detection, adversarial-fixture-testing, structural-readiness-validation]
key_files:
  created:
    - scripts/test-blinded-reader.sh
    - tests/fixtures/exec-sponsor-adversarial/temptation-plan.md
    - tests/fixtures/exec-sponsor-adversarial/test-exec-sponsor-adversarial.sh
    - tests/fixtures/blinded-reader/multi-signal-fixture.md
  modified:
    - scripts/validate-personas.sh
    - scripts/test-chair-synthesis.sh
    - .github/workflows/ci.yml
decisions:
  - "Voice-distinctness overlap check uses exact string match for banned phrases and substring match for objections; thresholds at 40% and 30% respectively per D-08/D-09"
  - "Blinded-reader Phase 4 implementation validates structural readiness (unique voices, sufficient attribution signals) rather than live LLM-as-judge attribution; live evaluation deferred to Phase 7"
  - "10-persona Chair synthesis produced 3 contradictions, well under the D-16 threshold of 5; Chair prompt update not needed"
metrics:
  duration: "11m55s"
  completed: "2026-04-28T19:32:00Z"
  tasks: 3
  files_created: 4
  files_modified: 3
---

# Phase 4 Plan 08: Voice Differentiation Validation Infrastructure Summary

Voice-distinctness pairwise overlap detection (40% banned-phrase / 30% objection thresholds, warn-mode), adversarial zero-quantification Executive Sponsor fixture with 73% banned-phrase coverage, blinded-reader structural readiness validation across 9 bench personas, and 10-persona Chair synthesis test (3 contradictions, under D-16 threshold of 5).

## Task Results

| Task | Name | Commit | Status |
|------|------|--------|--------|
| 1 | Extend validate-personas.sh with voice-distinctness overlap check | 96e1dbb | Done |
| 2 | Create adversarial Exec Sponsor fixture and blinded-reader fixture | 0c57ea2 | Done |
| 3 | Create blinded-reader evaluation script + extend Chair synthesis test + wire CI | e7d794c | Done |

## Implementation Details

### Task 1: Voice-Distinctness Overlap Check (PQUAL-01)

Extended `scripts/validate-personas.sh` with a `check_voice_distinctness()` function appended after all R1-R9 + W1-W3 individual persona checks. The function:

- Collects all critic sidecars (core + bench tiers) from `persona-metadata/*.yml`
- For each unique pair: extracts role-specific banned phrases (baseline excluded per D-08), computes set intersection, warns if overlap > 40%
- For each unique pair: extracts characteristic objections, performs substring matching (A is substring of B or vice versa), warns if overlap > 30%
- Emits warnings only (warn-mode per D-09) -- does not affect exit code
- Added `--skip-overlap` flag for test harnesses operating on partial roster

One expected overlap warning: junior-engineer and staff-engineer share 100% banned-phrase overlap (3/3 role-specific phrases). This is by design -- Junior Engineer is intentionally banned from Staff Engineer's simplification register per CORE-EXT-01.

### Task 2: Adversarial Fixtures (PQUAL-02, PQUAL-03)

Created three fixture files:

1. **`tests/fixtures/exec-sponsor-adversarial/temptation-plan.md`** -- Zero-quantification plan saturated with exec-speak: "north star", "unlock value", "de-risk", "move the needle", "stakeholder alignment", "competitive landscape", "opportunity window", "transformation journey", "strategic imperative", "key stakeholders", "leverage synergies", "drive impact", "alignment concerns". Contains zero dollar amounts, zero dates, zero customer counts. Covers 11/15 (73%) of role-specific banned phrases from the sidecar.

2. **`tests/fixtures/exec-sponsor-adversarial/test-exec-sponsor-adversarial.sh`** -- Two assertions per D-12: (a) fixture contains zero quantified business claims (grep for dollar/date/count patterns), (b) fixture contains >= 60% of role-specific banned phrases (proves adversarial coverage).

3. **`tests/fixtures/blinded-reader/multi-signal-fixture.md`** -- 124-line synthetic plan/RFC triggering all 9 bench signal domains: auth code (OAuth2 + PKCE), AWS SDK (CDK imports), Helm values (values.yaml + Chart.yaml), compliance markers (GDPR/HIPAA/SOC2/PCI citations), performance hot-path (loop + no stated rate), test imbalance (14 src files / 1 test file), exec keywords (strategic register), shared infra (3 downstream consumers named).

### Task 3: Blinded-Reader + Chair Extension + CI

1. **`scripts/test-blinded-reader.sh`** -- Validates structural prerequisites for Phase 7 LLM-as-judge evaluation: all 9 sidecars exist, multi-signal fixture exists, all primary_concerns are unique (key attribution signal), all personas have >= 3 characteristic objections, all have >= 3 role-specific banned phrases. All 5/5 checks pass.

2. **`scripts/test-chair-synthesis.sh` Case F** -- Added 10-persona fixture (4 core + 6 bench) using the existing HEREDOC pattern. Each bench persona draft cites evidence from contradiction-seed.md. Synthesis draft has 3 contradictions (PM vs SRE, Exec Sponsor vs Staff Eng, Test Lead vs Performance Reviewer). D-16 assertion: 3 <= 5 threshold passes. Chair prompt update not needed.

3. **`.github/workflows/ci.yml`** -- Added two new steps after persona validation: "Adversarial Exec Sponsor fixture" and "Blinded-reader readiness". Both use graceful skip guards for partial-phase CI runs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed REPO_ROOT path resolution in test-exec-sponsor-adversarial.sh**
- **Found during:** Task 2 verification
- **Issue:** Script used `$SCRIPT_DIR/../..` but the script lives 3 levels deep (`tests/fixtures/exec-sponsor-adversarial/`), resolving to `tests/` instead of repo root
- **Fix:** Changed to `$SCRIPT_DIR/../../..`
- **Files modified:** `tests/fixtures/exec-sponsor-adversarial/test-exec-sponsor-adversarial.sh`
- **Commit:** 0c57ea2

**2. [Rule 1 - Bug] Fixed 10-persona Chair test re-stamping core personas**
- **Found during:** Task 3 verification
- **Issue:** Case F tried to re-stamp all 10 personas but the 4 core personas were already stamped by `build_run_with_four_scorecards`, causing validator failures
- **Fix:** Changed stamp loop to only process the 6 new bench personas
- **Files modified:** `scripts/test-chair-synthesis.sh`
- **Commit:** e7d794c

## Verification Results

| Check | Result |
|-------|--------|
| `./scripts/validate-personas.sh` exits 0 | PASS (1 expected voice-distinctness warning) |
| `bash tests/fixtures/exec-sponsor-adversarial/test-exec-sponsor-adversarial.sh` exits 0 | PASS (73% coverage) |
| `bash scripts/test-blinded-reader.sh` exits 0 | PASS (5/5 checks) |
| `bash scripts/test-chair-synthesis.sh` exits 0 | PASS (cases A-F, 3 contradictions at 10-persona scale) |

## Decisions Made

1. **Overlap detection algorithm**: Exact string match for banned phrases (computationally simple, deterministic), substring match for objections (handles "X is a longer version of Y" patterns). Both are conservative -- false positives are acceptable in warn-mode.
2. **Blinded-reader Phase 4 scope**: Structural readiness validation only. Live LLM-as-judge attribution measurement deferred to Phase 7 per D-10/D-11 and the plan's explicit scoping ("Phase 4 validates the STRUCTURAL prerequisites").
3. **Chair prompt unchanged**: 10-persona synthesis produced 3 contradictions, well under the D-16 threshold of 5. Per D-16 ("test first, update Chair prompt only if needed"), no Chair prompt modification required.

## Self-Check: PASSED

All 7 created/modified files verified present. All 3 task commit hashes verified in git log.
