# MiniMax platforms and quants

> Verified against vLLM M3 recipe, SGLang M3 cookbook, TensorRT-LLM M3 guide, NVIDIA model cards (M3 and M2.7 NVFP4), NVIDIA DGX Spark forum thread, Unsloth guides, MLX Community model cards, 2026-10-11

Memory must cover weights plus KV cache. Sizes are in `models.md`. Throughput numbers below are third-party
reports, not baselines: measure your own.

## Quick matrix

| Platform                        | Memory         | M3 (428B / 23B active)                                                                                                | M2.7 (230B / 10B active)                                                                                          |
| ------------------------------- | -------------- | --------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| NVIDIA DGX Spark GB10, one node | 128 GB unified | Does not fit (smallest GGUF `UD-IQ1_M` is 128 GB, Unsloth asks for 133 GB total)                                      | GGUF `UD-IQ4_XS` 108 GB fits; NVFP4 does not (130 to 140 GB)                                                      |
| Two DGX Sparks (ConnectX-7)     | 256 GB         | No tested path found (NVFP4 is 257 GB)                                                                                | NVFP4 with vLLM TP=2 over Ray (community recipe)                                                                  |
| Consumer RTX (16 to 32 GB)      | VRAM + RAM     | Only by heavy CPU offload of GGUF, impractical                                                                        | GGUF with offload: Unsloth cites 25+ tok/s for `UD-IQ4_XS` on 1x16 GB GPU plus 96 GB RAM                          |
| Apple Silicon                   | unified        | No M3 MLX or tested GGUF path found                                                                                   | `mlx-community/MiniMax-M2.7-4bit` (128.67 GB, ~157 GB needed): Mac with 192 GB or more; 3-bit or MXFP4 for 128 GB |
| 8x H100 80 GB (640 GB)          |                | vLLM recipe lists H100; BF16 (1025 GB sizing) cannot fit; MXFP8 (513 GB) is Blackwell-oriented in SGLang. Unverified. | FP8 checkpoint (~230 GB) on 4 or 8 GPUs                                                                           |
| 8x H200 141 GB                  | 1128 GB        | BF16, TP8 (verified by vLLM and SGLang)                                                                               | FP8                                                                                                               |
| 8x B200 180 GB and larger       |                | MXFP8 or NVFP4                                                                                                        | FP8, NVFP4                                                                                                        |
| AMD MI300X to MI355X            |                | vLLM and SGLang recipes (BF16, MXFP8, MXFP4 on MI355X)                                                                | not checked                                                                                                       |

## NVIDIA DGX Spark (GB10, 128 GB unified, 221 GB/s)

- **M2.7 on one Spark:** use llama.cpp with the Unsloth `UD-IQ4_XS` GGUF (108 GB). That leaves under 20 GB for KV
  cache, OS and other services, so cap `--ctx-size` and run it in an exclusive model group (`self-hosted-llms`).
  Avoid CUDA 13.2. Speed on GB10 not verified.
- **M2.7 on two Sparks:** `nvidia/MiniMax-M2.7-NVFP4` (ModelOpt) with vLLM tensor parallel 2 and Ray over the
  200 GbE link. Forum reports about 25 tok/s generation. Reported flags: `--quantization modelopt_fp4`,
  `--kv-cache-dtype fp8`, `--attention-backend flashinfer`, `--load-format fastsafetensors`,
  `VLLM_NVFP4_GEMM_BACKEND=flashinfer-cutlass`, `--tool-call-parser minimax_m2`,
  `--reasoning-parser minimax_m2_append_think`, `--max-num-seqs` 5 to 8, `--max-model-len` up to ~196K.
  Community checkpoints (`saricles/MiniMax-M2.7-NVFP4-GB10`, `lukealonso/MiniMax-M2.7-NVFP4`, AWQ) exist; the
  forum reports NVIDIA's own NVFP4 is the more stable on strict tool-call sequences. The recipe containers belong
  to their authors: credit them, do not copy them.
- **M3:** no single- or dual-Spark path found. Not qualified.
- **TensorFold:** no MiniMax entry in v1.0.7. Not qualified.

## Consumer RTX

No M2 or M3 checkpoint fits in VRAM. Only llama.cpp CPU+GPU offload makes sense, with at least the GGUF size in
combined RAM+VRAM (Unsloth: total memory should exceed the file size). Use the `local-llms` skill for the
runtime. For a model that fits a single card, choose another family.

## Apple Silicon

- MLX: `mlx-community/MiniMax-M2.7-4bit` (4-bit weights, 8-bit router layers, text only, converted with mlx-lm
  0.31.2) and `...-4bit-mxfp4`. The catalog lists 128.67 GB and ~157 GB of unified memory.
- Third-party sizing (Silicon Score, citing MiniMax's MLX guide): 3-bit about 100 GB model / 112 GB memory;
  4-bit MXFP4 about 122 GB / 136 GB (tight on 128 GB, short context); 6-bit suited to 256 GB.
  An oMLX report shows a 4-bit M2.7 variant on an M5 Max 128 GB at roughly 55 tok/s generation, ~87 GB peak at 1K context.
- GGUF via llama.cpp (Metal) works the same as on Linux. Leave 10 to 20 GB for macOS.
- M3 on MLX: not checked.

## Datacenter Hopper and Blackwell

- **M3 BF16:** 8x H200, `--tensor-parallel-size 8 --block-size 128`. For long context use multi-node TP or
  `--kv-cache-dtype fp8`; cap `--max-model-len` for fewer GPUs.
- **M3 MXFP8:** native tensor cores on Blackwell (B200/B300, GB200/GB300) and AMD MI350X/MI355X. SGLang validated
  single-node B200 at TP8 and B300/GB300 at TP4. TensorRT-LLM supports BF16 and MXFP8 (dequantized on load).
- **M3 NVFP4:** `nvidia/MiniMax-M3-NVFP4`, vLLM TP8 on B200 with optional EAGLE3 draft head
  (`Inferact/MiniMax-M3-EAGLE3-GQA`, 3 tokens). TensorRT-LLM does not serve NVFP4 for M3.
- **M3 prefill/decode disaggregation:** SGLang validated 2x4 B200 (MXFP8, NIXL) and 2x8 H200 (BF16, mooncake) with
  equal TP, PP=1, RDMA.
- **M2.7:** FP8 on 4x96 GB (400K total KV tokens) or 8x144 GB; NVFP4 is NVIDIA-produced for Blackwell.
- **Hopper note:** MSA kernels (`fmha_sm100`) are Blackwell-only; Hopper uses the Triton sparse path (SGLang)
  with FlashAttention-3.

## Choosing a quant

1. Output quality first: BF16/FP8 for M3 and M2.7 when memory allows.
2. Memory-bound Blackwell: MXFP8 (half of BF16) or NVFP4 (about a quarter).
3. Memory-bound GGUF: Unsloth Dynamic quants. Their M2.5 KLD benchmarks favor `UD-Q4_K_XL` for quality/size;
   `UD-IQ4_XS` for fitting 128 GB. Treat third-party accuracy numbers as indicative. Use `model-quantization` for details.
4. Do not mix GGUF with MSA expectations: llama.cpp M3 support is newer than its docs (see `parsers-and-templates.md`).

## Sources

- https://recipes.vllm.ai/MiniMaxAI/MiniMax-M3
- https://docs.sglang.io/cookbook/autoregressive/MiniMax/MiniMax-M3
- https://nvidia.github.io/TensorRT-LLM/latest/deployment-guide/deployment-guide-for-minimax-m3-on-trtllm.html
- https://huggingface.co/nvidia/MiniMax-M3-NVFP4
- https://huggingface.co/nvidia/MiniMax-M2.7-NVFP4
- https://huggingface.co/saricles/MiniMax-M2.7-NVFP4-GB10
- https://forums.developer.nvidia.com/t/minimax-m2-7-nfvp4-recipe-benchmarks/366324
- https://unsloth.ai/docs/models/minimax-m27
- https://unsloth.ai/docs/models/minimax-m3
- https://huggingface.co/mlx-community/MiniMax-M2.7-4bit
- https://siliconscore.com/models/minimax-m2-7/
- https://github.com/ashhart/TensorFold
