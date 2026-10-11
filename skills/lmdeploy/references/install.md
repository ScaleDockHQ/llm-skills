# Install

> Verified against LMDeploy v0.18.0 (docs `get_started/installation.md`, README, Docker Hub tags), 2026-10-11

## Pick a path

| Situation                         | Path                                                                                                  |
| --------------------------------- | ----------------------------------------------------------------------------------------------------- |
| NVIDIA GPU, sm70 or newer, Linux  | `pip install lmdeploy` in a Python 3.10-3.13 env (upstream recommends conda)                          |
| Reproducible or server deployment | Docker image `openmmlab/lmdeploy:v0.18.0-cu12.8` or `v0.18.0-cu13.0`                                  |
| Windows                           | Upstream lists Windows as supported for the pip install; use WSL2 or Docker if in doubt               |
| AMD GPU                           | ROCm: build from source inside a `rocm/pytorch` container (below)                                     |
| Ascend, Cambricon, MetaX          | Source build with `LMDEPLOY_TARGET_DEVICE`; docs under `docs/en/get_started/{ascend,camb,maca}`       |
| Need an unreleased fix            | `pip install git+https://github.com/InternLM/lmdeploy.git` (needs CUDA toolkit, C++20, CMake 3.25.2+) |

Supported NVIDIA architectures (installation doc): Volta sm70 (V100), Turing sm75 (20 series, T4), Ampere sm80/sm86,
Ada sm89. Quantization docs additionally list Hopper sm90 for KV and FP8 paths. Blackwell: the README states the
default PyPI wheels are built against CUDA 12.8 and that this covers typical setups including GeForce RTX 50 series
(since v0.13.0). Datacenter Blackwell and DGX Spark are not mentioned in the docs read: treat as unverified and test.

## pip

```bash
python3 -m venv ~/venvs/lmdeploy && . ~/venvs/lmdeploy/bin/activate   # Python 3.10-3.13
pip install lmdeploy==0.18.0
lmdeploy check_env            # prints versions and GPUs; review before sharing
```

`pip install lmdeploy[all]` pulls extras such as those the quantization docs use. Models download from Hugging Face
by default. For ModelScope install `modelscope` and set `LMDEPLOY_USE_MODELSCOPE=True`; for openMind Hub install
`openmind_hub` and set `LMDEPLOY_USE_OPENMIND_HUB=True`.

## Docker

Image tags on Docker Hub (`openmmlab/lmdeploy`) at the writing date: `v0.18.0-cu12.8`, `v0.18.0-cu13.0`,
`latest`, `latest-cu12.8`, `latest-cu13.0`, `ascend`, and `nightly-*`. Pin the versioned form.

```bash
docker run --rm --runtime nvidia --gpus all --ipc=host \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" -e HF_TOKEN \
  -p 127.0.0.1:23333:23333 \
  openmmlab/lmdeploy:v0.18.0-cu12.8 \
  lmdeploy serve api_server Qwen/Qwen3-8B --server-name 0.0.0.0 --model-name qwen
```

Inside the container `--server-name 0.0.0.0` is needed so the published port works; the `127.0.0.1:` prefix on `-p`
keeps it loopback on the host. Upstream's example omits `-e HF_TOKEN=` hygiene: forward the variable with
`-e HF_TOKEN` and never put the value on the command line. The image sets `TRITON_PTXAS_PATH=/usr/local/cuda/bin/ptxas`
(Dockerfile) and uses a Python 3.12 environment at `/opt/py3`.

## ROCm

```bash
docker run -it --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
  --device=/dev/kfd --device=/dev/dri --group-add video --ipc=host --network=host \
  --shm-size 32G -v "$HOME":/workspace rocm/pytorch:latest
# inside the container:
LMDEPLOY_TARGET_DEVICE=rocm pip install git+https://github.com/InternLM/lmdeploy.git
```

Mounting your whole home, as upstream does with `/root`, is broad: mount only the model and work directories.

## From source

TurboMind builds by default with CUDA. `DISABLE_TURBOMIND=1 pip install git+https://github.com/InternLM/lmdeploy.git`
skips it (PyTorch engine only). Pin a tag with
`pip install https://github.com/InternLM/lmdeploy/archive/refs/tags/v0.18.0.zip`.

## Offline and air-gapped

Download the model first (`hf download <repo> --local-dir <dir>`) and pass the directory as `model_path`. Mirror the
wheel set with `pip download lmdeploy==0.18.0` on a connected machine. Not covered upstream: validate on a test host.

## Verify

```bash
lmdeploy --version 2>/dev/null; python3 -c 'import lmdeploy; print(lmdeploy.__version__)'
lmdeploy serve api_server -h | head -20
```
