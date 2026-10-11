# Install ik_llama.cpp

> Verified against ik_llama.cpp main (89bba35c, no tagged releases), 2026-10-11

All paths need approval before running. The project publishes no GitHub releases, so reproducibility comes from a commit SHA or an image digest.

## Support matrix

| Platform                             | Status upstream                                                        |
| ------------------------------------ | ---------------------------------------------------------------------- |
| CPU with AVX2 or better, ARM_NEON    | fully functional and performant                                        |
| NVIDIA CUDA, Turing or newer         | fully functional and performant                                        |
| ROCm, Vulkan, Metal, old NVIDIA, AVX | present from llama.cpp but not maintained; issues will not be resolved |
| macOS, Windows                       | build from source; same backend rules apply                            |

FlashMLA-3 on CUDA needs Ampere or newer.

## Prebuilt images

Tags on `ghcr.io/ikawrakow/ik-llama-cpp` (list: the package page on GitHub):

```bash
docker pull ghcr.io/ikawrakow/ik-llama-cpp:cu12-server   # llama-server only, CUDA 12
docker pull ghcr.io/ikawrakow/ik-llama-cpp:cu12-swap     # llama-swap + llama-server
docker pull ghcr.io/ikawrakow/ik-llama-cpp:cu12-full     # llama-server, llama-quantize, tools
docker pull ghcr.io/ikawrakow/ik-llama-cpp:cpu-server    # also cpu-swap, cpu-full
docker inspect --format '{{index .RepoDigests 0}}' ghcr.io/ikawrakow/ik-llama-cpp:cu12-server   # record the digest
```

The `server` target sets `LLAMA_ARG_HOST=0.0.0.0`, has `/app/llama-server` as entrypoint and a `curl /health` healthcheck on port 8080. Publish with `-p 127.0.0.1:8080:8080`. The `swap` target runs `/app/llama-swap -config /app/config.yaml` and listens on 8080 inside the container (upstream docs map it to host 9292). CUDA containers need the NVIDIA Container Toolkit (`--runtime nvidia` or `--gpus all`; Podman: `--device nvidia.com/gpu=all --security-opt=label=disable`).

Upstream's own `docs/docker.md` is inherited from llama.cpp and marked outdated: use `docker/README.md` instead.

## Build with CMake

```bash
git clone https://github.com/ikawrakow/ik_llama.cpp && cd ik_llama.cpp
git rev-parse --short HEAD        # record it
# Debian/Ubuntu prerequisites
sudo apt-get install -y build-essential git libcurl4-openssl-dev curl libgomp1 cmake
```

CPU:

```bash
cmake -B build -DGGML_NATIVE=ON
cmake --build build --config Release -j"$(nproc)"
```

CUDA (install the driver and CUDA Toolkit first):

```bash
cmake -B build -DGGML_NATIVE=ON -DGGML_CUDA=ON
cmake --build build --config Release -j"$(nproc)"
```

Useful options from `docs/build.md` and `docs/parameters.md`:

| Option                                                                               | Purpose                                                                                   |
| ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------- |
| `-DCMAKE_CUDA_ARCHITECTURES=86`                                                      | Build only for your GPU (8.6 for RTX 30, 8.9 for RTX 40; 12.0 for RTX 50 in docker notes) |
| `-DGGML_AVX512=ON -DGGML_AVX512_VNNI=ON -DGGML_AVX512_VBMI=ON -DGGML_AVX512_BF16=ON` | Zen4 or Sapphire Rapids and newer: activates the IQK fancy-SIMD path                      |
| `-DGGML_RPC=ON`                                                                      | RPC backend (`references/parallelism-multinode.md`)                                       |
| `-DGGML_IQK_FA_ALL_QUANTS=ON`                                                        | More KV cache quantization combinations in flash attention                                |
| `-DGGML_NCCL=OFF`                                                                    | Disable NCCL                                                                              |
| `-DGGML_MAX_CONTEXTS=2048`                                                           | Only for quants made with the Thireus quantization suite                                  |
| `-DGGML_MAX_SRC=N`                                                                   | Maximum GPU count                                                                         |
| `-DLLAMA_SERVER_SQLITE3=ON`                                                          | sqlite3 for the mikupad alternative web UI                                                |

Without the AVX-512 flags a vanilla Release build falls back silently to the AVX2 path on Zen4/Sapphire Rapids. `docs/build.md` shows a check: count VNNI instructions in the built binary; zero means the IQK kernels fell back to AVX2.

Binaries land in `build/bin/`: `llama-server`, `llama-cli`, `llama-quantize`, `llama-imatrix`, `llama-sweep-bench`, `llama-mtmd-cli`.

## Windows

`docs/build.md` has a step-by-step successful Windows build (MSVC, CUDA, AVX-512 options). Use it as written; Windows is not a CI target.

## Docker bake (own images)

```bash
docker buildx create --name ik-llama-builder --use
VARIANT=cpu docker buildx bake --builder ik-llama-builder --load full swap
# CUDA: set CUDA_VERSION and CUDA_DOCKER_ARCH in docker/ik_llama-cuda.Containerfile, then:
VARIANT=cu12 docker buildx bake --builder ik-llama-builder --load full swap
docker buildx bake --builder ik-llama-builder --set full.args.BUILD_COMMIT=<sha> full   # pin a commit
```

The CUDA Containerfile defaults to CUDA 12.6.2, Ubuntu 24.04 and `CUDA_DOCKER_ARCH="75-virtual;80-virtual;86-real;89-real"`; Blackwell (compute 12.0) needs a CUDA version that supports it and an added arch entry.

## Verify

```bash
./build/bin/llama-server --version
./build/bin/llama-server -m /models/model.gguf -ngl 999 --host 127.0.0.1 --port 8080 &
curl -s http://127.0.0.1:8080/health
```
