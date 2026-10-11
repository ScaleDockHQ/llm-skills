# Install vLLM

> Verified against vLLM v0.31.0 (docs `getting_started/installation`, `deployment/docker`, release notes), NVIDIA vLLM NGC container 26.06 to 26.09, 2026-10-11

One section per platform. Pick the container route unless the user needs to edit vLLM itself. Pin a version
everywhere and record what is running (`vllm --version`, `docker image inspect -f '{{.Id}}' <image>`).

Requirements common to all GPU routes: Linux, Python 3.10 to 3.13 (PyPI metadata says `>=3.10,<3.15`; the
install docs list 3.10 to 3.13). vLLM does not support Windows natively; use WSL.

## Image and package map

| Target                                   | Docker image (Docker Hub)                              | Wheel                                                          |
| ---------------------------------------- | ------------------------------------------------------ | -------------------------------------------------------------- |
| NVIDIA CUDA 13.0 (default since v0.31.0) | `vllm/vllm-openai:v0.31.0` (multi-arch amd64 + arm64)  | `uv pip install vllm --torch-backend=auto`                     |
| NVIDIA CUDA 12.9                         | `vllm/vllm-openai:v0.31.0-cu129`                       | `--torch-backend=cu129` or the `+cu129` release wheel          |
| NVIDIA arm64 only / amd64 only           | `v0.31.0-aarch64`, `v0.31.0-x86_64`                    | release wheels `..._aarch64.whl`, `..._x86_64.whl`             |
| AMD ROCm                                 | `vllm/vllm-openai-rocm:v0.31.0` (amd64)                | `--extra-index-url https://wheels.vllm.ai/rocm/0.31.0/rocm723` |
| CPU x86 / arm64                          | `vllm/vllm-openai-cpu:v0.31.0-x86_64`, `v0.31.0-arm64` | `+cpu` release wheels                                          |
| Intel XPU                                | `vllm/vllm-openai-xpu:v0.31.0`                         | `--extra-index-url https://wheels.vllm.ai/0.31.0/xpu`          |
| NVIDIA NGC (DGX Spark, Jetson Thor, DGX) | `nvcr.io/nvidia/vllm:<YY.MM>-py3` (amd64 + arm64)      | n/a                                                            |

The `v0.31.0` CUDA default is 13.0 (release notes, and `docker/versions.json` sets `CUDA_VERSION` 13.0.3).
`-ubuntu2404` variants of the tags exist; model-specific tags such as `gemma4-cu130` are recipe-owned
(see the NVIDIA playbook) and are not version-pinned releases. `latest-cu130` on Docker Hub was last pushed
in April 2026, so do not use it to get current code.

## NVIDIA GPU, Python (uv or pip)

Compute capability 7.5 or higher (T4, RTX 20xx, A100, L4, H100, B200 and newer). Blackwell needs CUDA 12.8
or newer in the PyTorch wheels. CUDA 13 images need an R580 or newer driver, or compatibility mode (below).

```bash
uv venv --python 3.12 --seed && source .venv/bin/activate
uv pip install vllm --torch-backend=auto        # picks the PyTorch index from the installed driver
vllm --version
```

- Always use a fresh environment. vLLM compiles CUDA kernels against one PyTorch build; a different CUDA or
  PyTorch needs a source build. conda PyTorch statically links NCCL, which can break vLLM's NCCL use.
- Pick a CUDA version explicitly: `--torch-backend=cu130` (or `UV_TORCH_BACKEND=cu130`). `uv self update` if
  the flag is not recognized.
- pip works for releases (`pip install vllm --extra-index-url https://download.pytorch.org/whl/cu129`), but
  upstream says pip is **not supported** for nightly indices (it picks the newest version across indexes).
- Specific CUDA wheel from GitHub releases:

```bash
export VLLM_VERSION=0.31.0 CUDA_VERSION=130 CPU_ARCH=$(uname -m)   # x86_64 or aarch64
uv pip install "https://github.com/vllm-project/vllm/releases/download/v${VLLM_VERSION}/vllm-${VLLM_VERSION}+cu${CUDA_VERSION}-cp38-abi3-manylinux_2_28_${CPU_ARCH}.whl" \
  --extra-index-url "https://download.pytorch.org/whl/cu${CUDA_VERSION}"
```

- Nightly: `uv pip install -U vllm --torch-backend=auto --extra-index-url https://wheels.vllm.ai/nightly`
  (variant subdirectories include `cu130` and `cpu`). Per-commit: `https://wheels.vllm.ai/<full-commit-hash>`.
- Python-only dev build: `VLLM_USE_PRECOMPILED=1 uv pip install --editable . --torch-backend=auto`.

## NVIDIA GPU, Docker (upstream image)

```bash
docker run --rm --runtime nvidia --gpus all --ipc=host -p 127.0.0.1:8000:8000 \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
  -v vllm-cache:/root/.cache/vllm \
  -e HF_TOKEN \
  vllm/vllm-openai:v0.31.0 Qwen/Qwen3-0.6B
```

- The image `ENTRYPOINT` is `vllm serve` (checked in `docker/Dockerfile`), so the model and flags follow the
  image name. Use `--entrypoint /bin/bash` for a shell.
- `--ipc=host` (or `--shm-size`) is required for tensor parallel (shared memory).
- Mount a named volume at `/root/.cache/vllm` to reuse `torch.compile` artifacts across containers; without
  it every new container recompiles. `HF_TOKEN` passed by name (`-e HF_TOKEN`) avoids putting it on the
  command line.
- Non-root: `--user 2000:0` works; mount caches under `/home/vllm` instead of `/root` and make them writable
  by group 0. A `vllm-openai-nonroot` build target exists.
- Older driver than the image's CUDA: set `-e VLLM_ENABLE_CUDA_COMPATIBILITY=1` (datacenter/professional GPUs
  only; CUDA 13 images support R535 and R570 hosts in compatibility mode).
- Optional extras are not in the image (licensing). Extend it: `FROM vllm/vllm-openai:v0.31.0` then
  `RUN uv pip install --system vllm[audio]==0.31.0` (versions must match), or install a newer
  `transformers` from git for brand-new model architectures.
- Podman: `podman run --device nvidia.com/gpu=all ... docker.io/vllm/vllm-openai:<tag> <args>`.
- Run a vLLM Recipes config: mount `config.yaml` and `env.sh`, `--entrypoint /bin/bash`, then
  `source /recipe/env.sh && exec vllm serve --config /recipe/config.yaml`.

## NVIDIA NGC container (DGX Spark, Jetson Thor, DGX systems)

`nvcr.io/nvidia/vllm:<YY.MM>-py3` is multi-arch (26.09-py3 lists amd64 and arm64, published 2026-09-28).
NVIDIA recommends it on DGX Spark. Differences from the upstream image:

- The entrypoint is not `vllm serve`: put `vllm serve <model> ...` after the image name.
- The bundled vLLM is not the upstream version number: 26.06 bundles vLLM 0.22.1 and 26.07 bundles 0.24.0
  (release notes). The 26.09 bundle was not read; check with `docker run --rm <image> vllm --version`.
- vLLM source is in `/opt/vllm`; Python 3.12 system environment.
- NVIDIA's known issue (26.06, 26.07, 26.08): `vllm serve` allocates GPU memory very aggressively by default
  on unified-memory systems (DGX Spark, Jetson); use a lower `--gpu-memory-utilization`, for example 0.7.
  Also: Nemotron Nano V3 / Super V3 NVFP4 on Spark needs `--max-num-seqs 4`; 26.06 reported gpt-oss-120b OOM
  on Spark/Jetson (use 26.05 there). Re-read the release notes for the tag you use.
- NGC 26.05 shipped without Ray; the NVIDIA two-Spark playbook patches `run_cluster.sh` to `pip install` it.
  See `references/combos/dgx-spark-dual-ray.md`.

```bash
docker run --rm --gpus all --ipc=host -p 127.0.0.1:8000:8000 \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_TOKEN \
  nvcr.io/nvidia/vllm:26.09-py3 \
  vllm serve openai/gpt-oss-20b --gpu-memory-utilization 0.7
```

Pulling from `nvcr.io` may need `docker login nvcr.io` with an NGC API key (read it from a `0600` file,
never inline).

## aarch64 and Blackwell notes (GH200, GB200, GB10/DGX Spark)

- Upstream multi-arch tags and aarch64 wheels exist. GB10 is compute capability 12.1 (SM121).
- Source build for arm64 (docs example for GH200: about 15 GB memory, about 25 minutes):

```bash
DOCKER_BUILDKIT=1 docker build . --file docker/Dockerfile --target vllm-openai --platform linux/arm64 \
  -t vllm-local:arm64 --build-arg max_jobs=<N> --build-arg nvcc_threads=2
```

Keep `max_jobs` substantially larger than `nvcc_threads` on big servers; on GB10 keep `max_jobs` low and stop
the model first, because the build shares the 128 GB with everything else. For (G)B300 the docs recommend CUDA
13 with `torch_cuda_arch_list='9.0 10.0+PTX'`. Add `--build-arg torch_cuda_arch_list=""` only if the GPU is
visible to the build (plain BuildKit does not expose it).

- Cross-building arm64 on x86 needs QEMU: `docker run --rm --privileged multiarch/qemu-user-static --reset -p yes`.
- Rubin (R100/VR200) has a documented preview build path (`INSTALL_RUBIN_PRERELEASE=true`); not covered here.
- SM120/SM121 optional kernels: `uv pip install "vllm[b12x]"` (see `references/combos/rtx-blackwell.md`).

## AMD ROCm

Supported (docs): MI200 (gfx90a), MI300 (gfx942), MI350 (gfx950), Radeon RX 7900 (gfx1100/1101), RX 9000
(gfx1200/1201), Ryzen AI MAX / AI 300 (gfx1151/1150). ROCm 6.3+; MI350 needs ROCm 7.0+; Ryzen AI needs
7.0.2+.

```bash
# Container (official since 2026-01-20; the rocm/vllm and rocm/vllm-dev images are deprecated)
docker run --rm --group-add=video --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
  --device /dev/kfd --device /dev/dri --ipc=host -p 127.0.0.1:8000:8000 \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_TOKEN \
  vllm/vllm-openai-rocm:v0.31.0 --model Qwen/Qwen3-0.6B
```

- Wheels are **Python 3.12 only**. On another Python, pip/uv silently falls back to the CUDA wheel and fails
  with `libcudart.so: cannot open shared object file`. v0.31.0 wheel: `vllm-0.31.0+rocm723-cp312-...manylinux_2_39_x86_64.whl`
  from `https://wheels.vllm.ai/rocm/0.31.0/rocm723` (the install page still says glibc >= 2.35; the wheel file
  name says 2.39, so check your distro).

```bash
uv venv --python 3.12 --seed --managed-python && source .venv/bin/activate
uv pip install vllm==0.31.0 --extra-index-url https://wheels.vllm.ai/rocm/0.31.0/rocm723
```

- `vllm/vllm-openai-rocm:nightly` for the newest code. See `references/combos/amd-instinct-rocm.md`.

## CPU

- x86: needs `avx512f` (recommended) or `avx2` (limited). FP32, FP16, BF16. Wheels since 0.17.0; arm64 wheels
  since 0.11.2 (NEON required).

```bash
docker run --rm -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -p 127.0.0.1:8000:8000 \
  -e HF_TOKEN vllm/vllm-openai-cpu:v0.31.0-x86_64 --model Qwen/Qwen3-0.6B   # arm64: v0.31.0-arm64
```

- Wheel install: `uv pip install "<release>+cpu-cp38-abi3-manylinux_2_34_x86_64.whl" --torch-backend cpu`
  (aarch64: `..._aarch64.whl`). With wheels, put Intel OpenMP on `LD_PRELOAD` (`find / -iname '*libiomp5.so'`).
- KV cache size: `VLLM_CPU_KVCACHE_SPACE` (GiB, default 4). Thread binding: `VLLM_CPU_OMP_THREADS_BIND`
  (default `auto`). The CPU image can run Recipes through `tools/recipes/serve_with_recipe.sh`.
- CPU serving is for tests and small models; performance is far below GPU.

## Apple Silicon, Intel XPU, other

- Apple GPU: community plugin [vllm-metal](https://github.com/vllm-project/vllm-metal) (MLX backend, MLX
  community checkpoints). Built-in macOS CPU build is experimental, FP32/FP16 only, no prebuilt wheels. For
  Mac serving prefer the `mlx` or `lm-studio` skills.
- Intel XPU: `vllm/vllm-openai-xpu:v0.31.0` or the XPU wheel index.
- IBM Z (s390x) and POWER have CPU builds (`Dockerfile.s390x`, `Dockerfile.ppc64le`); not covered.

## Verify

```bash
vllm --version && python -c "import torch;print(torch.__version__, torch.version.cuda, torch.cuda.is_available())"
vllm collect-env                       # diagnostic dump to attach to bug reports
curl -s http://127.0.0.1:8000/version  # on a running server
```
