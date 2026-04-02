# Release Management Skill

Automates versioning and releases for the vLLM fork, following the 0.18.x versioning scheme.

## Overview

This skill provides automated release management for maintaining the vLLM fork. Every commit triggers a new patch release (0.18.x).

## Versioning Scheme

- **Major**: 0 (locked for compatibility)
- **Minor**: 18 (locked for compatibility)
- **Patch**: Auto-incremented with each release (0, 1, 2, ...)

## Usage

### Automatic Release (Recommended)

After making commits and pushing to main:

```bash
# The skill will automatically detect and create the next release
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

2. **Create and push tag:**
   ```bash
   git tag v0.18.3 -m "v0.18.3 - Bug fix release"
   git push origin v0.18.3
   ```

3. **Create GitHub release:**
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
4. Generates release notes from commit messages
5. Creates and pushes the tag
6. Creates GitHub release

## Safety Checks

- Must be on `main` branch
- No uncommitted changes
- Remote `origin` is accessible
- GitHub CLI (`gh`) is authenticated
