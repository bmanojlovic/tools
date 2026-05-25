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

Resolves actions to their latest release SHA.

```bash
# Resolve specific actions
actions-pin actions/checkout actions/setup-node actions/setup-go

# Extract and resolve all from a workflow file
actions-pin -f .github/workflows/build.yml
```

Output format (ready to paste):
```
actions/checkout                              de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
```

## Install
```bash
ln -s /path/to/tools/actions-pin ~/.local/bin/
```

Requires: `gh` CLI authenticated.
