# v1.1.0 Release Checklist

**Created:** 2026-04-29
**CI Preflight Status:** ALL PASSED (local run)

## Pre-release Verification (COMPLETED)

All CI-equivalent tests ran locally and passed:

| Test | Result |
|------|--------|
| validate-personas.sh | PASSED (warnings only, no errors) |
| JSON sanity (plugin.json + marketplace.json) | PASSED |
| test-budget-cap.sh (6 scenarios + bonus) | PASSED |
| test-chair-synthesis.sh (cases A-F) | PASSED |
| test-coexistence.sh (6 checks) | PASSED |
| test-engine-smoke.sh (cases A-F) | PASSED |
| validate-shell-inject.sh (commands/*.md) | PASSED |
| test-shell-inject.sh (6 fixtures) | PASSED |
| test-blinded-reader.sh (5 checks) | PASSED |
| test-chair-strictness.sh (6 fixtures) | PASSED |
| test-classify.sh --negatives-only (17 fixtures) | PASSED |
| test-classify.sh --positives-only | PASSED |
| test-codex-delegation.sh | PASSED |
| test-injection-corpus.sh (mock mode) | PASSED |
| test-dropped-scorecard.sh | PASSED |
| test-responses-suppression.sh | PASSED |
| test-severity-render.sh | PASSED |
| test-hooks-gsd-guard.sh (3 paths) | PASSED |
| test-on-plan-on-code.sh (14 assertions) | PASSED |
| test-dig-spawn.sh (27 assertions) | PASSED |
| test-persona-scaffolder.sh | PASSED |
| test-exec-sponsor-adversarial.sh | PASSED |
| test-validate-personas.sh (self-test) | PASSED |

## Release Commands (EXECUTE MANUALLY)

These commands are irreversible. Review the CHANGELOG and version bumps before executing.

### Step 1: Push to main

```bash
# Ensure you're on main with all worktree merges complete
git checkout main
git log --oneline -5  # Verify latest commits are the 07-02 version bump

# Push to trigger CI
git push origin main
```

### Step 2: Wait for CI green

```bash
# Monitor the CI run
gh run list --branch main --limit 3
gh run watch  # Watch the latest run

# Verify it passed
gh run view --exit-status
```

### Step 3: Create annotated tag

```bash
git tag -a v1.1.0 -m "v1.1.0: Expansion + Hardening

16 personas (4 core + 9 bench + Chair + classifier + Junior Engineer).
Custom persona scaffolder. Codex --output-schema (WRAPPER verdict).
9-entry bench priority order. All 7 v1.0 tech-debt items closed.
35/35 v1.1 requirements delivered across 7 phases."

git push origin v1.1.0
```

### Step 4: Create GitHub Release

```bash
gh release create v1.1.0 \
  --title "v1.1.0 — Expansion + Hardening" \
  --notes "$(cat <<'EOF'
## Highlights

- **6 new bench personas:** Compliance Reviewer, Performance Reviewer, Test Lead, Executive Sponsor, Competing Team Lead, Junior Engineer (always-invokable on code-diff)
- **Custom persona scaffolder:** `/devils-council:create-persona` interactive wizard with voice-rubric coaching
- **Codex `--output-schema` enforcement:** WRAPPER verdict — schema-enforced delegation with feature-detect + schemaless fallback
- **9-entry bench priority order:** budget-cap selects top-6 by priority when all 9 signals fire
- **5 new classifier signals:** compliance_marker, performance_hotpath, test_imbalance, exec_keyword, shared_infra_change
- **All v1.0 tech debt closed:** TD-01 through TD-07 (shell-inject guard, Chair strictness, AUTHORING.md rename, marketplace update docs)

## Install / Upgrade

```bash
/plugin marketplace update devils-council
/plugin uninstall devils-council@devils-council
/plugin install devils-council@devils-council
```

## Full Changelog

See [CHANGELOG.md](https://github.com/astrowicked/devils-council/blob/v1.1.0/CHANGELOG.md#110---2026-04-29) for the complete list of changes, requirements closed (35/35), and per-phase breakdown.

## Requirements Delivered

35/35 v1.1 requirements across 7 phases:
- Phase 1: TD-01..07 (tech debt foundation)
- Phase 2: CODX-01 (schema spike — WRAPPER verdict)
- Phase 3: CLS-01..06 (classifier extension)
- Phase 4: BNCH2-01..05, CORE-EXT-01, PQUAL-01..03 (personas + quality)
- Phase 5: SCAF-01..05 (scaffolder)
- Phase 6: CODX-02..04 (schema rollout)
- Phase 7: REL-01..04 (UAT + release)
EOF
)"
```

### Step 5: Verify release

```bash
# Check the release exists
gh release view v1.1.0

# Verify tag
git ls-remote --tags origin | grep v1.1.0
```

## Post-release

- [ ] Verify `/plugin marketplace update devils-council` picks up v1.1.0 on a fresh Claude Code session
- [ ] Run `/plugin install devils-council@devils-council` and confirm version shows 1.1.0
- [ ] Test `/devils-council:review` on a sample artifact with the installed v1.1.0
