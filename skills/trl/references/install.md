# Installing TRL

> Verified against huggingface/trl v1.15.0 and huggingface/peft v0.21.2, 2026-10-11

## What it is and status

[TRL](https://github.com/huggingface/trl) (Apache-2.0) is Hugging Face's post-training library. Actively maintained: v1.15.0 released 2026-10-08 (v1.14.2 on 2026-10-06), last push 2026-10-11. PyPI `trl` 1.15.0 requires Python >= 3.11. Core dependencies at v1.15.0: `accelerate>=1.4.0`, `datasets>=4.7.0`, `transformers>=4.56.2`. PEFT latest is 0.21.2.

## Install

```bash
uv venv && source .venv/bin/activate
uv pip install trl peft            # or: pip install trl peft
uv pip install bitsandbytes        # QLoRA (4/8-bit)
uv pip install 'trl[vllm]'         # vLLM generation for GRPO / RLOO / online DPO
trl env                            # versions of trl, transformers, torch, accelerate, ...
```

Source install: `git clone https://github.com/huggingface/trl.git && cd trl && pip install -e .` (dev extras: `pip install -e ".[dev]"`).

Extras defined in `pyproject.toml` at v1.15.0 include `vllm` (`vllm>=0.21.0,<=0.31.0`), `peft`, `bitsandbytes`, `liger` (`liger-kernel>=0.8.2`) and kernels-hub extras. Check the `[project.optional-dependencies]` table for the full list.

## vLLM compatibility

TRL supports vLLM versions 0.21.0 to 0.31.0 only (docs warning). vLLM v0.31.0 is the latest vLLM release on 2026-10-11, so a plain `pip install vllm` today lands on the edge of that range; pin `vllm<=0.31.0` and recheck when vLLM publishes 0.32. Install `vllm` in the same environment for colocate mode; for server mode it can live in a separate environment (skill `vllm`).

## CUDA, arm64 and DGX Spark

Any platform with a CUDA PyTorch wheel works. On DGX Spark (GB10, aarch64) NVIDIA's PyTorch container `nvcr.io/nvidia/pytorch` is a common base; whether wheels for optional extras (bitsandbytes, vllm, flash-attn) exist for aarch64 at each version is **unverified**. Vendor containers (for example Unsloth's DGX Spark Dockerfile) pin an old TRL (`trl==0.22.2` on 2026-10-11) that does not match current docs.

## Verify

```bash
trl env
python -c 'import trl, peft, transformers, torch; print(trl.__version__, peft.__version__, transformers.__version__, torch.cuda.is_available())'
trl sft --help | head -20
```

Paste `trl env` output first in any bug report (no tokens in it).
