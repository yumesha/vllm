# nix/package.nix
# Nix package for vLLM - based on official nixpkgs approach

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
  # Python packages - listed individually
, buildPythonApplication
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
, python312Packages
}:

let
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

  # CUTLASS source for vLLM build
  cutlass = fetchFromGitHub {
    name = "cutlass-source";
    owner = "NVIDIA";
    repo = "cutlass";
    tag = "v4.4.2";  # Match CUTLASS_REVISION in CMakeLists.txt
    hash = "sha256-0q9Ad0Z6E/rO2PdM4uQc8H0E0qs9uKc3reHepiHhjEc=";
  };
in

buildPythonApplication.override { stdenv = torch.stdenv; } rec {
  pname = "vllm";
  version = "0.18.12";

  src = lib.cleanSource ../.;

  format = "pyproject";

  nativeBuildInputs = [
    cmake
    ninja
    gcc13
    git
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
    # Python build dependencies
    setuptools
    setuptools-scm
    packaging
    wheel
    torch
    python312Packages.cmake
  ];

  buildInputs = with cudaPackages; [
    nccl
    cudnn
    libcufile
  ] ++ mergedCudaLibraries;

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

  dontUseCmakeConfigure = true;

  cmakeFlags = [
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_CUTLASS" "${lib.getDev cutlass}")
    (lib.cmakeFeature "TORCH_CUDA_ARCH_LIST" "10.0;12.0")
    (lib.cmakeFeature "CUDA_TOOLKIT_ROOT_DIR" "${symlinkJoin {
      name = "cuda-merged-${cudaPackages.cudaMajorMinorVersion}";
      paths = builtins.concatMap (p: [ (lib.getBin p) (lib.getLib p) (lib.getDev p) ]) mergedCudaLibraries;
    }}")
  ];

  # Patch pyproject.toml to relax version constraints
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail "torch == 2.10.0" "torch >= 2.10.0" \
      --replace-fail "setuptools>=77.0.3,<81.0.0" "setuptools"
  '';

  env = {
    VLLM_TARGET_DEVICE = "cuda";
    CUDA_HOME = "${lib.getDev cudaPackages.cuda_nvcc}";
    MAX_JOBS = "4";
    NVCC_THREADS = "1";
    VLLM_USE_TRITON_FLASH_ATTN = "0";
    VLLM_DISABLE_SCCACHE = "1";
  };

  preBuild = ''
    export HOME=$TMPDIR
  '';

  dontUsePipInstall = false;
  doCheck = false;
  pythonRelaxDeps = true;
  pythonImportsCheck = [ "vllm" ];

  meta = with lib; {
    description = "High-throughput and memory-efficient inference and serving engine for LLMs";
    homepage = "https://github.com/yumesha/vllm";
    license = licenses.asl20;
  };
}
