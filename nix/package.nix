# nix/package.nix
# Nix package for vLLM - builds from local source

{ lib
, stdenv
, python3
, fetchFromGitHub
, fetchpatch
, cudaPackages
, autoAddDriverRunpath
, symlinkJoin
, git
, cmake
, ninja
, gcc13
  # Python packages - from python3.pkgs
, buildPythonPackage
, pip
, wheel
, setuptools
, setuptools-scm
, packaging
, torch
, numpy
, transformers
, fastapi
, uvicorn
, pydantic
, sentencepiece
, tokenizers
, huggingface-hub
, requests
, psutil
, pyzmq
  # Additional runtime dependencies
, cbor2
, blake3
, cachetools
, einops
, gguf
, protobuf
, py-cpuinfo
, prometheus-client
, prometheus-fastapi-instrumentator
, python-json-logger
, tiktoken
, compressed-tensors
, depyf
, partial-json-parser
, xgrammar
, msgspec
, outlines
, lm-format-enforcer
, llguidance
, opentelemetry-api
, opentelemetry-sdk
, opentelemetry-exporter-otlp
}:

let
  # Merge CUDA libraries for cmake
  mergedCudaLibraries = with cudaPackages; [
    cuda_cudart
    cuda_cccl
    libcurand
    libcusparse
    libcusolver
    cuda_nvtx
    cuda_nvrtc
    libcublas
  ];

  # CUTLASS source - must match CUTLASS_REVISION in CMakeLists.txt
  cutlass = fetchFromGitHub {
    name = "cutlass-source";
    owner = "NVIDIA";
    repo = "cutlass";
    tag = "v4.4.2";  # Match CUTLASS_REVISION in CMakeLists.txt
    hash = "sha256-0q9Ad0Z6E/rO2PdM4uQc8H0E0qs9uKc3reHepiHhjEc=";
  };

  # FlashMLA requires CUTLASS v3.9.0 (incompatible with v4.x)
  # See: https://github.com/vllm-project/vllm/issues/27425
  cutlass-flashmla = fetchFromGitHub {
    name = "cutlass-flashmla-source";
    owner = "NVIDIA";
    repo = "cutlass";
    rev = "147f5673d0c1c3dcf66f78d677fd647e4a020219";
    hash = "sha256-dHQto08IwTDOIuFUp9jwm1MWkFi8v2YJ/UESrLuG71g=";
  };

  # FlashMLA source
  flashmla = stdenv.mkDerivation {
    pname = "flashmla";
    version = "1.0.0";

    src = fetchFromGitHub {
      name = "FlashMLA-source";
      owner = "vllm-project";
      repo = "FlashMLA";
      rev = "c2afa9cb93e674d5a9120a170a6da57b89267208";
      hash = "sha256-pKlwxV6G9iHag/jbu3bAyvYvnu5TbrQwUMFV0AlGC3s=";
    };

    dontConfigure = true;

    buildPhase = ''
      rm -rf csrc/cutlass
      ln -sf ${cutlass-flashmla} csrc/cutlass
    '';

    installPhase = ''
      cp -rva . $out
    '';
  };

  # Triton kernels source
  triton-kernels = fetchFromGitHub {
    name = "triton-kernels-source";
    owner = "triton-lang";
    repo = "triton";
    tag = "v3.6.0";
    hash = "sha256-JFSpQn+WsNnh7CAPlcpOcUp0nyKXNbJEANdXqmkt4Tc=";
  };

  # qutlass source - check cmake/external_projects/qutlass.cmake for GIT_TAG
  qutlass = fetchFromGitHub {
    name = "qutlass-source";
    owner = "IST-DASLab";
    repo = "qutlass";
    rev = "830d2c4537c7396e14a02a46fbddd18b5d107c65";
    hash = "sha256-aG4qd0vlwP+8gudfvHwhtXCFmBOJKQQTvcwahpEqC84=";
  };

  # vllm-flash-attn source - check cmake/external_projects/vllm_flash_attn.cmake for GIT_TAG
  vllm-flash-attn = stdenv.mkDerivation {
    pname = "vllm-flash-attn";
    version = "2.7.2.post1";

    src = fetchFromGitHub {
      name = "flash-attention-source";
      owner = "vllm-project";
      repo = "flash-attention";
      rev = "188be16520ceefdc625fdf71365585d2ee348fe2";
      hash = "sha256-Osec+/IF3+UDtbIhDMBXzUeWJ7hDJNb5FpaVaziPSgM=";
    };

    # Patches to fix Hopper build failure
    # https://github.com/Dao-AILab/flash-attention/pull/1719
    # https://github.com/Dao-AILab/flash-attention/pull/1723
    patches = [
      (fetchpatch {
        url = "https://github.com/Dao-AILab/flash-attention/commit/dad67c88d4b6122c69d0bed1cebded0cded71cea.patch";
        hash = "sha256-JSgXWItOp5KRpFbTQj/cZk+Tqez+4mEz5kmH5EUeQN4=";
      })
      (fetchpatch {
        url = "https://github.com/Dao-AILab/flash-attention/commit/e26dd28e487117ee3e6bc4908682f41f31e6f83a.patch";
        hash = "sha256-NkCEowXSi+tiWu74Qt+VPKKavx0H9JeteovSJKToK9A=";
      })
    ];

    dontConfigure = true;

    buildPhase = ''
      rm -rf csrc/cutlass
      ln -sf ${cutlass} csrc/cutlass
    '';

    installPhase = ''
      cp -rva . $out
    '';
  };
in

buildPythonPackage.override { stdenv = torch.stdenv; } rec {
  pname = "vllm";
  version = "0.18.12";
  format = "setuptools";

  # Use local source
  src = lib.cleanSource ../.;

  # Build dependencies
  nativeBuildInputs = [
    cmake
    ninja
    gcc13
    git
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
    setuptools
    setuptools-scm
    packaging
    wheel
    torch
  ];

  # Runtime/build dependencies
  buildInputs = with cudaPackages; [
    nccl
    cudnn
    libcufile
  ] ++ mergedCudaLibraries;

  # Python dependencies
  propagatedBuildInputs = [
    torch
    numpy
    transformers
    fastapi
    uvicorn
    pydantic
    sentencepiece
    tokenizers
    huggingface-hub
    requests
    psutil
    pyzmq
    # Additional runtime dependencies
    cbor2
    blake3
    cachetools
    einops
    gguf
    protobuf
    py-cpuinfo
    prometheus-client
    prometheus-fastapi-instrumentator
    python-json-logger
    tiktoken
    compressed-tensors
    depyf
    partial-json-parser
    xgrammar
    msgspec
    outlines
    lm-format-enforcer
    llguidance
    opentelemetry-api
    opentelemetry-sdk
    opentelemetry-exporter-otlp
  ];

  # Tell setuptools-scm to use the version from the tag
  SETUPTOOLS_SCM_PRETEND_VERSION = version;

  # Patches for pyproject.toml
  postPatch = ''
    # Relax torch version constraint for nixpkgs compatibility
    substituteInPlace pyproject.toml \
      --replace-fail "torch == 2.10.0" "torch >= 2.10.0" \
      --replace-fail "setuptools>=77.0.3,<81.0.0" "setuptools"
  '';

  # Build environment variables
  env = {
    VLLM_TARGET_DEVICE = "cuda";
    CUDA_HOME = "${lib.getDev cudaPackages.cuda_nvcc}";
    MAX_JOBS = "4";
    NVCC_THREADS = "1";
    VLLM_USE_TRITON_FLASH_ATTN = "0";
    VLLM_DISABLE_SCCACHE = "1";
    # TRITON_KERNELS_SRC_DIR must point to the triton_kernels directory itself
    # (not the parent), see cmake/external_projects/triton_kernels.cmake
    TRITON_KERNELS_SRC_DIR = "${triton-kernels}/python/triton_kernels/triton_kernels";
    # Pass cmake flags via CMAKE_ARGS (read by setup.py)
    CMAKE_ARGS = lib.concatStringsSep " " [
      (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_CUTLASS" "${lib.getDev cutlass}")
      (lib.cmakeFeature "CUTLASS_INCLUDE_DIR" "${lib.getDev cutlass}/include")
      # Blackwell (RTX 5090) support requires CUDA 12.8+ and arch 10.0 or 12.0
      (lib.cmakeFeature "TORCH_CUDA_ARCH_LIST" "8.6;8.9;9.0;10.0;12.0")
      (lib.cmakeFeature "CUDA_TOOLKIT_ROOT_DIR" "${symlinkJoin {
        name = "cuda-merged-${cudaPackages.cudaMajorMinorVersion}";
        paths = builtins.concatMap (p: [ (lib.getBin p) (lib.getLib p) (lib.getDev p) ]) mergedCudaLibraries;
      }}")
      (lib.cmakeFeature "CUTLASS_NVCC_ARCHS_ENABLED" "80;86;89;90;100;120")
      (lib.cmakeFeature "FLASH_MLA_SRC_DIR" "${lib.getDev flashmla}")
      (lib.cmakeFeature "QUTLASS_SRC_DIR" "${lib.getDev qutlass}")
      (lib.cmakeFeature "VLLM_FLASH_ATTN_SRC_DIR" "${lib.getDev vllm-flash-attn}")
      # Explicitly set VLLM_PYTHON_EXECUTABLE to ensure cmake can find Python
      (lib.cmakeFeature "VLLM_PYTHON_EXECUTABLE" "${python3.interpreter}")
    ];
  };

  # Pre-build setup
  preBuild = ''
    export HOME=$TMPDIR
  '';

  # Disable cmake configure phase - vllm uses setup.py
  dontUseCmakeConfigure = true;

  # Don't run tests during build (too slow)
  doCheck = false;

  # Relax Python dependencies
  pythonRelaxDeps = true;

  # Check that vllm imports correctly
  pythonImportsCheck = [ "vllm" ];

  meta = with lib; {
    description = "High-throughput and memory-efficient inference and serving engine for LLMs";
    homepage = "https://github.com/vllm-project/vllm";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
