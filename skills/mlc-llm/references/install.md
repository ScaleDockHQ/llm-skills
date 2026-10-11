# Install MLC LLM

> Verified against MLC LLM main (8978ea9a; tags v0.20.0 and v0.26.dev0), 2026-10-11

Both routes need approval. Use an isolated conda environment (upstream strongly recommends conda). Python 3.13 is recommended.

## Prebuilt nightly wheels

```bash
conda create --name mlc-prebuilt python=3.13 && conda activate mlc-prebuilt
conda install -c conda-forge git-lfs
# Linux, pick ONE backend suffix
python -m pip install --pre -U -f https://mlc.ai/wheels mlc-llm-nightly-cu128 mlc-ai-nightly-cu128   # CUDA 12.8
# cu130 (CUDA 13.0), rocm61, rocm62, cpu are the other suffixes
# macOS (CPU + Metal) and Windows (CPU + Vulkan)
python -m pip install --pre -U -f https://mlc.ai/wheels mlc-llm-nightly-cpu mlc-ai-nightly-cpu
python -c "import mlc_llm; print(mlc_llm)"
pip list 2>/dev/null | grep -iE 'mlc|tvm'      # record versions
```

| Platform | Backend notes                                                                                                                                                          |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Linux    | CUDA 12.8 or 13.0, ROCm 6.1 or 6.2, CPU; Vulkan is supported in all Linux packages: `conda install -c conda-forge gcc libvulkan-loader`                                |
| macOS    | "CPU + Metal" package, check `conda info \| grep platform` is `osx-arm64` on Apple silicon                                                                             |
| Windows  | "CPU + Vulkan"; also `conda install -c conda-forge clang libvulkan-loader git-lfs git` for download and JIT; `conda install zstd` fixes a missing `tvm.dll` dependency |

Docs notes: if you see "GLIBC not found", `conda install -c conda-forge libstdcxx-ng`. Git LFS is required to download model repos. The CPU wheel is the one named for macOS Metal.

## Build from source

Needs CMake >= 3.24, Git, Rust and Cargo (Hugging Face tokenizers), and a GPU runtime (CUDA >= 11.8, Metal or Vulkan).

```bash
conda create -n mlc-chat-venv -c conda-forge "cmake>=3.24" rust git python=3.13 && conda activate mlc-chat-venv
git clone --recursive https://github.com/mlc-ai/mlc-llm.git && cd mlc-llm
git rev-parse --short HEAD                 # record it
mkdir -p build && cd build
python ../cmake/gen_cmake_config.py        # interactive: pick CUDA/Vulkan/Metal/ROCm
cmake .. && make -j"$(nproc)" && cd ..
cd python && pip install -e . && cd ..     # or: export MLC_LLM_SOURCE_DIR=$PWD PYTHONPATH=$PWD/python
ls -l build/                               # expect libmlc_llm.so and libtvm_runtime.so
mlc_llm chat -h
```

Only the TVM runtime (bundled in `3rdparty/tvm`) is needed to run models. To **compile** your own models you also need the TVM compiler: follow the "Install TVM Unity" page in upstream docs (`docs/install/tvm.rst`); the nightly `mlc-ai-nightly-*` wheel provides it.

## Device check

```bash
python -m mlc_llm.cli.check_device cuda:0 2>&1 | tail -2    # also: vulkan, metal, rocm, opencl
```

If this exact module path fails on your build, run `mlc_llm --help` and the Python `tvm.cuda(0).exist` check from the TVM docs instead.

## Other targets (pointers)

Web (WebGPU/WASM): `mlc-ai/web-llm` and `docs/install/emcc.rst`. iOS and Android apps: `ios/` and `android/` directories and `docs/deploy/ios.rst`, `docs/deploy/android.rst`. A prebuilt Android APK is linked in the quick start; the iOS app is on the App Store as "MLC Chat".
