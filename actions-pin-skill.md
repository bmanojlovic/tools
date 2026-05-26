---
name: actions-pin
description: GitHub Actions must be pinned by SHA. Use actions-pin tool to resolve latest versions. Apply when creating or updating GitHub Actions workflows.
---

# GitHub Actions Pinning

## Rule
Always pin actions by SHA with version comment:
```yaml
- uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
```

## Tool: actions-pin

Resolves GitHub Actions to their latest release SHA and optionally rewrites workflow files.

```bash
# Resolve specific actions (latest release)
actions-pin actions/checkout actions/setup-node actions/setup-go

# Resolve specific version (not latest)
actions-pin actions/download-artifact@v4

# Transform workflow file to stdout (original unchanged)
actions-pin .github/workflows/build.yml

# Replace in-place (uses tmpfile + mv, safe)
actions-pin -f .github/workflows/build.yml
```

Progress is printed to stderr, transformed content to stdout:
```
  pinned actions/checkout → de0fac2e4500... # v6.0.2
```

Resolve-only output format (ready to paste):
```
actions/checkout                              de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
```

## Install
```bash
ln -s /path/to/tools/actions-pin ~/.local/bin/
```

Requires: `gh` CLI authenticated.
