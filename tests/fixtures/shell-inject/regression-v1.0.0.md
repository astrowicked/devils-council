# v1.0.0 Shell-Inject P0 Regression Fixture

This fixture reproduces the exact prose-context inline !`<cmd>` pattern that
shipped as devils-council v1.0.0 and was hotfixed in v1.0.1 / v1.0.2
(git commits da45340 + d420c76). The parser MUST exit 1 on this file.

SUPPRESSED_IDS line from stdout for the render stage below:

    ${CLAUDE_PLUGIN_ROOT}/bin/dc-apply-responses.sh <RUN_DIR>

Do NOT use `` !`<cmd>` `` shell-inject here — `<RUN_DIR>` is resolved
at runtime, not at parse time, so shell-inject would fail with a zsh
parse error on the literal `<` character.

The helper writes `MANIFEST.suppressed_findings[]` additively.
