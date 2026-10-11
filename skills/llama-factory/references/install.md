# Installing LLaMA-Factory

> Verified against LLaMA-Factory v0.9.5, 2026-10-11

## What it is and status

[LLaMA-Factory](https://github.com/hiyouga/LLaMA-Factory) (Apache-2.0) is actively maintained: latest release v0.9.5 (2026-05-30), `main` is at `0.9.6.dev0` and had commits on 2026-10-10. PyPI `llamafactory` 0.9.5 requires Python >= 3.11. The commands are `llamafactory-cli` and the shortcut `lmf`.

## Install from source (upstream-recommended)

```bash
git clone --depth 1 https://github.com/hiyouga/LlamaFactory.git
cd LlamaFactory
uv venv && source .venv/bin/activate     # uv is shown in the README; plain venv works too
uv pip install -e .
uv pip install -r requirements/metrics.txt
uv pip install -r requirements/deepspeed.txt   # only for DeepSpeed runs
llamafactory-cli version && llamafactory-cli env
```

Upstream says installation is mandatory (a checkout, so `data/`, `examples/` and `dataset_info.json` exist). Optional dependency sets are `metrics` and `deepspeed`; extra requirements for specific features live in `examples/requirements/`. Install a CUDA PyTorch wheel first if your platform needs a specific index.

## Pinned ranges at v0.9.5 (and `main`)

`pyproject.toml` pins: `torch>=2.4.0`, `transformers>=4.55.0,<=5.6.0` at v0.9.5 (`<=5.8.0` on `main`), `accelerate>=1.3.0,<=1.11.0`, `peft>=0.18.0,<=0.18.1`, `trl>=0.18.0,<=0.24.0`, `datasets<=4.0.0`, `gradio<=5.50.0`. `requirements/deepspeed.txt` pins `deepspeed>=0.10.0,<=0.18.4`.

Consequence on 2026-10-11: PEFT 0.21.2 and DeepSpeed 0.19.7 are newer than these ranges. Do not `pip install -U peft deepspeed` into a LLaMA-Factory environment; keep the versions the checkout resolves. To try newer ones, use a separate environment and expect breakage. See `references/updating.md`.

The README's own requirements table (python 3.11+, torch 2.6.0 recommended, deepspeed 0.16.4 recommended, vllm 0.8.2 recommended) is older than `pyproject.toml`; treat `pyproject.toml` as authoritative for pins.

## Docker

```bash
docker run -it --rm --gpus=all --ipc=host hiyouga/llamafactory:latest
```

The README describes this image as Ubuntu 22.04 (x86_64), CUDA 12.4, Python 3.11, PyTorch 2.6.0, Flash-attn 2.7.4. Tags are at https://hub.docker.com/r/hiyouga/llamafactory/tags; `latest` was pushed 2026-10-10 and NPU images use tags such as `latest-npu-a2`. Pin a tag, not `latest`, for reproducibility. Compose files live in `docker/docker-cuda/`, `docker/docker-npu/` and `docker/docker-rocm/` (`docker compose up -d`, then `docker compose exec llamafactory bash`).

Mount a volume for `/root/.cache/huggingface` and your output folder so training results survive `--rm`.

## Other platforms

- **Windows:** install a CUDA PyTorch build first (README uses the `cu126` index); QLoRA needs a pre-built Windows `bitsandbytes` wheel per the README.
- **Ascend NPU:** `pip install -r requirements/npu.txt` plus CANN toolkit; NPU Docker images exist.
- **ROCm:** compose file `docker/docker-rocm/`.
- **arm64 / DGX Spark:** not covered by upstream docs read for this skill (unverified).

## Hugging Face login

Some datasets need acceptance. The README suggests `pip install "huggingface_hub<1.0.0"` then `huggingface-cli login`. Provide the token through `HF_TOKEN` rather than typing it into history. `USE_MODELSCOPE_HUB=1` switches model and dataset downloads to ModelScope; `USE_OPENMIND_HUB=1` to Modelers.

## Verify

```bash
llamafactory-cli version
llamafactory-cli env
python -c 'import torch; print(torch.cuda.is_available())'
llamafactory-cli help
```

Paste `llamafactory-cli env` output first in any bug report (no tokens in it).
