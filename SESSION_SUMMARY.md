# Session Summary - vLLM NixOS Development Environment

**Date**: 2026-04-02 to 2026-04-03  
**Repository**: yumesha/vllm (GitHub + Forgejo mirror)  
**Forgejo Instance**: <https://192.168.157.157:30443/antdev/vllm>  
**Latest Release**: v0.18.8

---

## Overview

This session focused on:

1. Implementing NixOS development environment with CUDA 12.9 support
2. Adding RTX 5090 (Blackwell) compatibility
3. Setting up automated release management on Forgejo
4. Migrating from GitHub to self-hosted Forgejo
5. **Fixing Python 3.12/3.13 compatibility in Nix package**
6. **Adding build optimizations from build script to Nix package**

---

## Key Changes

### 1. Nix Flake (`flake.nix`)

- **Added**: Complete NixOS development environment with FHS
- **CUDA**: Upgraded from 12.8 to 12.9
- **GPU**: RTX 5090 (sm_100/sm_120) support with `TORCH_CUDA_ARCH_LIST="10.0;12.0"`
- **Features**: Automatic virtual environment, CUDA paths, uv package manager
- **Fixed**: Explicit Python 3.12 usage to avoid Python 3.13 default

### 2. Build Script (`scripts/build_vllm.sh`)

- **Added**: Automated build script with pre-flight checks
- **Smart**: RAM-based MAX_JOBS calculation
- **Fix**: Forward compatibility for host NVIDIA drivers (`/run/opengl-driver/lib`)

### 3. Nix Package (`nix/package.nix`)

- **Added**: Proper Nix package output (not just dev shell)
- **Fix**: Avoid `python3Packages` alias (nixpkgs requirement)
- **Fix**: Explicit `python3 = pkgs.python312` to prevent Python 3.13
- **Added**: Build optimizations from build script:
    - `NVCC_THREADS = "1"` (stable CUDA compilation)
    - `VLLM_USE_TRITON_FLASH_ATTN = "0"` (simpler build)
- **Fixed**: Version tracking to match git tags

### 4. Bug Fixes

- **TMA Detection**: Fixed for Blackwell GPUs (`9 <= cap < 12`)
- **PYTHONPATH**: Propagated to subprocess for model registry
- **CUDA**: Forward compatibility with host drivers
- **Python 3.13**: Prevented by explicit Python 3.12 in Nix package

### 5. Documentation

- **Added**: `docs/getting_started/nixos-development.md`
- **Added**: `.rules` for development guidelines
- **Updated**: `docs/getting_started/installation/README.md`

### 6. Release Management

- **Skill**: `.agents/skills/release-management/` for automated releases
- **Forgejo Integration**: Migrated from GitHub CLI to Forgejo API
- **Environment Variables**: `FORGEJO_TOKEN` and `FORGEJO_HOST` support
- **Version Check**: Auto-detect and fix `nix/package.nix` version mismatches
- **Latest Tag**: `v0.18.8` created on Forgejo

---

## Environment Variables

For NixOS module usage:

```bash
export FORGEJO_TOKEN="your-token-here"
export FORGEJO_HOST="192.168.157.157:30443"
```

To get a Forgejo token:

1. Go to <https://192.168.157.157:30443/user/settings/applications>
2. Generate a new access token with `repo` scope

---

## Usage

### Development (Flake)

```bash
cd ~/github/vllm
nix develop
./scripts/build_vllm.sh
```

### NixOS Installation

```nix
# In flake.nix
vllm = {
  url = "git+ssh://git@192.168.157.157:30122/antdev/vllm?ref=v0.18.8";
  inputs.nixpkgs.follows = "nixpkgs-unstable";
};
```

Then rebuild:

```bash
nix flake update vllm
sudo nixos-rebuild switch
```

### Create Release (Forgejo)

```bash
# Using the release script
cd ~/github/vllm
export FORGEJO_TOKEN="your-token"
python .agents/skills/release-management/release.py
```

The script will:

1. Check for uncommitted changes
2. Calculate next version
3. Check/fix `nix/package.nix` version
4. Create and push git tag
5. Create Forgejo release via API

---

## Release History

### v0.18.8 (Latest)

**URL**: <https://192.168.157.157:30443/antdev/vllm/releases/tag/v0.18.8>

- Complete Forgejo release management migration
- Add `FORGEJO_TOKEN` and `FORGEJO_HOST` support
- Auto-detect repository from git remote
- Fix nix/package.nix version tracking

### v0.18.4 - v0.18.7

- Python 3.12 explicit usage fix
- Build optimizations (NVCC_THREADS, VLLM_USE_TRITON_FLASH_ATTN)
- Release script with auto-version checking

### v0.18.3

**URL**: <https://192.168.157.157:30443/antdev/vllm/releases/tag/v0.18.3>

- Add proper Nix package output to flake
- Fix nix/package.nix dependencies
- Fix CUDA version references (12.8 → 12.9)
- Add automated release management skill
- Fix CUDA forward compatibility
- Fix build script directory navigation
- Fix TMA support detection
- Fix PYTHONPATH propagation

---

## Files Added/Modified

| File | Type | Description |
|------|------|-------------|
| `flake.nix` | Modified | CUDA 12.9, RTX 5090, Python 3.12 explicit, package output |
| `flake.lock` | Added | Reproducible dependencies |
| `scripts/build_vllm.sh` | Added | Build script with GPU optimization |
| `nix/package.nix` | Added | Nix package with Python 3.12, build optimizations |
| `.rules` | Added | Development guidelines |
| `docs/getting_started/nixos-development.md` | Added | NixOS documentation |
| `docs/getting_started/installation/README.md` | Modified | Added NixOS link |
| `.gitignore` | Modified | Added Nix artifacts |
| `vllm/model_executor/layers/fla/ops/utils.py` | Modified | TMA fix for Blackwell |
| `vllm/model_executor/models/registry.py` | Modified | PYTHONPATH fix |
| `.agents/skills/release-management/` | Added | Forgejo release automation skill |

---

## Known Issues & Solutions

| Issue | Solution |
|-------|----------|
| Python 3.13 used instead of 3.12 | Fixed: Explicit `python3 = pkgs.python312` in flake.nix |
| GitHub API rate limits | Migrated to Forgejo |
| Forgejo API 401 errors | Use API token authentication with `FORGEJO_TOKEN` |
| Shell escaping in JSON | Use file-based JSON payload in curl |
| python3Packages alias error | List packages individually |
| Version mismatch in nix/package.nix | Release script auto-detects and fixes |

---

## Next Steps

1. ✅ Test NixOS rebuild with `sudo nixos-rebuild switch`
2. ✅ Verify vLLM imports and CUDA detection
3. ✅ Set up automated releases on Forgejo
4. Consider upstreaming NixOS module to nixpkgs
5. Set up CI/CD for automated testing

---

## References

- **GitHub**: <https://github.com/yumesha/vllm> (mirror)
- **Forgejo**: <https://192.168.157.157:30443/antdev/vllm> (primary)
- **Latest Release**: <https://192.168.157.157:30443/antdev/vllm/releases/tag/v0.18.8>
- **Original PR**: <https://github.com/vllm-project/vllm/pull/33819>
