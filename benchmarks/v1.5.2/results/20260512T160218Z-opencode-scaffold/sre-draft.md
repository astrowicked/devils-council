---
persona: sre
artifact_sha256: b52dfecbffedebf1ce890ec886e5f03af51d6b80dd3f869f1d152daeacd1f5b2
findings:
  - target: "**Build Script Details:**"
    claim: "The build script uses inline python3 with regex-based YAML parsing instead of a proper YAML library. When a persona body contains `---` (e.g., a horizontal rule or code example), the regex will split incorrectly, produce a corrupt agent file, and the failure mode is silent — the file is valid markdown but has the wrong body. npm publish ships a broken persona, and you find out from a user bug report, not an alert."
    evidence: |
      Reads agents/{persona}.md, extracts frontmatter via regex
    ask: "What happens when persona body contains a `---` line? Regex-based frontmatter extraction splits on the first two `---` boundaries — if the body has one, you get a truncated file that passes all existing checks. Add a round-trip assertion: after transform, parse the output file and verify body length matches source body length ±0 bytes."
    severity: major
    category: correctness
  - target: "**Build Script Details:**"
    claim: "The build script depends on python3 being available in PATH, but there's no version pinning or availability check before the transform starts. If CI runs on a node-only image or a contributor's machine lacks python3, the build fails mid-way through — possibly after writing 2 of 5 agent files — leaving .opencode/ in a partial state that git diff will happily stage."
    evidence: |
      bash with inline python3 for YAML parsing
    ask: "Add a `command -v python3 || { echo 'python3 required'; exit 1; }` at line 1 of build.sh, before any file writes. Alternatively, list python3 in a prerequisites section of the README with a minimum version (3.8+ for walrus operator if used). Partial writes are the operational hazard — either gate the whole script or write to a temp dir and atomic-mv at the end."
    severity: major
    category: blast-radius
  - target: "Task 2: Create OpenCode agent files + build script"
    claim: "The build script writes 5 agent files in sequence but has no atomic-commit pattern — if it crashes after writing 3 of 5, the working tree has inconsistent agent state. A developer who runs `git add .` after a partial build publishes an incomplete plugin. The plan says 'exits non-zero if source persona missing or parse fails' but doesn't address partial-write cleanup."
    evidence: |
      Exits non-zero if source persona missing or parse fails
    ask: "Write generated files to a `.opencode/.build-tmp/` directory, then `mv` them into place only after all 5 succeed. If any fail, rm the tmp dir — don't leave partial artifacts in the publish path. This is the same pattern rsync uses for atomic deploys."
    severity: minor
    category: correctness
  - target: "Task 3: Validate npm publishability"
    claim: "The 'Coexistence check (Claude Code plugin unchanged)' is mentioned but has no defined assertion. What does 'unchanged' mean operationally — same sha256 of .claude-plugin/plugin.json? Same `claude plugin validate` exit code? Without a concrete gate, this check becomes a manual eyeball that will be skipped under deadline pressure, and the first symptom is a broken Claude Code install reported by a user on GitHub issues."
    evidence: |
      Coexistence check (Claude Code plugin unchanged)
    ask: "Define the assertion: `claude plugin validate` exits 0 AND `git diff --stat .claude-plugin/` is empty after the opencode build runs. Make it a script in `scripts/check-coexistence.sh` that CI calls. A named check you can grep in CI logs is the difference between 'we verified coexistence' and 'someone said they looked at it.'"
    severity: minor
    category: observability
---

## Summary

This plan's operational story is mostly sound for a dev-tooling scaffold — it's not a production service, so there's no pager rotation to name. The two major findings both live in the build script: regex-based YAML parsing has a silent corruption mode when persona bodies contain `---` delimiters, and the python3 dependency has no availability gate, which means partial writes to the publish directory. Both are fixable with a round-trip body-length assertion and an atomic temp-dir-then-mv pattern. The coexistence check needs a concrete assertion rather than a prose intention.
