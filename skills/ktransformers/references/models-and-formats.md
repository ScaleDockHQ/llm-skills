# Models and formats

> Verified against KTransformers v0.7.1 (kt-kernel README, `Native-Precision-Tutorial.md`, `AVX2-Tutorial.md`, per-model tutorials under `doc/en`), 2026-10-11

## CPU backends (`--kt-method`) and what they need

| Method                  | CPU weights                                                   | CPU requirement                                                         | Notes                                      |
| ----------------------- | ------------------------------------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------ |
| `BF16`                  | The original BF16 checkpoint (native)                         | AVX512F + BW + BF16 (Cooper Lake+, Sapphire Rapids+, Zen 4+); AMX helps | Zero precision loss, largest RAM           |
| `FP8`, `FP8_PERCHANNEL` | The original FP8 checkpoint (block or per-channel scales)     | AVX512F + BW + BF16 + VBMI                                              | Half the RAM of BF16                       |
| `RAWINT4`               | Native INT4 checkpoint shared by CPU and GPU                  | AVX512F + BW (software fallback for VNNI/BF16); AVX2 variant exists     | Used by Kimi K2 Thinking and K2.5          |
| `AMXINT8`, `AMXINT4`    | Converted with `scripts/convert_cpu_weights.py` or `kt quant` | Intel AMX (Sapphire Rapids+)                                            | `AMXINT4` can hurt accuracy on some models |
| `LLAMAFILE`             | A GGUF folder (`Q4_K_M`, `Q4_K`, `Q5_K` ...), no conversion   | AVX2 (Haswell+, Zen+)                                                   | Universal fallback                         |
| `GPTQ_INT4`             | GPTQ INT4 checkpoint                                          | AVX2 tutorial lists it                                                  |                                            |
| `MOE_INT8`              | Converted `moe_int8`                                          | AMD CPUs with BLIS built (`CPUINFER_ENABLE_BLIS=ON`)                    | Faster INT8 prefill and decode on AMD      |

AVX2-only machines can run `BF16`, `FP8`, `GPTQ_INT4` and `RAWINT4`; the loader falls back to the AVX2 backend automatically
(`kt_kernel.__cpu_variant__` shows `avx2`). Expect much lower throughput than AMX.

Check your CPU: `lscpu | grep -o -E 'amx_[a-z0-9_]+|avx512[a-z_0-9]*|avx2' | sort -u`.

## Weights you need

- **GPU weights:** the normal Hugging Face model directory that SGLang loads (`--model`), original or already quantized for GPU.
- **CPU expert weights:** either the same native checkpoint (`BF16`, `FP8`, `RAWINT4`), a converted AMX directory, or a GGUF directory;
  point `--kt-weight-path` at it.

```bash
# Convert for AMX (CPU-heavy, needs RAM; see kt-kernel/scripts/README.md for the low-memory mode)
python scripts/convert_cpu_weights.py --input-path /models/Qwen3-30B-A3B --input-type bf16 \
  --output /models/Qwen3-30B-A3B-INT8 --quant-method int8      # int4, or moe_int8 for AMD
# Equivalent through the CLI
kt quant /models/Qwen3-30B-A3B --method int8 --input-type bf16 --output /models/Qwen3-30B-A3B-INT8
# GGUF for LLAMAFILE
huggingface-cli download Qwen/Qwen3-30B-A3B-GGUF Qwen3-30B-A3B-Q4_K_M.gguf --local-dir /models/Qwen3-30B-A3B-Q4_K_M
```

Supported conversion inputs: FP8, FP16, BF16 to INT4 or INT8. `huggingface-cli download` needs `HF_TOKEN` for gated repos; keep it in the
environment or a `0600` file.

## Models with upstream recipes (0.7.x)

| Model                                | `kt-method`                               | Notes from the tutorial                                                                                     |
| ------------------------------------ | ----------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| DeepSeek-V3, R1-0528, V3.2           | `FP8` (native); AMX INT4 variant for V3.2 | V3.2 INT4: about 350 GB RAM, 24+ GB VRAM, about 1 TB disk for FP8 plus INT4                                 |
| DeepSeek-V4-Flash                    | MXFP4 with the Docker image               | Validated on 1 RTX 5090 (SM_120), 4090 and 3090; at least 200 GB RAM, about 340 GB disk; AVX2 CPU is enough |
| Kimi-K2-Thinking, K2.5               | `RAWINT4`                                 | At least 650 GB RAM, 48 GB VRAM, about 600 GB disk                                                          |
| GLM-4.7                              | `FP8_PERCHANNEL`, `BF16`                  |                                                                                                             |
| GLM-5, 5.1, 5.2, 5.3-flash           | per tutorial                              | Tutorials in `doc/en/kt-kernel/`; 5.3-flash has 1M context and multimodal input                             |
| MiniMax-M2, M2.1, M2.5, M3           | `FP8`                                     | M2.1 needs 256 GB+ RAM                                                                                      |
| Qwen3-235B-A22B, Qwen3-30B-A3B       | `FP8`, `BF16`                             |                                                                                                             |
| Qwen3-Next-80B-A3B, Qwen3-Coder-Next | `FP8`, `BF16`                             | Coder-Next FP8: about 100 GB RAM, 1x RTX 4090                                                               |
| Qwen3.5 (about 400B MoE)             | `BF16`                                    | At least 800 GB RAM, 4x RTX 4090 (96 GB VRAM), about 800 GB disk                                            |

RAM and VRAM figures are upstream minimums for its tested configurations (for example 2x Xeon with 512 GB to 2 TB DDR5); your KV cache,
context length and OS need headroom. Always read the model's tutorial under `doc/en/kt-kernel/` or `doc/en/` first: model support changes
between releases.

## Hardware summary

- **CPU:** x86-64 with AVX2 minimum; AVX512 for native FP8/BF16/RAWINT4; AMX for the AMX methods. Memory bandwidth (many channels of DDR5) sets
  decode speed. Multi-socket servers need NUMA-aware pools.
- **GPU:** NVIDIA, compute capability 8.0+ (wheel covers 8.0, 8.6, 8.9, 9.0; DeepSeek-V4-Flash docs also validate SM_120). Upstream recommends PCIe 5.0
  for CPU-GPU transfer.
- **Disk:** the full checkpoint plus any converted copy.
