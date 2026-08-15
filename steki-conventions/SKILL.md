---
name: steki-conventions
description: Personal development conventions and tools. Use when creating GitHub Actions workflows, CI/CD pipelines, or setting up new projects.
---

# Development Conventions

## GitHub Actions
- Always pin actions by SHA with version comment: `uses: actions/checkout@<sha> # v6.0.2`
- Use `actions-pin` tool to resolve latest SHAs
- Run: `actions-pin actions/checkout actions/setup-node` or `actions-pin -f .github/workflows/build.yml`
- Tool location: `actions-pin` (in PATH, ~/.local/bin/)

## Tools
- Custom tools live in `~/.local/bin/` (added to PATH)

## Environment
- Go: check `go version` before assuming
- Flutter: check `flutter --version` before assuming
- Node: check `node --version` before assuming
- Always check actual installed versions, never assume from training data
