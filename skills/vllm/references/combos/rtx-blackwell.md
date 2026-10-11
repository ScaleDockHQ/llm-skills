# RTX Blackwell (SM120) and GB10 (SM121) with NVFP4 and b12x

> Verified against vLLM v0.31.0 (`docs/features/quantization/b12x.md`, `docs/getting_started/installation/gpu.cuda.inc.md`), 2026-10-11

Not run on RTX hardware by this skill.

Applies to RTX 50-series, RTX PRO Blackwell workstation/server cards (SM120) and DGX Spark / GB10 (SM121,
see also `combos/dgx-spark-dual-ray.md`).

## Install

- CUDA 13 wheels are the default on PyPI in v0.31.0. Use `uv pip install vllm --torch-backend=auto` into a fresh
  venv, or the upstream `vllm/vllm-openai` image (multi-arch).
- On GB10 / aarch64 you can also use `nvcr.io/nvidia/vllm:<YY.MM>-py3` (see `references/install.md`).
- Optional SM120/SM121 kernels: `uv pip install "vllm[b12x]"`.

## b12x backends

```bash
vllm serve <nvfp4-or-mxfp4-model> --linear-backend b12x --moe-backend b12x
```

- The two flags are independent. Pass `--moe-backend b12x` only for a compatible NVFP4 or MXFP4 **MoE** model.
- Linear: per-tensor FP8, 128x128 block FP8, MXFP8, NVFP4, MXFP4. MoE: tensor-parallel MXFP4 (BF16 or MXFP8
  activations) and NVFP4 (BF16, NVFP4 or MXFP8 activations).
- Not supported by the b12x MoE backend: expert parallelism, expert maps, EXL3, NF3. Dense W4A16 layers use
  another backend such as Marlin.
- `VLLM_B12X_MOE_FP4_FORCE_A16=1` forces BF16 activations for FP4 weights (for debugging accuracy).
- b12x linear kernels take part in automatic selection after the established backends; read the
  `Selected <kernel> for <module>` startup lines to see what is used.
- b12x can also appear as an attention backend value in v0.31.0 (see `serve-config.md`); whether it helps for your model is unverified.

## Model and flag guidance

- Prefer NVFP4 (NVIDIA Model Optimizer) or FP8 checkpoints; `references/models-and-formats.md` lists formats.
- Consumer cards have no NVLink: TP across several RTX cards runs over PCIe, so prefer a single card or
  pipeline parallel when the model allows it. If NCCL hangs on multi-GPU PCIe, see
  `references/troubleshooting.md` (`NCCL_CUMEM_HOST_ENABLE=0`).
- If you see `no kernel image is available`, you probably have a build without SM120 kernels; use the CUDA 13
  wheel or newer image (unverified rule of thumb).
- Single-user decode speed: add speculative decoding (`combos/eagle3.md`).
- `--gpu-memory-utilization` on discrete cards can stay near the default 0.92 unless a desktop session uses the
  same GPU; leave headroom for the display. On GB10 (unified memory) lower it (0.7-0.8).

## Verify

`vllm collect-env`, then watch the startup log for the compute capability, selected attention backend and kernel
lines. Benchmark against the default backends before keeping b12x (`references/performance-tuning.md`).
