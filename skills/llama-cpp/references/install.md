# llama.cpp: install

> Verified against llama.cpp b11556 (master) and v0.6.0 (docs/install.md, docs/build.md, docs/docker.md, release assets), 2026-10-11

Pick the route that matches the platform. Releases are build tags `bNNNN` that appear several times a day; `v0.6.0` is a named release marker on the same repository. Check `llama-server --version` after any install.

## Package managers (prebuilt)

| Route               | Command                                                                       | Platforms             | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ------------------- | ----------------------------------------------------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Homebrew            | `brew install llama.cpp`                                                      | macOS (Metal), Linux  | Formula tracks upstream releases automatically.                                                                                                                                                                                                                                                                                                                                                                                       |
| Winget              | `winget install llama.cpp`                                                    | Windows               | Updated automatically with releases.                                                                                                                                                                                                                                                                                                                                                                                                  |
| conda-forge         | `conda install -c conda-forge llama.cpp` (also `mamba`, `pixi add llama.cpp`) | Windows, macOS, Linux | CUDA and Vulkan builds (Win/Linux), Metal (macOS). Maintained by `conda-forge/llama.cpp-feedstock`.                                                                                                                                                                                                                                                                                                                                   |
| MacPorts            | `sudo port install llama.cpp`                                                 | macOS                 |                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Nix                 | `nix profile install nixpkgs#llama-cpp`                                       | macOS, Linux          | Non-flake: `nix-env --file '<nixpkgs>' --install --attr llama-cpp`.                                                                                                                                                                                                                                                                                                                                                                   |
| llama.app installer | `curl -LsSf https://llama.app/install.sh \| sh`                               | macOS, Linux          | Windows: `irm https://llama.app/install.ps1 \| iex`. Installs one `llama` binary into `~/.local/bin` (`llama serve -hf <repo>`, `llama cli -hf <repo>`); probes CUDA and ROCm. The script is fetched from `huggingface.co/buckets/ggml-org/install.sh`. Read it before piping to a shell; `HF_TOKEN` is only used for the download. Argument parity of `llama serve` with `llama-server` is **unverified**: run `llama serve --help`. |

Package-manager builds lag a few hours behind master and may not include every backend (for example SYCL or a specific ROCm). Use a release archive or Docker for those.

## Release archives

Download from https://github.com/ggml-org/llama.cpp/releases. Asset names on b11556 (names change per release; list them with `gh api repos/ggml-org/llama.cpp/releases/latest --jq '.assets[].name'`, noting that `/releases/latest` can return a `vX.Y.Z` marker without binaries, in which case use the newest `bNNNN` release):

- macOS: `llama-bNNNN-bin-macos-arm64.tar.gz`, `...-macos-x64.tar.gz`
- Linux: `ubuntu-x64` (CPU), `ubuntu-arm64`, `ubuntu-vulkan-x64`, `ubuntu-vulkan-arm64`, `ubuntu-cuda-12.8-x64`, `ubuntu-cuda-13.4-x64`, `ubuntu-cuda-13.4-arm64`, `ubuntu-rocm-10.0-x64`, `ubuntu-sycl-fp16-x64`, `ubuntu-sycl-fp32-x64`, `ubuntu-openvino-<ver>-x64`, `ubuntu-s390x`, plus `linux-arm64-snapdragon`
- Windows: `win-cpu-x64`, `win-cpu-arm64`, `win-vulkan-x64`, `win-vulkan-arm64`, `win-cuda-12.4-x64`, `win-cuda-13.4-x64`, `win-cuda-13.4-arm64`, `win-rocm-10.0-x64`, `win-sycl-x64`, `win-opencl-adreno-arm64`, `win-openvino-<ver>-x64`
- CUDA runtime libraries ship separately: `cudart-llama-bin-win-cuda-<ver>-x64.zip` (Windows) and `cudart-llama-bNNNN-bin-ubuntu-cuda-<ver>-<arch>.tar.gz` (Linux). Without them the CUDA build fails with missing DLLs or silently falls back to CPU unless the host has a matching CUDA toolkit.
- Android arm64 archives and an iOS `xcframework.zip` exist for embedding.

```bash
# Example: Linux x64 Vulkan (AMD, Intel, any Vulkan GPU)
tag=b11556
curl -fLO "https://github.com/ggml-org/llama.cpp/releases/download/${tag}/llama-${tag}-bin-ubuntu-vulkan-x64.tar.gz"
mkdir -p ~/llama.cpp/"$tag" && tar -xzf "llama-${tag}-bin-ubuntu-vulkan-x64.tar.gz" -C ~/llama.cpp/"$tag"
~/llama.cpp/"$tag"/*/llama-server --version
```

Keep one directory per tag and a `current` symlink so rollback is a symlink change.

## Docker images

Registry `ghcr.io/ggml-org/llama.cpp`. Three families, each with backend suffixes:

- `:server*` runs `llama-server` (the image entrypoint; arguments follow the image name).
- `:light*` runs `llama-cli` and `llama-completion`.
- `:full*` has all binaries plus the conversion/quantize tools (`--run`, `--all-in-one`).

| Suffix      | Backend            | Platforms                 |
| ----------- | ------------------ | ------------------------- |
| (none)      | CPU                | linux/amd64, arm64, s390x |
| `-cuda`     | CUDA 12            | linux/amd64, arm64        |
| `-cuda13`   | CUDA 13            | linux/amd64, arm64        |
| `-vulkan`   | Vulkan             | linux/amd64, arm64        |
| `-rocm`     | ROCm               | linux/amd64               |
| `-intel`    | SYCL               | linux/amd64               |
| `-musa`     | Moore Threads MUSA | linux/amd64               |
| `-openvino` | OpenVINO           | linux/amd64               |

Upstream says the GPU images are only built, not tested in CI, and gives no other variants: for a different CUDA/ROCm/MUSA library version or arch, build locally with `docker build -t local/llama.cpp:server-cuda --target server -f .devops/cuda.Dockerfile .` (the Dockerfile defaults are `CUDA_VERSION=12.8.1` and `CUDA_DOCKER_ARCH=default`; Ubuntu 24.04 base).

```bash
# NVIDIA (needs nvidia-container-toolkit)
docker run --rm --gpus all -p 127.0.0.1:8081:8080 -v /srv/models/gguf:/models:ro \
  ghcr.io/ggml-org/llama.cpp:server-cuda13 \
  -m /models/model-Q4_K_M.gguf -a small -c 32768 -ngl all -fa on --host 0.0.0.0 --port 8080

# AMD/Intel via Vulkan (DRI devices)
docker run --rm --device /dev/dri/renderD128:/dev/dri/renderD128 --device /dev/dri/card1:/dev/dri/card1 -p 127.0.0.1:8081:8080 -v /srv/models/gguf:/models:ro \
  ghcr.io/ggml-org/llama.cpp:server-vulkan \
  -m /models/model-Q4_K_M.gguf -ngl all --host 0.0.0.0 --port 8080

# Intel SYCL: pass the render and card nodes
docker run --device /dev/dri/renderD128:/dev/dri/renderD128 --device /dev/dri/card0:/dev/dri/card0 \
  -v /srv/models/gguf:/models:ro -p 127.0.0.1:8081:8080 ghcr.io/ggml-org/llama.cpp:server-intel \
  -m /models/model-Q4_K_M.gguf --host 0.0.0.0 --port 8080 -ngl 99
```

The `docker run --device /dev/dri` form for the ROCm image also needs `--device /dev/kfd` and the `video`/`render` groups; the upstream doc does not show a ROCm run command, so treat that as **unverified** and check `.devops/rocm.Dockerfile` and AMD's ROCm container docs.

Pin by digest in production (`docker buildx imagetools inspect ghcr.io/ggml-org/llama.cpp:server-cuda13`); tags move with every build. Inside the container publish with `--host 0.0.0.0` but map the host port to `127.0.0.1`.

`ghcr.io/mostlygeek/llama-swap:unified-cuda13` (amd64 + arm64) also bundles `llama-server` built from source; `unified-cuda` is CUDA 12 amd64, `unified-vulkan` is amd64 (per the llama-swap `docker/unified` README). See `references/combos/llama-swap-router.md`.

## Build from source (CMake)

```bash
git clone https://github.com/ggml-org/llama.cpp && cd llama.cpp
git checkout bNNNN            # optional: pin a build tag
cmake -B build <backend flags>
cmake --build build --config Release -j 8 -t llama-server llama-cli llama-bench llama-quantize llama-perplexity llama-imatrix
```

General notes (docs/build.md): use Ninja or `-j`, install `ccache` for rebuilds, `-DBUILD_SHARED_LIBS=OFF` for static binaries, `-DLLAMA_OPENSSL=ON` for TLS (needs OpenSSL 3 dev packages, otherwise it builds without SSL), `-DCMAKE_BUILD_TYPE=Debug` for debug builds on single-config generators. Multiple backends can be built together (`-DGGML_CUDA=ON -DGGML_VULKAN=ON`) and picked at runtime with `--device`; `-DGGML_BACKEND_DL=ON` builds backends as loadable libraries so one install works across different GPUs. `--list-devices` shows what a binary sees; `--device none` disables GPU entirely.

Compiling on a host that is serving competes for RAM and unified memory: stop serving or limit `-j`.

### CPU

```bash
cmake -B build && cmake --build build --config Release -j
```

BLAS is optional (`GGML_BLAS_VENDOR=OpenBLAS` and others; Accelerate is used on macOS). On arm64 add `-DGGML_CPU_KLEIDIAI=ON` for the Arm KleidiAI kernels. For a binary that must run on other CPUs, add `-DGGML_NATIVE=OFF`.

### Metal (macOS)

Enabled by default on macOS; nothing to pass. `-DGGML_METAL=OFF` disables it, and `--n-gpu-layers 0` at runtime disables GPU use. See `references/combos/apple-metal.md`.

### CUDA (NVIDIA)

Needs the CUDA toolkit (`nvcc`).

```bash
cmake -B build -DGGML_CUDA=ON
cmake --build build --config Release -j
# Specific architectures (faster, smaller): list compute capabilities
cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="86;89"
# One binary for every CUDA GPU (slow compile, big binary, some JIT at runtime)
cmake -B build -DGGML_CUDA=ON -DGGML_NATIVE=OFF
```

By default it builds for the GPUs found at configure time. If `nvcc` cannot detect the GPU (warning `Cannot find valid GPU for '-arch=native'`), list `CMAKE_CUDA_ARCHITECTURES` explicitly. Multiple toolkits: `-DCMAKE_CUDA_COMPILER=/opt/cuda-X/bin/nvcc`. Other CMake options (docs/build.md): `GGML_CUDA_FORCE_MMQ`, `GGML_CUDA_FORCE_CUBLAS`, `GGML_CUDA_FA_QUANTS` (which K/V quant pairs get FlashAttention kernels; default `q4_0-q4_0;q8_0-q8_0;f16-f16;bf16-bf16`, `all` compiles every pair slowly; uncompiled pairs fall back to f16 kernels with a warning), and `GGML_CUDA_CCCL_VERSION`.

#### aarch64, Blackwell and DGX Spark (GB10)

Use CUDA 13: the `server-cuda13` image and the `ubuntu-cuda-13.4-arm64` archive are published for arm64; CUDA 12 images also exist for arm64. A source build on the Spark is the same `-DGGML_CUDA=ON` command; GB10 is detected at configure time. The exact compute capability value for GB10 to pass in `CMAKE_CUDA_ARCHITECTURES` is **unverified** here: rely on native detection or check `nvidia-smi --query-gpu=compute_cap --format=csv`. On Blackwell, the MXFP4/NVFP4 matmul precision can be tuned at runtime with `GGML_CUDA_MMQ_PREC=auto|q8|q4` (see `references/performance-tuning.md`). GB10 has unified memory: building while a model is loaded competes for the same pool. See also the `nvidia-dgx-spark` skill (planned).

### Vulkan

Needs a Vulkan loader, headers and `glslc`, plus SPIRV headers.

```bash
sudo apt-get install libvulkan-dev glslc spirv-headers   # Debian/Ubuntu
vulkaninfo --summary | head                              # verify the driver works
cmake -B build -DGGML_VULKAN=1 && cmake --build build --config Release -j
./build/bin/llama-cli -m model.gguf -ngl 99              # log must show: ggml_vulkan: Using <your GPU>
```

Other distros: `spirv-headers` (Arch), `spirv-headers-devel` (Fedora/openSUSE). On Windows use the LunarG Vulkan SDK (`Include` already contains the headers); on Linux the LunarG tarball needs `source setup_env.sh` in every shell before building. macOS: Vulkan runs through MoltenVK or KosmicKrisp, and you build with `-DGGML_VULKAN=1 -DGGML_METAL=OFF`; Metal is the better choice there.

### ROCm / HIP (AMD)

```bash
HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
  cmake -S . -B build -DGGML_HIP=ON -DGPU_TARGETS=gfx1030 -DCMAKE_BUILD_TYPE=Release \
  && cmake --build build --config Release -- -j 16
```

`GPU_TARGETS` is optional (omitted = all GPUs in the system); find yours with `rocminfo | grep gfx | head -1 | awk '{print $2}'`. If clang reports `cannot find ROCm device library`, locate the directory with `oclc_abi_version_400.bc` under `HIP_PATH` and prefix `HIP_DEVICE_LIB_PATH=<dir>`. Windows uses Ninja with `-DGGML_HIP=ON -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++` from the x64 Native Tools prompt. At runtime `HIP_VISIBLE_DEVICES` selects GPUs; for unsupported cards `HSA_OVERRIDE_GFX_VERSION` (for example `10.3.0` on RDNA2, `11.0.0` on RDNA3) may work (not supported on Windows). On APUs and unified memory systems set `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1` (Linux).

### SYCL (Intel GPUs)

Needs the Intel oneAPI base toolkit and drivers (see docs/backend/SYCL.md).

```bash
source /opt/intel/oneapi/setvars.sh
cmake -B build -DGGML_SYCL=ON -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icpx -DGGML_SYCL_F16=ON   # F16 build; omit the flag for FP32
cmake --build build --config Release -j -v
```

Windows: `cmake -B build -G "Ninja" -DGGML_SYCL=ON -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=icx -DCMAKE_BUILD_TYPE=Release -DGGML_SYCL_F16=ON` after `setvars.bat intel64`. Error `sycl... not found` usually means `setvars.sh` was not sourced.

### Others

Also supported upstream: MUSA (Moore Threads), CANN (Ascend), OpenCL (Adreno), WebGPU, OpenVINO, ZenDNN, Hexagon, IBM Z. See docs/build.md for each; they are not covered here.

## RPC build flag

For multi-host inference add `-DGGML_RPC=ON` on every host, see `references/parallelism-multinode.md`.

## Verify an install

```bash
llama-server --version
llama-server --list-devices
llama-bench -m model.gguf -ngl 99 -p 512 -n 128     # prompt and generation speed
```

The startup log names the backend (`ggml_cuda_init: found N CUDA devices`, `ggml_vulkan: Using ...`, Metal device lines) and how many layers were offloaded.

## Sources

- https://github.com/ggml-org/llama.cpp/blob/master/docs/install.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/docker.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/SYCL.md
- https://github.com/ggml-org/llama.cpp/releases
- https://llama.app
