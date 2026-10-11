# Installing verl

> Verified against verl-project/verl v0.9.1 (docs/start/install.rst, docker/README.md, pyproject.toml), 2026-10-11

The repo moved from `volcengine/verl` to `verl-project/verl`; GitHub redirects the old URL.

## Requirements (docs)

- Python >= 3.10 (`pyproject.toml`: `>=3.10,<3.13`); the uv workflow targets Linux, Python 3.12, x86_64 and aarch64.
- CUDA >= 12.8 per the install page; the committed `uv.lock` is CUDA 13.0 / torch 2.11.
- Training backends: FSDP/FSDP2 (recommended for research and prototyping), Megatron-LM (for scale; core_v0.18.0 with megatron-bridge 0.5.2 in the lock).
- Rollout: vLLM (lock pins `vllm==0.24.0`; docs say vLLM >= 0.18.0, older is unusable), SGLang (lock pins `sglang==0.5.12`), TGI for single-GPU debugging.

## Option 1: uv (no install step)

Run from the repo root. `uv run` builds `.venv` from `uv.lock` on first use.

```bash
git clone https://github.com/verl-project/verl.git && cd verl
git checkout v0.9.1                 # pin a tag, not main
UV_RUN="uv run --frozen --all-packages --extra vllm --extra fsdp"
$UV_RUN python3 -c 'import verl, torch; print(verl.__version__, torch.cuda.is_available())'
bash examples/grpo_trainer/run_qwen3_8b_fsdp.sh     # scripts carry the uv wiring
INFER_BACKEND=sglang bash examples/grpo_trainer/run_qwen3_8b_fsdp.sh
```

- Extras: inference `vllm` or `sglang` (mutually exclusive); training `fsdp` or `megatron`; `cpu` stands alone. `python manage_envs.py list` prints extras, conflicts and the `.venv` state.
- Keep extras identical across the commands of one job: `uv run` syncs `.venv` to exactly the extras given, so alternating combinations reinstalls torch.
- Ray workers must use the same env: pass `ray_kwargs.ray_init.runtime_env.py_executable="$UV_RUN"` (the example scripts set it). If a launcher changes the working directory before `ray.init()`, use an absolute interpreter path such as `/abs/path/verl/.venv/bin/python3`.
- `VERL_USE_UV=0` makes the example scripts use the ambient interpreter instead.
- uv never compiles apex, transformer-engine or flash-attn: prebuilt wheels come from the verl wheelhouse index (cu130 / torch 2.11 / CPython 3.12).

## Option 2: Docker

Since v0.6.0 images are built on the vLLM and SGLang release images and add flash_attn, Megatron-LM, Apex, TransformerEngine and DeepEP.

```bash
# uv image: bakes the package cache, picks extras at run time
DOCKER_BUILDKIT=1 docker build -f docker/Dockerfile.uv.cu130 -t verl:uv-cu130 .
docker run --rm -it --gpus all verl:uv-cu130 bash

# prebuilt images on Docker Hub (list tags first; do not guess)
curl -s 'https://hub.docker.com/v2/repositories/verlai/verl/tags?page_size=50&ordering=last_updated' | jq -r '.results[].name'
docker create --runtime=nvidia --gpus all --net=host --shm-size="10g" --cap-add=SYS_ADMIN \
  -v .:/workspace/verl --name verl <image:tag> sleep infinity
docker start verl && docker exec -it verl bash
```

Inside a prebuilt image the dependencies are already installed: `pip install --no-deps -e .` for verl itself and launch with the ambient `python3` (`VERL_USE_UV=0` for the `examples/` scripts). The docs name tags like `verlai/verl:vllm024.latest` and `verlai/verl:sgl0512.latest`; verify they exist on Docker Hub before relying on them. Dockerfiles: `docker/Dockerfile.stable.vllm`, `Dockerfile.stable.sglang`, `Dockerfile.stable.trtllm`, `docker/rocm/`, `docker/ascend/`.

## Other backends

Ascend NPU, AMD ROCm and TensorRT-LLM are outside the uv workflow; use their dedicated Dockerfiles. aarch64 GPUs (GH200/GB200) are inside it: build `Dockerfile.uv.cu130` on an arm64 host.

## Blackwell / GB200

The GRPO example script gates `MACHINE=gb200` overrides: `rollout.enforce_eager=True`, `rollout.free_cache_engine=True`, FSDP `model_dtype=bfloat16`, `+ray_kwargs.ray_init.num_gpus=<n>` and, for SGLang, `attention_backend=flashinfer`.

## Discovery

```bash
gh api repos/verl-project/verl/releases/latest --jq '.tag_name,.published_at'
uv run --frozen --all-packages --extra vllm --extra fsdp uv pip list | grep -Ei 'verl|torch|vllm|sglang|ray|transformers'
```
