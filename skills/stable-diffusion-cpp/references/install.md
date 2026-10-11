# stable-diffusion.cpp: install

> Verified against stable-diffusion.cpp master-956-1b0ba10 (README, docs/build.md, docs/docker.md, GitHub releases and the ghcr.io image index), 2026-10-11

Upstream: [leejet/stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp) (MIT, not archived, last push 2026-10-10). There are no semver releases: every push to master is a release named `master-<count>-<sha>` (956 on 2026-10-10). The README says the project is under active development and options "may change frequently".

## Pick an install path

| Path                     | Use when                                                                                             | Notes                                                                                                                                                                                                                                                                                                                     |
| ------------------------ | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Release zip              | quick trial on macOS arm64, Linux x86_64 (CPU, Vulkan, ROCm) or Windows (CPU, CUDA 12, Vulkan, ROCm) | Assets on 2026-10-11: `sd-master-1b0ba10-bin-Darwin-macOS-26.6.2-arm64.zip`, `...-Linux-Ubuntu-24.04-x86_64.zip`, `...-x86_64-vulkan.zip`, `...-x86_64-rocm-10.1.0.zip`, `...-win-cuda12-x64.zip` (plus `cudart-sd-bin-win-cu12-x64.zip`), `win-cpu`, `win-vulkan`, `win-rocm`. **No Linux CUDA and no Linux arm64 zip.** |
| Container image          | NVIDIA Linux, DGX Spark, repeatable servers                                                          | `ghcr.io/leejet/stable-diffusion.cpp:master-cuda` (linux/amd64), `:master-cuda-spark` (linux/arm64), `:master-vulkan` (amd64), plus `master-musa` and `master-sycl`. `:master` is the documented default CLI image. Tags move; pin the digest.                                                                            |
| CMake build              | no matching asset, custom backend, newer than the last release                                       | `docs/build.md`.                                                                                                                                                                                                                                                                                                          |
| llama-swap unified image | llama-swap already runs the stack                                                                    | `ghcr.io/mostlygeek/llama-swap:unified-cuda13` bundles `sd-server` (`combos/llama-swap-litellm.md`).                                                                                                                                                                                                                      |

A release zip contains `sd-cli`, `sd-server` and `libstable-diffusion` (the macOS zip on 2026-10-11 also shipped `ggml.txt` and a licence text). `sd-cli --help` and `sd-server --help` print the build commit on their first line.

## Release zip, macOS arm64

```bash
mkdir -p ~/sdcpp && cd ~/sdcpp
gh release download master-956-1b0ba10 -R leejet/stable-diffusion.cpp -p 'sd-master-*-Darwin-*-arm64.zip'
unzip -o sd-master-*.zip && ./sd-server --list-devices
```

The start compiles Metal kernels (the flash-attention library took about 15 s in a test on 2026-10-11). The build guide notes that Metal is inefficient on very large matrices; measure before choosing it over a smaller quant.

## Container images

Upstream's Docker doc runs the CLI by default and the server through the entrypoint:

```bash
docker run --rm --init --gpus all -v /srv/models/sd:/models:ro -v /srv/out:/output \
  -p 127.0.0.1:1234:1234 --entrypoint /sd-server \
  ghcr.io/leejet/stable-diffusion.cpp:master-cuda \
  --listen-ip 0.0.0.0 --listen-port 1234 -m /models/model.safetensors
```

- Inside a container bind `0.0.0.0` but publish only `127.0.0.1:` on the host.
- Use `:master-cuda-spark` on arm64 DGX Spark. Check platforms before pulling: `docker manifest inspect ghcr.io/leejet/stable-diffusion.cpp:master-cuda-spark | jq -c '[.manifests[].platform|"\(.os)/\(.architecture)"]'`.
- Local builds: `docker build -f docker/Dockerfile -t sd .` (variants `Dockerfile.cuda`, `.musa`, `.sycl`, `.vulkan` exist in `docker/`).

## CMake build

```bash
git clone --recursive https://github.com/leejet/stable-diffusion.cpp && cd stable-diffusion.cpp
mkdir build && cd build
cmake .. -DSD_CUDA=ON        # pick one backend flag, see table
cmake --build . --config Release -j
```

| Backend       | Flag                                                       | Notes                                                                                         |
| ------------- | ---------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| CPU           | none                                                       | `-DGGML_OPENBLAS=ON` adds OpenBLAS                                                            |
| NVIDIA        | `-DSD_CUDA=ON`                                             | CUDA toolkit required; native SageAttention is included with the patched GGML (`--sage-attn`) |
| AMD           | `-DSD_HIPBLAS=ON` with clang and `-DGPU_TARGETS=$GFX_NAME` | set `GFX_NAME` yourself for unsupported cards (for example `gfx1030`)                         |
| Apple         | `-DSD_METAL=ON`                                            |                                                                                               |
| Vulkan        | `-DSD_VULKAN=ON`                                           | needs Vulkan SDK or `libvulkan-dev glslc spirv-headers`                                       |
| Moore Threads | `-DSD_MUSA=ON`                                             |                                                                                               |
| Intel         | `-DSD_SYCL=ON` with `icx`/`icpx`                           | optional `-DGGML_SYCL_F16=ON`                                                                 |
| Adreno        | OpenCL, see `docs/build.md`                                | mostly Q4_0 optimised                                                                         |

Other options: `-DSD_USE_UPSTREAM_GGML=ON` swaps the patched GGML for upstream (some operators and FP8 or INT8 handling are lost; see build.md), `-DSD_WEBP=OFF -DSD_WEBM=OFF` drops image and video codecs, `-DSD_SERVER_BUILD_FRONTEND=ON` rebuilds the web UI (needs Node 20 and pnpm 10). Update an existing clone with `git pull origin master && git submodule update --init`.

## DGX Spark and other arm64 Linux

No Linux arm64 zip exists. Use `:master-cuda-spark`, the llama-swap unified image, or build with `-DSD_CUDA=ON`. Unified memory means weights and an LLM share one pool; the CPU offload flags save nothing there (`performance-memory.md`). See the `nvidia-dgx-spark` skill.

## Verify

```bash
sd-server --list-devices           # the GPU must appear, else the build lacks that backend
sd-cli --help | head -1            # records the commit
```
