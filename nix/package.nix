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

  # Fetch CUTLASS source for vLLM build
  cutlass = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cutlass";
    rev = "v4.4.2";  # Match CUTLASS_REVISION in CMakeLists.txt
    hash = "sha256-0iwcw4hsdpp1mlvsgf1xmg908zgh3kjf4k7pv37gl4vs8rvl1byj=";
  };
in

buildPythonApplication rec {
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
    # Python cmake package (required by pyproject.toml build-system)
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

  # Patch pyproject.toml to relax torch version constraint only
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'torch == 2.10.0' 'torch'
  '';

  env = {
    VLLM_TARGET_DEVICE = "cuda";
    CUDA_HOME = "${lib.getDev cudaPackages.cuda_nvcc}";
    MAX_JOBS = "4";
    NVCC_THREADS = "1";
    TORCH_CUDA_ARCH_LIST = "10.0;12.0";
    VLLM_USE_TRITON_FLASH_ATTN = "0";
    # Disable sccache/ccache detection
    VLLM_DISABLE_SCCACHE = "1";
    # Provide pre-fetched CUTLASS source
    VLLM_CUTLASS_SRC_DIR = "${cutlass}";
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
