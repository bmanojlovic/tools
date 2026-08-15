---
name: osc-package-upgrade
description: Upgrade an openSUSE Build Service (OBS) package to a new upstream version using osc and quilt patch management. Use when bumping a package's Version field, swapping its source tarball, or refreshing patches for a new release.
---

# OBS/osc Package Version Upgrade

## Purpose
Upgrade an openSUSE Build Service (OBS) package to a new upstream version using proper `osc` tooling and `quilt` patch management.

## Prerequisites
- `osc` client configured and authenticated
- `quilt` installed (patch management)
- Package already checked out locally via `osc co` or `osc bco`
- `obs-service-download_files` installed locally

## Workflow Overview

```
1. Assess package structure
2. Determine latest upstream version
3. Update spec version
4. Acquire new source tarball
5. Verify patches apply cleanly
6. Update .changes file
7. Register file changes with osc
8. Local build test
9. Commit and submit
```

---

## Step 1: Assess Package Structure

From the package working directory, identify:

```bash
# Check for _service file
ls _service 2>/dev/null

# Check spec file for Source URLs and patches
grep -E "^(Version|Source[0-9]*|Patch[0-9]*):" *.spec

# Check current version
grep "^Version:" *.spec
```

### Decision tree: Source acquisition method

| Condition | Method |
|-----------|--------|
| No `_service`, spec has `Source0:` with HTTP(S) URL containing `%{version}` | `osc service run download_files` |
| `_service` exists with `download_url` (mode=disabled) | Update URL path in `_service`, run `osc service disabledrun` |
| `_service` exists with `download_url` (mode=manual) | Update URL path in `_service`, run `osc service manualrun` |
| `_service` exists with `obs_scm`/`tar_scm` | Update `revision` param, run appropriate service command |
| No URL in Source0 (local-only tarball) | Download manually, `osc rm` old, `osc add` new |

### Key insight: `download_files` without `_service`

The `download_files` service parses ALL spec files in the package directory, finds `Source:` tags with HTTP/HTTPS/FTP URLs, and downloads them. No `_service` file is required for this to work. It expands RPM macros like `%{version}` from the spec before downloading.

---

## Step 2: Determine Latest Upstream Version

Methods vary by project:
- Check upstream release page / download page
- Check git tags
- Look at release notes
- For well-known projects: check their download/sources page

Example for Zabbix 7.0 LTS:
```
https://www.zabbix.com/download_sources → shows latest 7.0.x
https://cdn.zabbix.com/zabbix/sources/stable/7.0/ → directory listing
```

---

## Step 3: Update Spec Version

```bash
# Edit the Version: field
sed -i 's/^Version:.*$/Version:        NEW_VERSION/' PACKAGE.spec

# If Release is not auto-managed, reset to 0
sed -i 's/^Release:.*$/Release:        0/' PACKAGE.spec
```

Verify no other hardcoded version references exist that need updating:
```bash
grep -n "OLD_VERSION" *.spec _service 2>/dev/null
```

---

## Step 4: Acquire New Source Tarball

### Method A: `download_files` (preferred when Source0 has URL)

```bash
# Remove old tarball first
osc rm PACKAGE-OLD_VERSION.tar.gz

# Download new tarball — reads Source0 URL from spec, expands %{version}
osc service run download_files

# Verify download
ls -la PACKAGE-NEW_VERSION.tar.gz

# Register new file
osc add PACKAGE-NEW_VERSION.tar.gz
```

### Method B: `_service` file with `download_url`

Edit `_service` to update the path:
```xml
<services>
  <service name="download_url" mode="disabled">
    <param name="protocol">https</param>
    <param name="host">cdn.example.com</param>
    <param name="path">/sources/package-NEW_VERSION.tar.gz</param>
  </service>
</services>
```

Then run:
```bash
osc rm PACKAGE-OLD_VERSION.tar.gz
osc service disabledrun
# Downloaded file will be prefixed: _service:download_url:PACKAGE-NEW_VERSION.tar.gz
# Or without prefix depending on mode
osc add PACKAGE-NEW_VERSION.tar.gz
```

### Method C: `_service` with `obs_scm`/`tar_scm`

Update revision in `_service`:
```xml
<param name="revision">vNEW_VERSION</param>
```

Run:
```bash
osc service manualrun   # or disabledrun depending on mode
```

---

## Step 5: Verify Patches with Quilt

```bash
# Setup quilt from spec (extracts tarball + creates series file)
quilt setup *.spec
```

### Dealing with Unknown Macros

If `quilt setup` fails with `Unknown tag: %sysusers_requires` or similar errors from
distribution-specific macros not available locally, use `--spec-filter` with `quilt-spec-filter`
(installed at `~/.local/bin/quilt-spec-filter`, source alongside this skill in `~/GITHUB/tools/osc-package-upgrade/quilt-spec-filter`):

```bash
# quilt resolves bare filter names against /usr/share/quilt/spec-filters/
# so use $(which ...) to resolve from PATH
quilt setup --spec-filter $(which quilt-spec-filter) *.spec
```

The filter handles common openSUSE/SLE macros:
- `%sysusers_requires` → commented out
- `%pkg_vcmp` conditionals → resolved to `1` (include all patches)
- `%fillup_prereq` → replaced with standard Requires
- `%systemd_ordering` → commented out
- `%license` → replaced with `%doc`

Add new patterns to `~/GITHUB/tools/osc-package-upgrade/quilt-spec-filter` as encountered.

```bash
# Enter source directory (check what was created)
cd <package>-<version>-build/<package>-<version>/

# Apply all patches in order
quilt push -a
```

### If a patch applies cleanly:
```
Applying patch PATCHFILE
patching file src/something.c
```

### If a patch fails:
```
Applying patch PATCHFILE
patching file src/something.c
Hunk #1 FAILED at 42.
1 out of 1 hunk FAILED
```

Resolution options:
1. **Patch already applied upstream** → remove from spec (`Patch:` line AND `%patch` line), `osc rm PATCHFILE`
2. **Patch needs refresh (minor offset)** → `quilt push -f && quilt refresh`
3. **Patch conflicts badly** → rework manually with `quilt edit`, then `quilt refresh`

After resolving, return to package dir:
```bash
cd ..
```

If patches were refreshed, copy them back:
```bash
cp PACKAGE-NEW_VERSION/patches/PATCHFILE .
```

---

## Step 6: Update .changes File

```bash
osc vc
```

This opens `$EDITOR` on the `.changes` file with a pre-formatted header (timestamp + email). Add:

```
- Update to version NEW_VERSION:
  * Key change 1
  * Key change 2
  * See https://upstream.example/release-notes for full changelog
```

Conventions:
- Reference bug numbers: `bsc#NNNNNNN`, `boo#NNNNNNN`
- Reference CVEs if security fix: `CVE-YYYY-NNNNN`
- Keep it concise — point to upstream changelog for details

---

## Step 7: Register File Changes

```bash
# Auto-detect added/removed files
osc ar

# Or explicitly:
osc rm PACKAGE-OLD_VERSION.tar.gz
osc add PACKAGE-NEW_VERSION.tar.gz

# Verify status
osc st
```

Expected output:
```
D    PACKAGE-OLD_VERSION.tar.gz
A    PACKAGE-NEW_VERSION.tar.gz
M    PACKAGE.spec
M    PACKAGE.changes
```

---

## Step 8: Local Build Test

```bash
# List available build targets
osc repos

# Build for a specific target
osc build openSUSE_Tumbleweed x86_64

# Or let osc choose
osc build
```

Fix any build failures before committing.

---

## Step 9: Commit and Submit

```bash
# Commit to your branch
osc commit -m "Update to version NEW_VERSION"

# Check build status on server
osc r

# Once builds succeed, submit to upstream project
osc sr -m "Update PACKAGE to NEW_VERSION"
```

---

## Quick Reference: Complete Minimal Flow

For a simple version bump where Source0 has a URL and patches apply cleanly:

```bash
cd PACKAGE_DIR

# 1. Edit version
sed -i 's/^Version:.*OLD/Version:        NEW/' *.spec

# 2. Swap tarball
osc rm *-OLD.tar.gz
osc service run download_files
osc add *-NEW.tar.gz

# 3. Verify patches
quilt setup *.spec
cd PACKAGE-NEW/ && quilt push -a && cd ..

# 4. Update changelog
osc vc

# 5. Commit
osc ar
osc commit -m "Update to NEW"
osc sr
```

---

## Notes

- `osc service run download_files` works WITHOUT a `_service` file — it parses Source URLs from spec
- When a `_service` file exists, check its `mode` attribute to know which `osc service` subcommand to use:
  - `mode="disabled"` → `osc service disabledrun`
  - `mode="manual"` → `osc service manualrun`
  - no mode / `mode="trylocal"` / `mode="localonly"` → `osc service run`
- `osc ar` = "add/remove" — auto-detects new untracked files and missing tracked files
- `osc vc` = "version change" — creates a proper .changes entry with timestamp
- For branch workflow: `osc bco PRJ PKG` creates branch + checkout in one step
- Always `osc build` locally before committing to catch build failures early
