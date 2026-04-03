# nix/package.nix
# Nix package for vLLM

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
in

buildPythonApplication rec {
  pname = "vllm";
  version = "0.18.9";

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

  env = {
    VLLM_TARGET_DEVICE = "cuda";
    CUDA_HOME = "${lib.getDev cudaPackages.cuda_nvcc}";
    MAX_JOBS = "4";
    NVCC_THREADS = "1";
    TORCH_CUDA_ARCH_LIST = "10.0;12.0";
    VLLM_USE_TRITON_FLASH_ATTN = "0";
    # Disable sccache/ccache detection
    VLLM_DISABLE_SCCACHE = "1";
  };

  # Use pyproject hook for building
  preBuild = ''
    export HOME=$TMPDIR
  '';

  # pip install handles the build
  dontUsePipInstall = false;

  # Skip tests during install
  doCheck = false;

  # Avoid strict import check (extensions are built but may not load in build env)
  pythonImportsCheck = [ "vllm" ];

  meta = with lib; {
    description = "High-throughput and memory-efficient inference and serving engine for LLMs";
    homepage = "https://github.com/yumesha/vllm";
    license = licenses.asl20;
  };
}
