# Release Management Skill

Automates versioning and releases for the vLLM fork on **Forgejo**, following the 0.18.x versioning scheme.

## Overview

This skill provides automated release management for maintaining the vLLM fork on a self-hosted Forgejo instance. Every commit triggers a new patch release (0.18.x).

## Prerequisites

### Environment Variables

```bash
export FORGEJO_TOKEN="your-api-token-here"
export FORGEJO_HOST="192.168.157.157:30443"  # Optional, has default
```

To get a Forgejo token:

1. Go to Forgejo web UI → User Settings → Applications
2. Generate a new access token with `repo` scope

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
# Set your Forgejo token
export FORGEJO_TOKEN="your-token"

# Run the release script
python .agents/skills/release-management/release.py
```

The script will:

1. Check Forgejo configuration
2. Run safety checks (branch, uncommitted changes)
3. Calculate next version
4. Check/fix `nix/package.nix` version
5. Create and push git tag
6. Create Forgejo release via API

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

4. **Create Forgejo release via API:**
   ```bash
   curl -X POST \
     "https://${FORGEJO_HOST}/api/v1/repos/antdev/vllm/releases" \
     -H "Authorization: token ${FORGEJO_TOKEN}" \
     -H "Content-Type: application/json" \
     -d '{
       "tag_name": "v0.18.3",
       "name": "v0.18.3",
       "body": "Release notes here",
       "prerelease": false
     }' -k
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
| `release.py` | Automated release script for Forgejo |
| `.release-config.yaml` | Configuration for release behavior (legacy) |

## Automation

The release script:

1. Validates `FORGEJO_TOKEN` environment variable
2. Detects repository from `git remote get-url origin`
3. Checks for uncommitted changes
4. Gets the latest v0.18.x tag
5. Determines next patch version
6. **Checks nix/package.nix version** (auto-fix if mismatch)
7. Generates release notes from commit messages
8. Creates and pushes the tag
9. Creates Forgejo release via API

## Safety Checks

- `FORGEJO_TOKEN` must be set
- Must be on `main` branch
- No uncommitted changes
- Remote `origin` must be accessible
- Nix package version matches release version (or auto-fixed)

## Common Issues

### Missing FORGEJO_TOKEN

```text
❌ FORGEJO_TOKEN not set
   Set it with: export FORGEJO_TOKEN=your-token
```

**Fix:** Set the environment variable before running the script.

### Version Mismatch in nix/package.nix

```text
⚠️  Version mismatch detected!
   nix/package.nix has: 0.18.3
   Will be updated to:  0.18.4
Auto-update nix/package.nix? [y/N]:
```

The script will offer to auto-update. Choose `y` to:

1. Update `version = "0.18.4";` in nix/package.nix
2. Commit the change
3. Push to main
4. Continue with release

### Forgejo API Errors

If you see HTTP errors when creating the release:

- Check that `FORGEJO_TOKEN` is valid and has `repo` scope
- Verify `FORGEJO_HOST` is correct
- Ensure the repository exists on Forgejo
- Check network connectivity to the Forgejo instance
