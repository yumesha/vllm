#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Copyright contributors to the vLLM project
"""
Automated release script for vLLM fork.
Creates a new 0.18.x patch release for every commit on Forgejo.
"""

import json
import os
import subprocess
import sys
import tempfile

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


def get_forgejo_config():
    """Get Forgejo configuration from environment."""
    token = os.environ.get("FORGEJO_TOKEN")
    host = os.environ.get("FORGEJO_HOST", "192.168.157.157:30443")

    if not token:
        print("❌ FORGEJO_TOKEN not set")
        print("   Set it with: export FORGEJO_TOKEN=your-token")
        return None, host

    return token, host


def get_repo_spec():
    """Get repository spec from git remote."""
    try:
        remote_url = run("git remote get-url origin")
        # Parse ssh://git@host:port/owner/repo.git or similar
        if "192.168.157.157" in remote_url:
            # Extract owner/repo from URL
            # ssh://git@192.168.157.157:30122/antdev/vllm.git
            # -> antdev/vllm
            match = re.search(r"/([^/]+/[^/]+?)(?:\.git)?$", remote_url)
            if match:
                return match.group(1)
    except subprocess.CalledProcessError:
        pass
    return None


def create_forgejo_release(token, host, repo_spec, tag, name, body):
    """Create a release on Forgejo."""
    url = f"https://{host}/api/v1/repos/{repo_spec}/releases"

    data = {"tag_name": tag, "name": name, "body": body, "prerelease": False}

    # Create temp file for JSON payload
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        json.dump(data, f)
        json_file = f.name

    try:
        # Use curl for the request
        cmd = [
            "curl",
            "-s",
            "-k",
            "-w",
            "\n%{http_code}",
            "-X",
            "POST",
            url,
            "-H",
            f"Authorization: token {token}",
            "-H",
            "Content-Type: application/json",
            "-d",
            f"@{json_file}",
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)
        output = result.stdout.strip()

        # Parse response
        lines = output.split("\n")
        http_code = lines[-1]
        response_body = "\n".join(lines[:-1])

        if http_code == "201":
            response_json = json.loads(response_body)
            return True, response_json.get("html_url", ""), None
        elif http_code == "409":
            return False, None, "Release already exists"
        else:
            return False, None, f"HTTP {http_code}: {response_body}"

    finally:
        os.unlink(json_file)


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
    print("🚀 Release Management Script (Forgejo)")
    print("=" * 40)

    # Check Forgejo configuration
    token, host = get_forgejo_config()
    if not token:
        sys.exit(1)

    repo_spec = get_repo_spec()
    if not repo_spec:
        print("❌ Could not determine repository from git remote")
        print("   Make sure origin points to Forgejo")
        sys.exit(1)

    print(f"📦 Repository: {repo_spec}")
    print(f"🌐 Forgejo: https://{host}")

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
                print("❌ Release cancelled - fix version manually")
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
    tag_message = f"{next_version} - Bug fix release\n\n"
    tag_message += "\n".join(commits[:5])

    run(f"git tag -a {next_version} -m '{tag_message}'")
    print(f"✅ Tag created: {next_version}")

    print("\n📤 Pushing tag to origin...")
    run(f"git push origin {next_version}")
    print("✅ Tag pushed")

    print("\n🌐 Creating Forgejo release...")
    success, release_url, error = create_forgejo_release(
        token, host, repo_spec, next_version, next_version, release_notes
    )

    if success:
        print("✅ Forgejo release created")
        if release_url:
            print(f"   URL: {release_url}")
    else:
        print(f"❌ Failed to create Forgejo release: {error}")
        print("   You may need to create it manually:")
        print(f"   curl -X POST https://{host}/api/v1/repos/{repo_spec}/releases")

    print(f"\n✨ Release {next_version} complete!")


if __name__ == "__main__":
    main()
