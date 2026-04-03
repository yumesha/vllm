# nix/package.nix
# Nix package for vLLM - builds from local source

{ lib
, python3
, fetchFromGitHub
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
in

buildPythonPackage.override { stdenv = torch.stdenv; } rec {
  pname = "vllm";
  version = "0.18.12";
  pyproject = true;

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
  ];

  # Python build system dependencies
  build-system = [
    cmake
    ninja
    packaging
    setuptools
    setuptools-scm
    torch
    wheel
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
  ];

  # Tell setuptools-scm to use the version from the tag
  SETUPTOOLS_SCM_PRETEND_VERSION = version;

  # Don't use cmake configure (we use setup.py)
  dontUseCmakeConfigure = true;

  # CMake flags for vLLM build
  cmakeFlags = [
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_CUTLASS" "${lib.getDev cutlass}")
    (lib.cmakeFeature "TORCH_CUDA_ARCH_LIST" "8.6;8.9;9.0")
    (lib.cmakeFeature "CUDA_TOOLKIT_ROOT_DIR" "${symlinkJoin {
      name = "cuda-merged-${cudaPackages.cudaMajorMinorVersion}";
      paths = builtins.concatMap (p: [ (lib.getBin p) (lib.getLib p) (lib.getDev p) ]) mergedCudaLibraries;
    }}")
    (lib.cmakeFeature "CUTLASS_NVCC_ARCHS_ENABLED" "80;86;89;90")
  ];

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
  };

  # Pre-build setup
  preBuild = ''
    export HOME=$TMPDIR
  '';

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
