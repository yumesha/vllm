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
  version = "0.18.5";

  src = lib.cleanSource ../.;

  format = "pyproject";

  nativeBuildInputs = [
    cmake
    ninja
    gcc13
    git
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
    pip
    wheel
    setuptools
    setuptools-scm
    packaging
    torch
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
    MAX_JOBS = "8";
    NVCC_THREADS = "1";
    TORCH_CUDA_ARCH_LIST = "10.0;12.0";
    VLLM_USE_TRITON_FLASH_ATTN = "0";
  };

  # Skip pip install check since we build from source
  dontUsePipInstall = true;

  buildPhase = ''
    runHook preBuild

    export HOME=$TMPDIR

    # Build vLLM
    ${python3.interpreter} setup.py build_ext --inplace

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Install using pip
    pip install . --prefix=$out --no-build-isolation --no-deps

    runHook postInstall
  '';

  pythonImportsCheck = [ "vllm" ];

  meta = with lib; {
    description = "High-throughput and memory-efficient inference and serving engine for LLMs";
    homepage = "https://github.com/yumesha/vllm";
    license = licenses.asl20;
  };
}
