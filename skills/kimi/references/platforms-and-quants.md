# Kimi: platforms, quants and sizing

> Verified against vLLM recipes (Kimi-K3, Kimi-K2.6), vLLM K3 blog, SGLang Kimi-K3 cookbook, TensorRT-LLM K3 deployment guide, NVIDIA NVFP4 model cards (Kimi-K2.6, K2.7-Code, K3), Unsloth Kimi K3/K2.6/K2.7-Code pages and GGUF repos, mlx-community and community MLX cards, Hugging Face file listings (Kimi-Linear GGUF, Kimi-VL GGUF), 2026-10-11

## Reality check by platform

Only the small models fit one box. The Kimi flagships are multi-hundred-GB checkpoints.

| Platform                               | What fits                                                                                                                                                 | What does not                                                                                                                                  |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| NVIDIA DGX Spark GB10 (128 GB unified) | Kimi-Linear-48B-A3B (GGUF `Q4_K_M` is 30 GB, `Q8_0` is about 52 GB), Kimi-VL-A3B-Thinking-2506 (GGUF `Q4_K_M` 10.5 GB, `Q8_0` 16.9 GB plus mmproj 0.6 GB) | K2.x (smallest Unsloth GGUF 325-350 GB) and K3 (smallest 594 GB). Two Sparks (256 GB) still do not fit them                                    |
| Consumer RTX (24-32 GB VRAM)           | Kimi-VL GGUF; Kimi-Linear `Q4_K_M` (30 GB) only with CPU offload or 32 GB VRAM                                                                            | K2.x and K3: Unsloth says the smallest K2.6 needs 350 GB+ RAM/VRAM; ModelFit's measured estimate for K2.6 `UD-Q2_K_XL` is 410 GB at 8K context |
| Apple Silicon                          | Kimi-Linear: `mlx-community/Kimi-Linear-48B-A3B-Instruct-4bit` (about 27.6 GB of files) and 6/8-bit variants; Kimi-VL MLX 4/8-bit exist                   | K2.x needs a 512 GB Mac Studio (see below); K3 does not fit a single 512 GB Mac                                                                |
| Datacenter H100/H200 (80/141 GB)       | K2.x INT4: 8x H200 verified (vLLM recipe, about 640 GB aggregate VRAM); K3 on SGLang cookbook recipes H200 2x8, H100 4x8 (Marlin + FlashMLA)              |                                                                                                                                                |
| Datacenter B200/B300/GB200/GB300       | K2.x NVFP4: 4x B300 verified (vLLM recipe). K3: vLLM says at least one 8x B300 node (or GB300 NVL72); 16x B200 also supported                             | K3 on 8x B200 (TensorRT-LLM: TEP8 does not fit its BF16 non-expert weights)                                                                    |
| AMD MI300X to MI355X                   | K2.6 on 8x MI300X/MI325X/MI355X with ROCm 7.2.1 (vLLM recipe); K3 on 8x MI355X (vLLM) and MI35x 1x8 (SGLang)                                              |                                                                                                                                                |

## Official and ecosystem quants

| Model       | Formats that exist (source)                                                                                                                                                                                                                                                                                         |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| K3          | Official MXFP4/MXFP8 (QAT, 1.56 TB, `moonshotai/Kimi-K3`); NVIDIA `nvidia/Kimi-K3-NVFP4` (MXFP4 experts converted to NVFP4, attention FP8, vLLM and SGLang); Unsloth `unsloth/Kimi-K3-GGUF`; community MLX port https://github.com/PipeNetwork/kimi-k3-mlx (not upstream; a bit-exact `mxfp4` tier, per its README) |
| K2.7-Code   | Official INT4; `nvidia/Kimi-K2.7-Code-NVFP4` (vLLM, Blackwell, TP 4); `unsloth/Kimi-K2.7-Code-GGUF`; community MLX (`mlx-community/Kimi-K2.7-Code-4bit`, `spicyneuron/Kimi-K2.7-Code-MLX-3.6bit`, a vision-keeping `avlp12/...-MLX-Dynamic-3.6bpw-VLM`)                                                             |
| K2.6        | Official INT4 (about 595 GB on disk); `nvidia/Kimi-K2.6-NVFP4` (modelopt 0.44.0, `--tensor-parallel-size 4`); `RedHatAI/Kimi-K2.6-NVFP4` (seen in a vLLM issue); `unsloth/Kimi-K2.6-GGUF`                                                                                                                           |
| K2.5        | `nvidia/Kimi-K2.5-NVFP4` (used in the SGLang cookbook B200 recipe)                                                                                                                                                                                                                                                  |
| K2-Thinking | Official INT4 (QAT); `nvidia/Kimi-K2-Thinking-NVFP4` (TensorRT-LLM Blackwell guide)                                                                                                                                                                                                                                 |
| Kimi-Linear | GGUF (bartowski, ymcki, others), MLX 4/6/8-bit (mlx-community), AWQ and FP8-dynamic community quants; none official                                                                                                                                                                                                 |
| Kimi-VL     | `ggml-org/Kimi-VL-A3B-Thinking-2506-GGUF` (with mmproj), mlx-community 4/8-bit                                                                                                                                                                                                                                      |

### Unsloth GGUF sizes

| Model     | Quant        | Size                    | Notes                                                                                                   |
| --------- | ------------ | ----------------------- | ------------------------------------------------------------------------------------------------------- |
| K3        | `UD-IQ1_S`   | 594 GB                  | Unsloth recommended starting point; needs about 610 GB RAM+VRAM; mean KLD 0.5645, top-1 agreement 78.9% |
| K3        | `UD-IQ1_M`   | 648.9 GB                | top-1 agreement 81.2%                                                                                   |
| K3        | `UD-IQ2_XXS` | 711.1 GB                | top-1 agreement 84.1%                                                                                   |
| K3        | `UD-Q2_K_XL` | 861.3 GB                | top-1 agreement 90.4%                                                                                   |
| K3        | `UD-Q4_K_XL` | 1,510 GB                | near full precision                                                                                     |
| K3        | `UD-Q8_K_XL` | 1,560 GB                | lossless versus the MXFP4 original (experts MXFP4, rest BF16)                                           |
| K2.6      | `UD-Q2_K_XL` | 340.5 GB                | about 410 GB total memory at 8K context (ModelFit estimate)                                             |
| K2.6      | `UD-Q4_K_XL` | 583.7 GB                |                                                                                                         |
| K2.6      | `UD-Q8_K_XL` | 594.5 GB                | lossless (INT4 experts kept)                                                                            |
| K2.7-Code | `UD-Q2_K_XL` | about 345 GB RAM needed | `UD-Q8_K_XL` lossless; Unsloth says full precision is 605 GB                                            |

Unsloth's rule of thumb: RAM + VRAM about equals the quant size; below that it still runs but is much slower from disk offload. Unsloth reports roughly 20 tokens/s when K3 fits on B200s. Quality numbers (KLD, PPL) are Unsloth's own; they warn that some third-party K3 quants of similar size degrade far more.

## Format advice

- **Datacenter Blackwell:** serve the official K3 checkpoint (already MXFP4) or `nvidia/Kimi-K3-NVFP4` through vLLM/SGLang; for K2.x serve `nvidia/Kimi-K2.6-NVFP4` or K2.7-Code NVFP4 with `--kv-cache-dtype fp8`. NVIDIA's K3 NVFP4 was produced without calibration data (card statement); re-run your evals.
- **Hopper (H100/H200):** no FP4 tensor cores. K2.x official INT4 runs on 8x H200 in vLLM; K3 runs on Hopper in the SGLang cookbook (Marlin MoE plus FlashMLA decode), with H100 leaving the least headroom (80 GB). Cookbook marks all cells except two B300 1x8 ones as "Final Verification In Progress"; measure accuracy yourself.
- **CPU-heavy or mixed memory:** Unsloth GGUF through llama.cpp. Use the model's recommended sampling (`--temp 1.0 --top-p 0.95`) and the vision `--mmproj` file if you need images.
- **Apple Silicon:** MLX through `mlx_lm.server` for K2.7-Code (community 3.6-bit uses about 460 GB peak and reports 21 tok/s generation on an M3 Ultra), Kimi-Linear 4-bit for smaller Macs. Community vision builds need `mlx-vlm >= 0.6.3` plus `tiktoken` and `blobfile`.
- **Do not requantize K3 MXFP4 to affine 4-bit** if you can avoid it: the MLX port's README measured 9.8% mean relative error for that path versus a bit-exact `mxfp4` reinterpretation (single-source claim).

## KV cache and memory levers

- vLLM K3: `--kv-cache-dtype fp8`, `--max-model-len` (recipe uses 1048576), `--gpu-memory-utilization 0.95` in the recipe (0.9 in the blog), `VLLM_PREFIX_CACHE_RETENTION_INTERVAL` for KDA checkpoint spacing (0 keeps only prompt-end states).
- SGLang K3: the KDA state pool is the concurrency ceiling; `--mamba-full-memory-ratio` splits memory between it and the MLA KV pool. Use `--kv-cache-dtype fp8_e4m3` for long context and `--context-length` to bound requests.
- K2.x SGLang cookbook: `--context-length 128000` to conserve memory, `--kv-cache-dtype fp8_e4m3`.
- vLLM K2.6 recipe tunables: `--max-num-batched-tokens 8192`, `--max-num-seqs 256`, `--decode-context-parallel-size 8` (MLA), CPU KV offload with `SimpleCPUOffloadConnector`.

## Sources

- https://recipes.vllm.ai/moonshotai/Kimi-K3 , https://recipes.vllm.ai/moonshotai/Kimi-K2.6
- https://docs.sglang.io/cookbook/autoregressive/Moonshotai/Kimi-K3
- https://nvidia.github.io/TensorRT-LLM/deployment-guide/deployment-guide-for-kimi-k3-on-trtllm.html
- https://huggingface.co/nvidia/Kimi-K3-NVFP4 , https://huggingface.co/nvidia/Kimi-K2.6-NVFP4 , https://huggingface.co/nvidia/Kimi-K2.7-Code-NVFP4
- https://unsloth.ai/docs/models/kimi-k3 , https://unsloth.ai/docs/models/kimi-k2.6 , https://unsloth.ai/docs/models/kimi-k2.7-code , https://huggingface.co/unsloth/Kimi-K2.6-GGUF
- https://modelfit-eight.vercel.app/unsloth-kimi-k2-6-gguf/ (third-party sizing estimate)
- https://github.com/PipeNetwork/kimi-k3-mlx , https://huggingface.co/spicyneuron/Kimi-K2.7-Code-MLX-3.6bit , https://huggingface.co/mlx-community/Kimi-K2.7-Code-4bit , https://huggingface.co/avlp12/Kimi-K2.7-Code-Alis-MLX-Dynamic-3.6bpw-VLM
- https://huggingface.co/bartowski/moonshotai_Kimi-Linear-48B-A3B-Instruct-GGUF , https://huggingface.co/mlx-community/Kimi-Linear-48B-A3B-Instruct-4bit , https://huggingface.co/ggml-org/Kimi-VL-A3B-Thinking-2506-GGUF
