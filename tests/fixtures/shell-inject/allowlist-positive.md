# Allowlist Positive Edge Case

This file contains an intentional injection protected by the inline
allowlist marker. The parser MUST respect the marker and pass.

<!-- dc-shell-inject-ok: intentional invocation for fixture-runner self-test -->
!`date +%s`

After the marker-protected injection, another prose line.
