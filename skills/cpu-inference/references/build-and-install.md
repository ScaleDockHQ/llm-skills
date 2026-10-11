# Install and build for CPU

> Verified against llama.cpp b11557 (docs/build.md, docs/docker.md, release assets), 2026-10-11

## Prebuilt

Release assets for CPU on b11557: `llama-b11557-bin-ubuntu-x64.tar.gz`, `llama-b11557-bin-ubuntu-arm64.tar.gz`, `llama-b11557-bin-win-cpu-x64.zip`, `llama-b11557-bin-win-cpu-arm64.zip`, `llama-b11557-bin-macos-x64.tar.gz`. Pick the newest tag from the releases page; do not hardcode this one.

```bash
curl -s https://api.github.com/repos/ggml-org/llama.cpp/releases/latest | jq -r '.tag_name, (.assets[].name | select(test("ubuntu-(x64|arm64)|win-cpu|macos-x64")))'
```

Docker, CPU: `ghcr.io/ggml-org/llama.cpp:server` (`llama-server` only), `:light` and `:full` (platforms `linux/amd64`, `linux/arm64`, `linux/s390x`). A generic image cannot know your CPU; prefer a native build for the last bit of speed.

## Build from source (native)

```bash
git clone https://github.com/ggml-org/llama.cpp && cd llama.cpp
cmake -B build                                  # GGML_NATIVE defaults to on for a normal host build
cmake --build build --config Release -j
build/bin/llama-server --version
```

Notes from upstream: `-j` or Ninja for parallel builds, `ccache` for repeats, `-DBUILD_SHARED_LIBS=OFF` for a static build.

## Options that matter on CPU

```bash
cmake -B build -DGGML_CPU_KLEIDIAI=ON           # AArch64 only (Linux, Apple arm64, Windows arm64, Android arm64-v8a)
cmake -B build -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=OpenBLAS   # may speed prompt processing at batch sizes above 32; no effect on generation
cmake -B build -DGGML_NATIVE=OFF                # portable binary for other machines (slower kernels)
```

- **BLAS** helps prompt processing with batch size above 32 (default 512) and does not affect generation (upstream). Vendors listed upstream include OpenBLAS, BLIS, AOCL-BLAS and Intel oneMKL; for AMD CPUs upstream recommends the ZenDNN backend over AOCL-BLAS (`docs/backend/ZenDNN.md`).
- **KleidiAI** makes Arm kernels available; llama.cpp still selects per CPU feature, tensor type and shape at runtime. Never enable it for x86 or 32-bit Arm.
- **Portable binary.** `GGML_NATIVE=OFF` builds a baseline. Upstream also supports building backends as dynamic libraries (`GGML_BACKEND_DL`) so one binary adapts at runtime; with `GGML_CPU_ALL_VARIANTS` (needs `GGML_BACKEND_DL` and shared libraries) it builds all CPU variants.
- Illegal-instruction crashes mean the binary was built for a newer CPU than the one running it (`troubleshooting.md`).

## Verify

```bash
build/bin/llama-bench -m model.gguf -p 128 -n 32 -r 1 2>&1 | head -20
build/bin/llama-server --list-devices           # CPU only: no GPU devices listed
```

## Official links

- https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
- https://github.com/ggml-org/llama.cpp/blob/master/docs/docker.md
- https://github.com/ggml-org/llama.cpp/releases
