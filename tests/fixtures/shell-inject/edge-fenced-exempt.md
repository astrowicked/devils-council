# Fenced Exempt Edge Case

This is DOCUMENTATION of the shell-inject pattern:

```
The syntax is !`<cmd>` and it runs at parse time.
```

```bash
# This is a bash fence showing syntax; not executed
example: !`echo hello`
```

The parser MUST NOT flag either of the above — both are non-`!` fences
(exemption zones per STACK.md §Q3).
