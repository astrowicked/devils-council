---
phase: 05-scaffolder-skill
status: secured
threats_total: 5
threats_closed: 5
threats_open: 0
audited: 2026-04-28
---

# Phase 05 Security Audit: scaffolder-skill

## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| User input to persona file | Freeform text from AskUserQuestion enters YAML frontmatter |
| Workspace path to filesystem | Slug from user input becomes directory/file path |

## Threat Register

| Threat ID | Category | Component | Disposition | Status | Evidence |
|-----------|----------|-----------|-------------|--------|----------|
| T-05-01 | Tampering | SKILL.md user input | mitigate | CLOSED | `skills/create-persona/SKILL.md:32` — slug validated against `[a-z0-9]+(-[a-z0-9]+)*` regex; rejects uppercase, underscores, spaces, `../`. validate-personas.sh R1 ensures parseable YAML on output. |
| T-05-02 | Tampering | Workspace path construction | mitigate | CLOSED | `skills/create-persona/SKILL.md:326-327` — all writes constrained to `${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/` with `mkdir -p`. Slug validation (T-05-01) prevents path traversal. |
| T-05-03 | Information Disclosure | Persona content in workspace | accept | CLOSED | Accepted risk: workspace is local to user's machine under `CLAUDE_PLUGIN_DATA`. No network exfiltration path. Plugin data dir is user-scoped by Claude Code runtime. |
| T-05-04 | Elevation of Privilege | Shell injection via persona name | mitigate | CLOSED | `skills/create-persona/SKILL.md` — zero `!` backtick shell-inject patterns (grep confirms 0 matches). All shell operations via Bash tool with quoted variables. Slug kebab-case validation prevents metacharacter injection. |
| T-05-05 | Information Disclosure | README.md | accept | CLOSED | Accepted risk: README is a public repo file. Workspace path uses `${CLAUDE_PLUGIN_DATA}` variable, not concrete user paths. No secrets exposed. |

## Accepted Risks

| Threat ID | Risk | Justification |
|-----------|------|---------------|
| T-05-03 | Persona content visible in local workspace | User-scoped data dir; no network path; consistent with all Claude Code plugin data handling |
| T-05-05 | Public README documents workspace path pattern | Variable-based path only; no user-specific information disclosed |

## Security Audit 2026-04-28

| Metric | Count |
|--------|-------|
| Threats found | 5 |
| Closed | 5 |
| Open | 0 |

All mitigations verified against codebase. No open threats.
