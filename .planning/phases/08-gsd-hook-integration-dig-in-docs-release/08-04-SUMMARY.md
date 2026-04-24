---
phase: 08-gsd-hook-integration-dig-in-docs-release
plan: 04
subsystem: docs
tags: [readme, docs-01, d-81, release-doc, v1.0.0]
dependency-graph:
  requires:
    - lib/signals.json (16-signal registry; linked as source of truth)
    - agents/*.md (10 persona files; linked from roster table)
    - .planning/phases/07-hardening-injection-defense-response-workflow/07-UAT.md (v1.1 tickets)
    - .planning/phases/08-gsd-hook-integration-dig-in-docs-release/08-CONTEXT.md (D-81 section plan)
  provides:
    - Release-grade v1.0.0 README documenting the full persona council
    - User-facing surface for install / uninstall / quickstart / troubleshooting
  affects:
    - Public-facing GitHub repo landing page
    - Marketplace install first-impression
tech-stack:
  added: []
  patterns:
    - Compact-and-link README pattern (D-81: ≤400 lines, links outward to source-of-truth files)
    - Collapsed <details> block for signal table (keeps 16-row reference accessible without dominating the page)
    - Anchor-linked troubleshooting (each of 8 items has its own H3 for deep-linking)
key-files:
  created:
    - .planning/phases/08-gsd-hook-integration-dig-in-docs-release/08-04-SUMMARY.md
  modified:
    - README.md (full rewrite: 223 → 339 lines)
decisions:
  - D-81 (README compact-and-link): implemented as 12 H2 sections totaling 339 lines; Codex Setup preserved content-equivalent to Phase-1 state
  - Trigger table rendered inside <details>/<summary> so default page scroll stays short; link to lib/signals.json gives canonical detail
  - Troubleshooting #3 references 07-UAT.md path (not GitHub URL) to work for offline + forked readers
metrics:
  duration_seconds: 134
  tasks_completed: 1
  files_modified: 1
  lines_added: 222
  lines_removed: 106
  net_line_delta: +116
completed: 2026-04-24
---

# Phase 08 Plan 04: Full v1.0.0 README Rewrite Summary

Replaced the Phase-1 scaffold README with a release-grade v1.0.0 documentation artifact per D-81's compact-and-link pattern, shipping all 10 personas, 4 commands, 16 trigger signals, budget/userConfig configuration, Codex setup, and 8 troubleshooting entries (including both v1.1 carryover tickets from 07-UAT.md) in 339 lines.

## What Shipped

- **README.md** — full rewrite from 223-line Phase-1 scaffold ("No personas yet — those land in Phase 2+") to 339-line v1.0.0 release doc.
- **12 H2 sections** — every DOCS-01 mandated section plus Contributing + License, each substantive (no TBD/placeholder text).
- **10-persona roster table** — Staff Engineer, SRE, PM, Devil's Advocate (core) + Security, FinOps, Air-Gap, Dual-Deploy (bench) + Council Chair + Artifact Classifier, each linked to `agents/<persona>.md`.
- **16-signal trigger table** — collapsed `<details>` block with description + target personas per signal; first row points readers to `lib/signals.json` as source of truth.
- **4-command reference** — `review`, `on-plan`, `on-code`, `dig` with syntax + example each; review flags documented (`--only`, `--exclude`, `--cap-usd`, `--type`, `--show-nits`).
- **8 troubleshooting entries** covering: plugin cache staleness (v1.1 ticket #1), Codex unavailable, RESP-03 LLM variance (v1.1 ticket #2), GSD hook integration, bench persona not spawning, Codex sandbox violation, budget cap too low, terminal render unreadable.

## Section Layout

| # | Section | Start line | Length |
|---|---------|-----------:|-------:|
| 0 | Header (title + pitch + status + repo/license/CC line) | 1 | 8 |
| 1 | Core Value | 9 | 4 |
| 2 | Requirements | 13 | 8 |
| 3 | Install | 21 | 23 |
| 4 | Uninstall | 44 | 9 |
| 5 | Quickstart | 53 | 21 |
| 6 | Persona Roster | 74 | 19 |
| 7 | Trigger Rules | 93 | 40 |
| 8 | Commands | 133 | 16 |
| 9 | Configuration | 149 | 27 |
| 10 | Codex Setup | 176 | 50 |
| 11 | Responses Workflow | 226 | 26 |
| 12 | Troubleshooting | 252 | 79 |
| 13 | Contributing | 331 | 6 |
| 14 | License | 337 | 3 |

Total: 339 lines (requirement: ≥200 AND ≤400). All 12 DOCS-01 sections present as H2 headers (plus Core Value, Contributing, License — three auxiliaries).

## Troubleshooting Items → Causes

| # | Item | Root cause | Fix surface |
|---|------|-----------|-------------|
| 1 | Plugin cache staleness after version bump | Claude Code plugin cache behavior (not a devils-council bug) | `/plugin uninstall` + `/plugin install` |
| 2 | Codex unavailable (delegation_failed) | Codex not installed / not authed | `codex login status`, `./scripts/smoke-codex.sh`, reinstall Codex |
| 3 | Dismissals not suppressing on re-run (RESP-03) | Finding ID hashes claim text; LLM phrasing variance shifts the hash | v1.0 workaround: dismiss multiple variants; v1.1 fix: normalize claim before hashing |
| 4 | GSD hook integration not firing | `userConfig.gsd_integration` off, GSD not installed, or hook not registered | three-point checklist (userConfig, GSD agent presence, hook JSON) |
| 5 | Bench persona not spawning despite match | Classifier miss, persona triggers list incomplete, or budget cap reached | inspect `MANIFEST.classifier` / persona triggers / `MANIFEST.personas_skipped` |
| 6 | Codex sandbox violation | Persona requested write or network op against read-only sandbox | expected fail-loud per D-51; widening deferred post-v1 |
| 7 | Budget cap too low | Default $0.50 cap trips before all bench run | `--cap-usd=1.00` or edit `config.json` `budget.cap_usd` |
| 8 | Terminal render unreadable | 4-8 scorecards + synthesis overflows terminal | `--show-nits` for explicit expansion or `cat .council/<run>/<persona>.md` |

v1.1 tickets #1 and #2 from `.planning/phases/07-hardening-injection-defense-response-workflow/07-UAT.md` are both surfaced (items #1 and #3).

## Links Verified

All outbound file references resolve to files on disk at commit time:

- `agents/staff-engineer.md` — exists
- `agents/sre.md` — exists
- `agents/product-manager.md` — exists
- `agents/devils-advocate.md` — exists
- `agents/security-reviewer.md` — exists
- `agents/finops-auditor.md` — exists
- `agents/air-gap-reviewer.md` — exists
- `agents/dual-deploy-reviewer.md` — exists
- `agents/council-chair.md` — exists
- `agents/artifact-classifier.md` — exists
- `lib/signals.json` — exists (16 signals)
- `LICENSE` — exists
- `scripts/smoke-codex.sh` — exists
- `.planning/phases/07-hardening-injection-defense-response-workflow/07-UAT.md` — exists

## Verification Results

All acceptance criteria from the plan's `<verify>` block pass:

| Criterion | Result |
|-----------|--------|
| `wc -l < README.md` ≤ 400 | 339 ✓ |
| `wc -l < README.md` ≥ 200 | 339 ✓ |
| `! grep -q 'Phase 1 scaffold' README.md` | ✓ |
| `! grep -q 'No personas yet' README.md` | ✓ |
| 12 required H2 sections present | 12/12 ✓ |
| `grep -c '/devils-council:' README.md` ≥ 8 | 16 ✓ |
| `grep -cE '\| \[.*\]\(agents/' README.md` ≥ 10 | 10 ✓ |
| `grep -q 'lib/signals.json'` | ✓ |
| `grep -q 'gsd_integration'` | ✓ |
| `grep -qE 'RESP-03\|LLM.*variance'` | ✓ |
| `grep -qE 'plugin.*cache.*stale\|uninstall.*reinstall'` | ✓ |
| `grep -q 'codex login'` | ✓ |
| `grep -q 'OPENAI_API_KEY'` | ✓ |
| `grep -q 'smoke-codex.sh'` | ✓ |
| `claude plugin validate .` exits 0 | ✓ (marketplace manifest passes) |

## Deviations from Plan

None — plan executed exactly as written. The `<action>` block in the plan provided a fully-drafted README body; this task adopted it verbatim with minor adjustments:

- Troubleshooting #3's v1.1 ticket reference changed from a GitHub URL (`https://github.com/astrowicked/devils-council/blob/main/...`) to a repo-relative path (`.planning/phases/07-hardening-injection-defense-response-workflow/07-UAT.md`). Rationale: forked readers and offline browsers resolve the repo-relative path; the GitHub URL would fail for forks. Informational change only; content-equivalent.

No auto-fix (Rule 1/2/3) issues discovered; no architectural changes (Rule 4) needed.

## Commits

- `171bf04` — docs(08-04): full v1.0.0 README rewrite per DOCS-01 / D-81

## Self-Check: PASSED

- README.md modified at commit `171bf04` — verified via `git show --stat 171bf04`
- `.planning/phases/08-gsd-hook-integration-dig-in-docs-release/08-04-SUMMARY.md` created — this file
- All 14 link targets exist on disk at commit time
- All 15 verify-block criteria pass
