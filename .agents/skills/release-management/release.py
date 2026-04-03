#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright contributors to the vLLM project
"""
Automated release script for vLLM fork.
Creates a new 0.18.x patch release for every commit.
"""

import subprocess
import sys

import regex as re


def run(cmd, check=True, capture_output=True):
    """Run a shell command."""
    result = subprocess.run(
        cmd, shell=True, check=check, capture_output=capture_output, text=True
    )
    return result.stdout.strip() if capture_output else ""


def get_current_branch():
    """Get current git branch."""
    return run("git branch --show-current")


def has_uncommitted_changes():
    """Check for uncommitted changes."""
    result = run("git status --porcelain", check=False)
    return bool(result.strip())


def get_latest_version():
    """Get the latest v0.18.x tag."""
    try:
        return run("git describe --tags --match 'v0.18.*' --abbrev=0")
    except subprocess.CalledProcessError:
        return "v0.18.0"


def get_next_version(latest):
    """Calculate next patch version."""
    parts = latest.lstrip("v").split(".")
    major, minor, patch = parts[0], parts[1], int(parts[2])
    return f"v{major}.{minor}.{patch + 1}"


def get_commits_since_last_release(latest_tag):
    """Get commit messages since last release."""
    try:
        commits = run(f"git log {latest_tag}..HEAD --oneline --no-decorate")
        return commits.split("\n") if commits else []
    except subprocess.CalledProcessError:
        return []


def get_nix_package_version():
    """Get version from nix/package.nix."""
    try:
        with open("nix/package.nix") as f:
            content = f.read()
        match = re.search(r'version = "([^"]+)";', content)
        if match:
            return match.group(1)
    except FileNotFoundError:
        pass
    return None


def update_nix_package_version(new_version):
    """Update version in nix/package.nix."""
    try:
        with open("nix/package.nix") as f:
            content = f.read()

        # Replace version line
        new_content = re.sub(
            r'version = "[^"]+";', f'version = "{new_version}";', content
        )

        with open("nix/package.nix", "w") as f:
            f.write(new_content)

        return True
    except Exception as e:
        print(f"❌ Failed to update nix/package.nix: {e}")
        return False


def create_release_notes(version, commits):
    """Generate release notes from commits."""
    lines = [f"## {version}", "", "### Changes", ""]

    for commit in commits:
        if commit.strip():
            parts = commit.split(" ", 1)
            if len(parts) > 1:
                lines.append(f"- {parts[1]}")

    lines.extend(["", "### Contributors", "", "- @yumesha"])
    return "\n".join(lines)


def confirm(message):
    """Ask for user confirmation."""
    response = input(f"{message} [y/N]: ").lower().strip()
    return response in ("y", "yes")


def main():
    print("🚀 Release Management Script")
    print("=" * 40)

    print("\n📋 Running safety checks...")

    branch = get_current_branch()
    if branch != "main":
        print(f"❌ Not on main branch (currently on: {branch})")
        if not confirm("Continue anyway?"):
            sys.exit(1)
    else:
        print("✅ On main branch")

    if has_uncommitted_changes():
        print("❌ Uncommitted changes detected")
        print(run("git status --short", check=False))
        if not confirm("Continue anyway?"):
            sys.exit(1)
    else:
        print("✅ No uncommitted changes")

    print("\n📊 Version information:")
    latest = get_latest_version()
    next_version = get_next_version(latest)
    next_version_without_v = next_version.lstrip("v")
    print(f"   Latest: {latest}")
    print(f"   Next:   {next_version}")

    # Check nix/package.nix version
    nix_version = get_nix_package_version()
    if nix_version:
        print(f"   Nix package: {nix_version}")
        if nix_version != next_version_without_v:
            print("\n⚠️  Version mismatch detected!")
            print(f"   nix/package.nix has: {nix_version}")
            print(f"   Will be updated to:  {next_version_without_v}")
            if confirm("Auto-update nix/package.nix?"):
                if update_nix_package_version(next_version_without_v):
                    print("✅ Updated nix/package.nix")
                    # Commit the version update
                    run("git add nix/package.nix")
                    commit_msg = "chore: update version to "
                    commit_msg += f"{next_version_without_v}"
                    run(f'git commit -m "{commit_msg}"')
                    run("git push origin main")
                    print("✅ Committed and pushed version update")
                else:
                    print("❌ Failed to update nix/package.nix")
                    sys.exit(1)
            else:
                print(
                    "❌ Release cancelled - fix version manually or allow auto-update"
                )
                sys.exit(1)
        else:
            print("✅ Nix package version matches")

    commits = get_commits_since_last_release(latest)
    if not commits:
        print("\n⚠️  No commits since last release")
        if not confirm("Create release anyway?"):
            sys.exit(0)
    else:
        print(f"\n📝 Commits since {latest}:")
        for commit in commits[:10]:
            print(f"   {commit}")
        if len(commits) > 10:
            print(f"   ... and {len(commits) - 10} more")

    print(f"\n🎯 Ready to create release: {next_version}")
    if not confirm("Proceed with release?"):
        print("❌ Release cancelled")
        sys.exit(0)

    print(f"\n🏷️  Creating tag {next_version}...")
    release_notes = create_release_notes(next_version, commits)
    tag_message = f"{next_version} - Bug fix release\n\n" + "\n".join(commits[:5])

    run(f"git tag -a {next_version} -m '{tag_message}'")
    print(f"✅ Tag created: {next_version}")

    print("\n📤 Pushing tag to origin...")
    run(f"git push origin {next_version}")
    print("✅ Tag pushed")

    print("\n🌐 Creating GitHub release...")
    try:
        run(
            f"gh release create {next_version} "
            f'--title "{next_version}" '
            f'--notes "{release_notes}"'
        )
        print("✅ GitHub release created")
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to create GitHub release: {e}")
        print("   You may need to create it manually:")
        print(f"   gh release create {next_version}")

    print(f"\n✨ Release {next_version} complete!")
    print(f"   URL: https://github.com/yumesha/vllm/releases/tag/{next_version}")


if __name__ == "__main__":
    main()
