# Shebang Edge Case

Example bash script inside a non-`!` fence:

```bash
#!/usr/bin/env bash
echo "hello"
ls -la
```

The `#!` shebang is not an injection pattern; parser must not match on it.
