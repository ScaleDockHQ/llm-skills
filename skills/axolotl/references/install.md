# Installing Axolotl

> Verified against axolotl-ai-cloud/axolotl v0.20.0 (docs/installation.qmd, docs/docker.qmd on main), 2026-10-11

## What it is and requirements

[Axolotl](https://github.com/axolotl-ai-cloud/axolotl) (Apache-2.0, actively maintained: v0.20.0 released 2026-09-30, last push 2026-10-10) is a YAML-driven fine-tuning framework over Transformers, PEFT and TRL. PyPI `axolotl` 0.20.0 requires Python >= 3.12.

Upstream requirements: NVIDIA GPU (Ampere or newer for `bf16` and Flash Attention) or AMD GPU; Python >= 3.12; PyTorch >= 2.13.0 (2.13.0 recommended).

Blackwell (B100/B200/B300, RTX 50): use PyTorch >= 2.11.0 and CUDA 13.0. CUDA 12.8 cannot compile for `sm_103a` (B300); CUDA 13.0 also avoids first-launch JIT overhead on B100/B200/RTX 50.

## uv (recommended by upstream)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env
export UV_TORCH_BACKEND=cu130        # or cu128
uv venv && source .venv/bin/activate
uv pip install --no-build-isolation 'axolotl[deepspeed]'
axolotl --help
```

Extras seen in upstream docs: `deepspeed`, `vllm` (GRPO with vLLM generation; requires `vllm>=0.30.0`, which pins torch 2.13.0), `modal` and `baseten` (cloud launchers). Pin a release for reproducibility: `'axolotl[deepspeed]==0.20.0'`.

Edge build for unreleased features:

```bash
git clone https://github.com/axolotl-ai-cloud/axolotl.git && cd axolotl
uv venv && source .venv/bin/activate
uv pip install --no-build-isolation -e '.[deepspeed]'
```

Offline or air-gapped hosts: see upstream `docs/airgapped.qmd` (build a bundle on a connected host).

## Docker

```bash
docker run --gpus '"all"' --rm -it --ipc=host axolotlai/axolotl-uv:main-latest
```

With a bind-mounted workspace and the Hugging Face cache (token passed by name only):

```bash
docker run --gpus all --rm -it --ipc=host --shm-size 10g \
  --ulimit memlock=-1 --ulimit stack=67108864 \
  --mount type=bind,src="$PWD",target=/workspace/axolotl \
  -v ~/.cache/huggingface:/root/.cache/huggingface \
  -e HF_TOKEN \
  axolotlai/axolotl:main-latest
```

Images (all uv-based, Python 3.12, CUDA 13.0, PyTorch 2.13.0 for `main-latest`):

| Image                                              | Use                                                                                                                                                                   |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `axolotlai/axolotl` (alias `axolotlai/axolotl-uv`) | Main runtime                                                                                                                                                          |
| `axolotlai/axolotl-base` (alias `-base-uv`)        | Minimal base to build on                                                                                                                                              |
| `axolotlai/axolotl-cloud` (alias `-cloud-uv`)      | Cloud: sets `HF_HOME=/workspace/data/huggingface-cache`, runs Jupyter (disable with `JUPYTER_DISABLE=1`, password `JUPYTER_PASSWORD`, SSH key `PUBLIC_KEY`/`SSH_KEY`) |
| `axolotlai/axolotl-cloud-term`                     | Cloud image without tmux; no `-uv` alias                                                                                                                              |

Tag formats: `main-latest`; `main-py3.12-cu130-2.13.0`; `<version>` (e.g. `0.18.0`), `<version>-py3.12-cu130-2.13.0`, `<version>-latest`; dated `<branch>-YYYYMMDD-py...`. An extra `-vllm` suffix may appear on tags that include vLLM. Blackwell: `axolotlai/axolotl-uv:main-py3.12-cu130-2.13.0` or `axolotlai/axolotl-cloud-uv:main-py3.12-cu130-2.13.0`.

Pin a release tag in anything you want to reproduce; `main-latest` moves.

## arm64 and DGX Spark

Docker Hub's `axolotlai/axolotl:main-latest` manifest lists `linux/amd64` and `linux/arm64` (checked via the Docker Hub API, 2026-10-11). Upstream has no DGX Spark page. A native `uv pip install` on aarch64 with GB10 is **unverified**; prebuilt aarch64 wheels for flash-attn, bitsandbytes and deepspeed may be missing, so use the arm64 image first.

## Other platforms

macOS and AMD have their own upstream pages (`docs/mac.qmd`, `docs/amd_hpc.qmd`); not covered here. Cloud GPU providers named in upstream docs: RunPod, Vast.ai, PRIME Intellect, Modal, Novita, JarvisLabs, plus SkyPilot (`docs/skypilot.qmd`) for your own cloud accounts. Renting generally: skill `cloud-llms`.

## Verify

```bash
axolotl --help | head -5
python -c 'import torch; print(torch.__version__, torch.cuda.is_available())'
axolotl fetch examples            # writes examples/ locally
```
