---
phase: 01-plugin-scaffolding-codex-setup
plan: 01
subsystem: plugin-manifest
tags: [scaffolding, manifest, marketplace, licensing]
one-liner: "Installable devils-council plugin skeleton with verified plugin.json + marketplace.json, six empty component dirs, MIT LICENSE, runtime/credential gitignore — claude plugin validate exits 0."
requires:
  - PROJECT.md (decisions: plugin-not-skill, v1 scope)
  - STACK.md (verified plugin.json + marketplace.json schemas)
  - 01-CONTEXT.md (D-05 namespace, D-07 .council/ runtime path, PLUG-05)
provides:
  - ".claude-plugin/plugin.json (name=devils-council, version=0.1.0)"
  - ".claude-plugin/marketplace.json (single-plugin catalog, source=./)"
  - "Six empty component dirs via .gitkeep (agents, commands, skills, scripts, bin, hooks)"
  - "/devils-council:* namespace reserved"
  - ".gitignore (excludes .council/ runtime + .codex/ credentials)"
  - "LICENSE (MIT, 2026 Andy Woodard)"
affects:
  - Plan 01-02 (drops skills/codex-deep-scan/SKILL.md + scripts/smoke-codex.sh into reserved dirs)
  - Plan 01-03 (symlink target name must match plugin name exactly)
  - Plan 01-04 (CI runs claude plugin validate — proven to pass locally)
  - Plan 01-05 (publishes to github.com/andywoodard/devils-council — repo URL fixed in manifest)
tech-stack:
  added: []
  patterns:
    - "Single-repo marketplace pattern (plugins[0].source = ./)"
    - ".gitkeep placeholder for empty directory tracking"
    - "SemVer starting at 0.1.0 (Phase 1 scaffolding; roadmap bumps to 1.0.0 at Phase 8 release)"
key-files:
  created:
    - ".claude-plugin/plugin.json"
    - ".claude-plugin/marketplace.json"
    - "agents/.gitkeep"
    - "commands/.gitkeep"
    - "skills/.gitkeep"
    - "scripts/.gitkeep"
    - "bin/.gitkeep"
    - "hooks/.gitkeep"
    - ".gitignore"
    - "LICENSE"
  modified: []
decisions:
  - "Plugin version starts at 0.1.0 (not 0.0.1 per D-discretion) — signals 'scaffolding in place, public API not frozen' per SemVer 0.y.z convention"
  - "No skills/commands/agents/hooks path overrides in plugin.json — defaults match our intended layout per STACK.md"
  - "No settings.json created (per D-PLUG-05) — prevents top-level agent key hijack that would break coexistence with GSD/Superpowers"
  - "claude plugin validate ran locally (v2.1.117) and passed — no CI-only fallback needed"
requirements-completed: [PLUG-01, PLUG-02, PLUG-04, PLUG-05]
metrics:
  tasks: 3
  commits: 3
  files-created: 10
  files-modified: 0
  duration: "~2 minutes"
  completed: 2026-04-22T18:52:01Z
---

# Phase 01 Plan 01: Plugin Scaffolding Summary

## One-Liner

Installable `devils-council` Claude Code plugin skeleton at repo root: verified `plugin.json` + `marketplace.json`, six empty component directories tracked via `.gitkeep`, MIT LICENSE, and `.gitignore` protecting runtime artifacts and Codex credentials. `claude plugin validate .` exits 0.

## What Was Built

### 1. Plugin Manifest (`.claude-plugin/plugin.json`)

Committed content (exact):

```json
{
  "name": "devils-council",
  "version": "0.1.0",
  "description": "Persona-driven adversarial review council for plans, code, and RFCs. Staff Engineer, SRE, PM, Devil's Advocate + auto-triggered bench personas critique in parallel; Council Chair synthesizes contradictions without collapsing dissent.",
  "author": {
    "name": "Andy Woodard",
    "url": "https://github.com/andywoodard"
  },
  "homepage": "https://github.com/andywoodard/devils-council",
  "repository": "https://github.com/andywoodard/devils-council",
  "license": "MIT",
  "keywords": ["review", "personas", "adversarial-review", "plan-review", "code-review", "gsd", "claude-code-plugin"]
}
```

### 2. Marketplace Catalog (`.claude-plugin/marketplace.json`)

Committed content (exact):

```json
{
  "name": "devils-council",
  "owner": {
    "name": "Andy Woodard"
  },
  "metadata": {
    "description": "Persona-driven adversarial review council",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "devils-council",
      "source": "./",
      "description": "Adversarial review: Staff Eng, SRE, PM, Devil's Advocate + bench (Security, FinOps, Air-Gap, Dual-Deploy)",
      "category": "code-review",
      "tags": ["review", "personas", "gsd", "adversarial-review"]
    }
  ]
}
```

### 3. Component Directory Skeleton

Six empty directories tracked via zero-byte `.gitkeep` placeholders:

| Directory    | Future Owner                                                    |
|--------------|-----------------------------------------------------------------|
| `agents/`    | Phase 2+ (persona subagent markdown files)                      |
| `commands/`  | Phase 3 (`review.md`); Phase 8 (`on-plan.md`, `on-code.md`, `dig.md`) |
| `skills/`    | Plan 01-02 (`codex-deep-scan/SKILL.md`); Phase 2+ (`persona-voice`, `scorecard-schema`) |
| `scripts/`   | Plan 01-02 (`smoke-codex.sh`)                                   |
| `bin/`       | Phase 6 (`codex-review` shell-out wrapper, auto-PATH when plugin enabled) |
| `hooks/`     | Phase 8 (opt-in `hooks.json` for GSD integration)               |

### 4. Licensing + Ignore Hygiene

- `LICENSE` — MIT with `Copyright (c) 2026 Andy Woodard` attribution.
- `.gitignore` — excludes `.council/` (runtime per D-07), `.codex/` + `*.codex-session` (credentials per STACK.md anti-pattern), `.DS_Store`, `node_modules/`, `.env*`, build outputs.

## Validation Outcome

`claude plugin validate .` was run locally against CLI **v2.1.117**:

```
Validating marketplace manifest: /Users/andywoodard/dev/devils-council/.claude/worktrees/agent-aac4cd61/.claude-plugin/marketplace.json

✔ Validation passed
```

Exit code: `0`. No CI-only fallback is required — the manifest is verified against the actual `claude` CLI. Plan 01-04 (CI) can rely on the same validator in GitHub Actions.

## Acceptance Criteria (All Pass)

| # | Criterion | Result |
|---|-----------|--------|
| 1 | Both JSON files parse cleanly (`jq empty`) | PASS |
| 2 | Plugin name is `devils-council` (namespace reserved) | PASS |
| 3 | Plugin version is `0.1.0` | PASS |
| 4 | Marketplace `plugins[0].name == "devils-council"` and `source == "./"` | PASS |
| 5 | No `settings.json` at repo root or in `.claude-plugin/` | PASS |
| 6 | Six component directories exist, each with zero-byte `.gitkeep` | PASS |
| 7 | `.gitignore` excludes `.council/` and `.codex/` | PASS |
| 8 | `LICENSE` is MIT with Andy Woodard 2026 attribution | PASS |
| 9 | `claude plugin validate .` exits 0 | PASS |
| 10 | No out-of-scope files (no personas, no review command, no `tests/`) | PASS |

## Deviations from Plan

None — plan executed exactly as written. All three tasks and ten files produced match the plan's `files_modified` list byte-for-byte.

## Authentication Gates

None encountered. Task 3's `claude plugin validate` ran against the already-authenticated local CLI without credential prompts.

## Threat Register Mitigations Verified

| Threat ID | Mitigation | Verification |
|-----------|------------|--------------|
| T-01-01 (Tampering: manifest JSON) | `jq empty` + `claude plugin validate` | Both passed on committed files |
| T-01-02 (Elevation: settings.json hijack) | No `settings.json` created | `test ! -f settings.json` exit 0 |
| T-01-03 (Info Disclosure: Codex credentials) | `.codex/` and `.env*` in `.gitignore` | `grep` matches confirmed |
| T-01-04 (Spoofing: reserved marketplace name) | Name is `devils-council`, not on Anthropic reserved list | Visual inspection + Plan 05 will retest at publish time |
| T-01-06 (DoS: manifest parse failure) | Both JSON files parse under `jq` | Verified in Task 1 and Task 3 |

## Handoff Notes

### To Plan 01-02 (Codex CLI Setup + Deep-Scan Skill)

- `skills/` is empty and ready to receive `codex-deep-scan/SKILL.md` with full request/response envelope (D-11).
- `scripts/` is empty and ready to receive `smoke-codex.sh` (D-04) running `codex exec --json --sandbox read-only`.
- Plan 01-02 is expected to create `tests/fixtures/` for the smoke-test fixture — Plan 01-01 intentionally did not create `tests/`.

### To Plan 01-03 (Local Dev Loop via `--plugin-dir` Symlink)

- Plugin name is exactly `devils-council`. The `~/.claude/plugins/` symlink target directory should match this name so `/reload-plugins` registers commands under `/devils-council:*` (D-05, D-08).

### To Plan 01-04 (Minimal CI)

- `claude plugin validate .` has been verified to pass on local CLI v2.1.117 against both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. CI should install `claude` on both `ubuntu-latest` and `macos-latest` (D-10) and run the same validator — no additional manifest preparation required.

### To Plan 01-05 (Publish to GitHub Marketplace)

- Manifest `homepage` and `repository` both point to `https://github.com/andywoodard/devils-council`. Repo push destination is fixed; changing the GitHub owner requires a new commit updating both fields.
- Marketplace name `devils-council` does not collide with the four Anthropic-reserved names (T-01-04 verified).

## Commits

| Task | Hash    | Message                                                            |
|------|---------|--------------------------------------------------------------------|
| 1    | 7ea2d5b | `feat(01-01): add plugin manifest and marketplace catalog`         |
| 2    | 99cc3a9 | `chore(01-01): add empty component directory skeleton`             |
| 3    | a78737d | `chore(01-01): add .gitignore and MIT LICENSE; validate manifest`  |

Final commit adding this SUMMARY.md follows.

## Self-Check: PASSED

- `.claude-plugin/plugin.json` — FOUND
- `.claude-plugin/marketplace.json` — FOUND
- `agents/.gitkeep` — FOUND
- `commands/.gitkeep` — FOUND
- `skills/.gitkeep` — FOUND
- `scripts/.gitkeep` — FOUND
- `bin/.gitkeep` — FOUND
- `hooks/.gitkeep` — FOUND
- `.gitignore` — FOUND
- `LICENSE` — FOUND
- Commit `7ea2d5b` — FOUND
- Commit `99cc3a9` — FOUND
- Commit `a78737d` — FOUND
- `claude plugin validate .` — exits 0 (FOUND)
