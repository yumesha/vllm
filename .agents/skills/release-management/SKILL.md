# Release Management Skill

Automates versioning and releases for the vLLM fork, following the 0.18.x versioning scheme.

## Overview

This skill provides automated release management for maintaining the vLLM fork. Every commit triggers a new patch release (0.18.x).

## Versioning Scheme

- **Major**: 0 (locked for compatibility)
- **Minor**: 18 (locked for compatibility)
- **Patch**: Auto-incremented with each release (0, 1, 2, ...)

## Features

### Automatic Version Check

The release script automatically checks `nix/package.nix` version and:

- Compares with the intended release version
- Warns if mismatch detected
- Offers to auto-update and commit the fix

This prevents version mismatches between git tags and the Nix package.

## Usage

### Automatic Release (Recommended)

After making commits and pushing to main:

```bash
# The skill will automatically detect and create the next release
# It will also check and fix nix/package.nix version
python .agents/skills/release-management/release.py
```

### Manual Release Steps

If you need to manually create a release:

1. **Determine next version:**
   ```bash
   git describe --tags --match "v0.18.*" --abbrev=0
   # Returns: v0.18.2
   # Next: v0.18.3
   ```

2. **Check/Update nix/package.nix version:**
   ```bash
   grep 'version = ' nix/package.nix
   # Should match: version = "0.18.3";
   ```

3. **Create and push tag:**
   ```bash
   git tag v0.18.3 -m "v0.18.3 - Bug fix release"
   git push origin v0.18.3
   ```

4. **Create GitHub release:**
   ```bash
   gh release create v0.18.3 --title "v0.18.3" --notes "Release notes"
   ```

## Release Notes Template

```markdown
## Bug Fix Release

This release includes bug fixes and improvements.

### Changes

- [List changes from git log]

### Contributors

- @yumesha
```

## Files

| File | Purpose |
| ---- | ------- |
| `SKILL.md` | This documentation |
| `release.py` | Automated release script |
| `.release-config.yaml` | Configuration for release behavior |

## Automation

The release script:

1. Checks for uncommitted changes
2. Gets the latest v0.18.x tag
3. Determines next patch version
4. **Checks nix/package.nix version** (auto-fix if mismatch)
5. Generates release notes from commit messages
6. Creates and pushes the tag
7. Creates GitHub release

## Safety Checks

- Must be on `main` branch
- No uncommitted changes
- Remote `origin` is accessible
- GitHub CLI (`gh`) is authenticated
- Nix package version matches release version (or auto-fixed)

## Common Issues

### Version Mismatch in nix/package.nix

If you see:

```text
⚠️  Version mismatch detected!
   nix/package.nix has: 0.18.3
   Will be updated to:  0.18.4
```

The script will offer to auto-update. Choose `y` to:

1. Update `version = "0.18.4";` in nix/package.nix
2. Commit the change
3. Push to main
4. Continue with release
