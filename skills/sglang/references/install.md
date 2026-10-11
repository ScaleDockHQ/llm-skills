# SGLang: install

> Verified against SGLang v0.5.21 (docs: get-started/install, hardware-platforms/*; PyPI; Docker Hub lmsysorg/sglang tags), 2026-10-11

Python 3.10+ is required. SGLang v0.5.21 requires CUDA 13 on NVIDIA: the `cu129` wheels and images are retired (PyTorch 2.14 publishes no CUDA 12.9 build); `v0.5.19` / `v0.5.19-cu129` is the last CUDA 12 lane. The `pyproject.toml` at the v0.5.21 tag pins `torch==2.13.0`, `xgrammar==0.2.7`, `flashinfer_python[cu13]==0.6.18`.

## Contents

- [NVIDIA: pip or uv](#nvidia-pip-or-uv)
- [NVIDIA: Docker](#nvidia-docker)
- [aarch64 and Blackwell (GB10, GB200, B200)](#aarch64-and-blackwell)
- [AMD ROCm](#amd-rocm)
- [NVIDIA Jetson Orin](#nvidia-jetson-orin)
- [Apple Silicon (MLX)](#apple-silicon-mlx)
- [Other hardware](#other-hardware)
- [From source](#from-source)
- [Kubernetes, SkyPilot, SageMaker](#kubernetes-skypilot-sagemaker)
- [Verify the install](#verify-the-install)

## NVIDIA: pip or uv

```bash
python3 -m venv ~/venvs/sglang && source ~/venvs/sglang/bin/activate
pip install --upgrade pip uv
uv pip install --prerelease=allow sglang        # or: uv pip install --prerelease=allow "sglang==0.5.21"
sglang version
```

- uv older than 0.12.0 silently resolves `sglang` 0.5.9 without `--prerelease=allow` (some dependencies publish only pre-releases). On uv 0.12.0+ the flag is a harmless no-op.
- PyPI ships `manylinux_2_34` wheels for both `x86_64` and `aarch64`, CPython 3.10 to 3.13 (checked for 0.5.21 on 2026-10-11).
- `OSError: CUDA_HOME environment variable is not set`: `export CUDA_HOME=/usr/local/cuda-<version>`, or install FlashInfer first (see FlashInfer install docs).
- FlashInfer is the default attention kernel backend (sm75 and newer). If a FlashInfer issue hits on sm75+ GPUs, try `--attention-backend triton --sampling-backend pytorch`.
- Reinstall FlashInfer: `pip3 install --upgrade flashinfer-python --force-reinstall --no-deps` and `rm -rf ~/.cache/flashinfer`.
- Nightly wheels (from `main`): `uv pip install --prerelease=allow --index-strategy unsafe-best-match --extra-index-url https://docs.sglang.ai/whl/cu130/ sglang`. Never use these for production.
- Entry points installed: `sglang` (`serve`, `generate`, `version`) and `killall_sglang`. `sglang serve MODEL ...` is the CLI equivalent of `python -m sglang.launch_server --model-path MODEL ...`.
- The model gateway/router is a separate package: `pip install sglang-router` (0.3.2 on PyPI on 2026-10-11), launched with `python -m sglang_router.launch_router`.

## NVIDIA: Docker

Images live at `lmsysorg/sglang`, built from `docker/Dockerfile` (base `nvidia/cuda:13.0.3-cudnn-devel-ubuntu24.04`). The Python environment is on `PATH` (`/opt/sglang/bin`), so `python3 -m sglang.launch_server` works directly.

| Tag                                                  | Meaning                                                              |
| ---------------------------------------------------- | -------------------------------------------------------------------- |
| `v0.5.21`, `v0.5.21-cu130`                           | Immutable release, amd64 + arm64. Pin this.                          |
| `v0.5.21-cu130-runtime`, `v0.5.21-runtime`           | Release without build tools; about 40% smaller; for production.      |
| `latest`, `latest-cu130`, `latest-runtime`           | Mutable, newest stable release.                                      |
| `dev`, `dev-cu13`, `nightly-dev-cu13-YYYYMMDD-<sha>` | Rebuilt daily from `main`; development only.                         |
| `nightly-cu134*`                                     | arm64-only nightly built from `docker/Dockerfile.cu134` (CUDA 13.4). |
| `v0.5.21-renderer`                                   | Renderer image variant (multimodal rendering; not covered here).     |
| `latest-cu129`, `v0.5.19-cu129`                      | Last CUDA 12 images (last updated 2026-09-04). Retired.              |
| `spark`                                              | arm64, last pushed 2025-11-06; stale. Prefer `-cu130`.               |

```bash
docker pull lmsysorg/sglang:v0.5.21-cu130
docker run --rm --gpus all lmsysorg/sglang:v0.5.21-cu130 nvidia-smi
docker run --gpus all --ipc=host --shm-size 32g -p 127.0.0.1:30000:30000 \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
  --env-file ~/.config/sglang/env \
  lmsysorg/sglang:v0.5.21-cu130 \
  python3 -m sglang.launch_server --model-path meta-llama/Llama-3.1-8B-Instruct --host 0.0.0.0 --port 30000
```

- `--ipc=host` or a large `--shm-size` (upstream uses `32g`) is required: processes exchange tensors through shared memory.
- Needs the NVIDIA Container Toolkit (`--gpus all`).
- `HF_TOKEN` via `--env-file` (a `0600` file) rather than `--env HF_TOKEN=<literal>`, so it stays out of shell history and `docker inspect` output you share.
- Offline hosts: pre-download weights, mount them, and set `HF_HUB_OFFLINE=1`.
- Record the digest: `docker image inspect lmsysorg/sglang:v0.5.21-cu130 --format '{{index .RepoDigests 0}}'`.
- `docker/compose.yaml` upstream uses `network_mode: host` and `privileged: true` "required by RDMA"; only do that for RDMA, otherwise publish port 30000. See `templates/docker-compose.yml`.

## aarch64 and Blackwell

- `lmsysorg/sglang:v0.5.21-cu130` and `latest-cu130` are multi-arch (amd64 + arm64); this is the image NVIDIA's DGX Spark SGLang playbook uses (`latest-cu130`). PyPI also has aarch64 wheels.
- Blackwell GPUs (B200, GB200, GB10) run on the CUDA 13 builds, which are the only ones published now (`-cu130` images and PyPI wheels). FP4 paths: `--quantization modelopt_fp4` for NVFP4 checkpoints, `--fp4-gemm-backend` to pick the NVFP4 GEMM runner. See `models-and-formats.md`.
- GB10 (DGX Spark) specifics, memory sizing and two-node recipes: `combos/dgx-spark.md`.
- Grace-Blackwell and arm64 server images: `docker/arm64.Dockerfile` exists in the repo; the prebuilt multi-arch tags above cover the normal case.

## AMD ROCm

Docker is recommended. Prebuilt tags are per ROCm version and GPU family (amd64). The v0.5.21 release notes point to the `rocm10` tags as the default for MI30x and MI35x:

- `v0.5.21-rocm724-mi30x`, `v0.5.21-rocm720-mi30x`, `v0.5.21-rocm10-mi30x` (MI300/MI325 class)
- `v0.5.21-rocm724-mi35x`, `v0.5.21-rocm720-mi35x`, `v0.5.21-rocm10-mi35x` (MI350/MI355 class)

The ROCm-version meaning of `rocm724`/`rocm720`/`rocm10` is inferred from the tag names, not stated in the docs read: unverified. Pick from the Docker Hub tag list and the upstream AMD doc.

```bash
alias drun='docker run -it --rm --network=host --privileged --device=/dev/kfd --device=/dev/dri \
  --ipc=host --shm-size 16G --group-add video --cap-add=SYS_PTRACE \
  --security-opt seccomp=unconfined -v $HOME/dockerx:/dockerx -v /data:/data'
drun -p 30000:30000 -v ~/.cache/huggingface:/root/.cache/huggingface \
  --env-file ~/.config/sglang/env <rocm-image> \
  python3 -m sglang.launch_server --model-path NousResearch/Meta-Llama-3.1-8B --host 0.0.0.0 --port 30000
```

- `--network host` and `--privileged` are needed only for RDMA; remove them otherwise. For RoCE you may need `export NCCL_IB_GID_INDEX=3`.
- Host tuning from the AMD doc: append `pci=realloc=off iommu=pt` to `GRUB_CMDLINE_LINUX` (then `update-grub`, reboot) and `sudo sh -c 'echo 0 > /proc/sys/kernel/numa_balancing'`. Both change the host: ask first.
- `export SGLANG_USE_AITER=1` enables Aiter-accelerated kernels (needed for MXFP4 on CDNA3/CDNA4). FP8 works via Aiter or Triton; AWQ uses Triton dequant on AMD (no Marlin).
- Source build (v0.5.18 branch in the doc): compile `sgl-kernel` with `python setup_rocm.py install` in `python/sglang/kernels/aot`, swap `pyproject_other.toml` into place, `pip install -e "python[all_hip]"`. There are also `docker/rocm.Dockerfile` and `docker/rocm-gfx1151.Dockerfile`.

## NVIDIA Jetson Orin

Per upstream: JetPack 6.1+, high-performance mode (`sudo nvpmodel -m 0`), then jetson-containers:

```bash
git clone https://github.com/dusty-nv/jetson-containers.git && bash jetson-containers/install.sh
jetson-containers build sglang
jetson-containers run $(autotag sglang)
python -m sglang.launch_server --model-path deepseek-ai/DeepSeek-R1-Distill-Llama-8B \
  --device cuda --dtype half --attention-backend flashinfer --mem-fraction-static 0.8 --context-length 8192
```

## Apple Silicon (MLX)

Needs macOS 14+, stable PyTorch 2.13.x and MLX 0.32.0+. Source install from the default branch (as documented):

```bash
git clone https://github.com/sgl-project/sglang.git && cd sglang
uv venv -p 3.12 sglang-metal && source sglang-metal/bin/activate
rm -f python/pyproject.toml && mv python/pyproject_other.toml python/pyproject.toml
uv pip install -e "python[all_mps]"
SGLANG_USE_MLX=1 python -m sglang.launch_server --model <MODEL_ID_OR_PATH> --disable-cuda-graph --host 127.0.0.1
```

Without `SGLANG_USE_MLX=1` it falls back to `torch.mps` with less support. `mlx-community/*-4bit` repos load directly; `--quantization mlx_q4|mlx_q8` quantizes at load. Optional Metal kernel build needs full Xcode. For plain Mac inference see the `mlx` and `lm-studio` skills.

## Other hardware

Dedicated upstream pages exist for Intel Xeon CPU (`v0.5.21-xeon` tag), Intel XPU (`v0.5.21-xpu`), Google TPU, Ascend NPU (CANN images `main-cann*`), and Moore Threads GPUs. Not covered further here.

## From source

```bash
git clone -b v0.5.21 https://github.com/sgl-project/sglang.git && cd sglang
pip install --upgrade pip && pip install -e "python"
```

The upstream install page still shows an older branch in this example; use the tag you want. For development use the `lmsysorg/sglang:dev` image.

## Kubernetes, SkyPilot, SageMaker

- Upstream manifests: `docker/k8s-sglang-service.yaml` (single node, PVC + Deployment + Service) and `docker/k8s-sglang-distributed-sts.yaml` (two-node StatefulSet). Our adaptation: `templates/k8s-deployment.yaml`. For operators see OME (`sgl-project/ome`).
- SkyPilot: YAML with `image_id: docker:lmsysorg/sglang:latest` (pin a tag), `ports: 30000`, `sky launch -c sglang --env HF_TOKEN sglang.yaml`.
- SageMaker: build from `docker/sagemaker.Dockerfile` with the `serve` script; env vars prefixed `SM_SGLANG_` become flags (`SM_SGLANG_MODEL_PATH`, `SM_SGLANG_REASONING_PARSER=qwen3`); default port 8080.

## Verify the install

```bash
sglang version
python3 -c 'import sglang, torch; print(sglang.__version__, torch.__version__, torch.cuda.is_available())'
python3 -m sglang.launch_server --help | head -20
```
