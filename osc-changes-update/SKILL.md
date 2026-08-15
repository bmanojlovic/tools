---
name: osc-changes-update
description: Generate a properly formatted OBS/RPM .changes entry for a package version upgrade by fetching and formatting upstream release notes. Use when upgrading an OBS package version or after updating the spec file's Version field.
---

# OBS .changes File Update

## Purpose
Generate a properly formatted `.changes` entry for an OBS/RPM package version upgrade by fetching upstream release notes and formatting them to match the existing changelog style.

## When to Use
- Upgrading a package version in OBS
- After updating the `.spec` file `Version:` field
- When `osc vc` would be used but you need structured release notes content

## Workflow

### Step 1: Read Existing .changes Format

Before writing anything, read the top 2-3 entries of the existing `.changes` file to understand:
- Date format (e.g., `Thu Jul 16 21:00:00 UTC 2026`)
- Maintainer line (e.g., `- Boris Manojlovic <boris@steki.net>`)
- Section headers (e.g., `- New Features and Improvements`, `- Bug Fixes`)
- Entry prefix (e.g., `  + ZBXNEXT-NNNNN Description Component`)
- Whether cumulative updates reference intermediate versions

### Step 2: Identify Versions to Include

Read the LAST entry in `.changes` to find what version was previously packaged.
Then fetch release notes for every version AFTER that up to and including the new target.

Example: Last `.changes` says "Update to version 7.0.26", target is 7.0.28
→ Fetch: 7.0.27 + 7.0.28 (everything between last packaged and target)

### Step 3: Fetch Upstream Release Notes

For each version, fetch from the upstream release notes URL:
```
https://www.zabbix.com/rn/rn7.0.27
https://www.zabbix.com/rn/rn7.0.28
```

Extract:
- **New Features and Improvements** — lines with `ZBXNEXT-NNNNN`
- **Bug Fixes** — lines with `ZBX-NNNNN`

Each entry has format: `TICKET_ID Description Component(s)`

### Step 4: Compose .changes Entry

The entry structure (matching openSUSE/OBS conventions):

**Key principle: Bundle all intermediate versions into single unified sections.**
Merge all "New Features" from all versions into ONE `- New Features and Improvements` section,
and all "Bug Fixes" from all versions into ONE `- Bug Fixes` section.
Do NOT separate per-version within the entry.

```
-------------------------------------------------------------------
<Day> <Mon> <DD> <HH:MM:SS> UTC <YYYY> - <Name> <email>

- Update to version X.Y.Z LTS
- Cumulative update from A.B.C to X.Y.Z including all intermediate releases

- New Features and Improvements
  + ZBXNEXT-NNNNN Description Component (from any version in range)
  + ZBXNEXT-NNNNN Description Component

- Bug Fixes
  + ZBX-NNNNN Description Component (from any version in range)
  + ZBX-NNNNN Description Component

```

### Format Rules

1. **Separator line**: exactly 67 dashes: `-------------------------------------------------------------------`
2. **Date format**: `LC_ALL=C date -u "+%a %b %d %H:%M:%S UTC %Y"`
3. **Header line**: `- Update to version X.Y.Z LTS`
4. **Cumulative note** (if skipping versions): `- Cumulative update from OLD to NEW including all intermediate releases`
5. **Section headers**: `- New Features and Improvements` / `- Bug Fixes` (NO version prefix)
6. **Entries**: `  + TICKET-ID Description Component` (two spaces + plus + space)
7. **Bundling**: ALL features from ALL intermediate versions go into one section; ALL bug fixes into another
8. **Ordering within sections**: newest version entries first (7.0.28 entries before 7.0.27 entries)
9. **No trailing blank lines** before the separator of the next entry
10. **If no "New Features"** exist across all versions, omit that section entirely

### Step 5: Prepend to .changes File

Insert the new entry BEFORE the first existing `-------------------------------------------------------------------` line in the file. The file starts immediately with the separator.

### Example: Multi-version Update

For update from 7.0.26 to 7.0.28 (skipping 7.0.27):

```
-------------------------------------------------------------------
Thu Jul 16 21:00:00 UTC 2026 - Boris Manojlovic <boris@steki.net>

- Update to version 7.0.28 LTS
- Cumulative update from 7.0.26 to 7.0.28 including all intermediate releases

- New Features and Improvements
  + ZBXNEXT-10478 Updated maximum supported MariaDB version to 12.3 API Proxy Server
  + ZBXNEXT-10592 Updated maximum supported MySQL version to 9.7 API Proxy Server

- Bug Fixes
  + ZBX-27883 Fixed inability to copy trigger prototypes Frontend
  + ZBX-27594 Fixed sorting of discovered hosts Frontend
  + ZBX-22504 Improved memory usage in LLD worker processes Server
  + ZBX-27780 Restored support of LLD macros in LLD rule override operations API

```

## Notes

- Use `osc vc -m "__PLACEHOLDER__"` to generate a properly timestamped header entry with correct maintainer email from osc config, then replace `- __PLACEHOLDER__` with the full changelog content
- This avoids hardcoding timestamps and email — osc handles that from its configuration
- For automated/scripted updates, the workflow is:
  1. `osc vc -m "__PLACEHOLDER__"`
  2. Replace the placeholder line with the full structured content
- Always verify format matches existing entries — different packages may have slightly different conventions
- The `Component` at the end (Frontend, Server, Proxy, Agent, API, Templates, etc.) comes directly from upstream release notes
