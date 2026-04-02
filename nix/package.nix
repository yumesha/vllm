# nix/package.nix
# Nix package for vLLM

{ lib
, buildPythonPackage
, python
, setuptools
, setuptools-scm
, cmake
, ninja
, packaging
, torch
, cudaPackages
  # Runtime dependencies
, numpy
, transformers
, fastapi
, uvicorn
, pydantic
, prometheus-fastapi-instrumentator
, prometheus-client
, sentencepiece
, tokenizers
, huggingface-hub
, py-cpuinfo
, psutil
, py-libnuma
, openai
, tiktoken
, einops
, ray
, nvidia-ml-py
, requests
, pyzmq
, zmq
, uvloop
, python-json-logger
, transformers-stream-generator
, einops-exts
, torchaudio
, torchvision
, pip
, wheel
, autoAddDriverRunpath
, symlinkJoin
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

  getAllOutputs = p: [
    (lib.getBin p)
    (lib.getLib p)
    (lib.getDev p)
  ];
in

buildPythonPackage rec {
  pname = "vllm";
  version = "0.18.3";

  src = lib.cleanSource ../.;

  pyproject = true;

  nativeBuildInputs = [
    cmake
    ninja
    packaging
    setuptools
    setuptools-scm
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
  ];

  build-system = [
    cmake
    ninja
    packaging
    setuptools
    setuptools-scm
    torch
  ];

  buildInputs = with cudaPackages; [
    nccl
    cudnn
    libcufile
  ] ++ mergedCudaLibraries;

  dontUseCmakeConfigure = true;

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DVLLM_TARGET_DEVICE=cuda"
    "-DCUDA_TOOLKIT_ROOT_DIR=${symlinkJoin {
      name = "cuda-merged-${cudaPackages.cudaMajorMinorVersion}";
      paths = builtins.concatMap getAllOutputs mergedCudaLibraries;
    }}"
    "-DCAFFE2_USE_CUDNN=ON"
    "-DCAFFE2_USE_CUFILE=ON"
  ];

  env = {
    VLLM_TARGET_DEVICE = "cuda";
    CUDA_HOME = "${lib.getDev cudaPackages.cuda_nvcc}";
    MAX_JOBS = "8";
  };

  propagatedBuildInputs = [
    torch
    numpy
    transformers
    fastapi
    uvicorn
    pydantic
    prometheus-fastapi-instrumentator
    prometheus-client
    sentencepiece
    tokenizers
    huggingface-hub
    py-cpuinfo
    psutil
    py-libnuma
    openai
    tiktoken
    einops
    ray
    nvidia-ml-py
    requests
    pyzmq
    uvloop
    python-json-logger
    torchaudio
    torchvision
  ];

  pythonImportsCheck = [ "vllm" ];

  meta = with lib; {
    description = "High-throughput and memory-efficient inference and serving engine for LLMs";
    homepage = "https://github.com/yumesha/vllm";
    license = licenses.asl20;
    maintainers = [ ];
  };
}
