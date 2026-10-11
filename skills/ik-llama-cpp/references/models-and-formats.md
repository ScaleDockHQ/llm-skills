# Models and quant formats in ik_llama.cpp

> Verified against ik_llama.cpp main (89bba35c), README and docs/parameters.md, 2026-10-11

ik_llama.cpp loads GGUF files. It adds quant types that mainline llama.cpp does not have, so the file and the engine must match.

## Quant families (from the README)

| Family             | Types                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------- |
| IQK quants         | `IQ2_K`, `IQ3_K`, `IQ4_K`, `IQ5_K`, `IQ6_K`, `IQ2_KS`, `IQ4_KS`, `IQ5_KS`, `IQ4_KSS`, `IQ2_KL`    |
| Row-interleaved    | `*_R4` variants (for example `IQ4_K_R4`, `IQ4_KS_R4`), `IQ4_KS_R16`; created by `-rtr` or offline |
| Trellis quants     | `IQ1_KT`, `IQ2_KT`, `IQ3_KT`, `IQ4_KT`                                                            |
| Bitnet and ternary | `IQ1_BN`, `IQ2_BN`, `Q1_0_G128_R8` (Bonsai 1-bit)                                                 |
| Others added       | `Q8_KV` (8-bit KV cache type), `MXFP4` (gpt-oss), `Q6_0`                                          |
| Mainline types     | `Q*_K`, `Q*_0/1`, `IQ*_XS/S/M/NL` with ik's improved quantization code                            |

Which types have CUDA kernels differs. All types now have quantized matmul kernels on CUDA, but row-interleaved variants mostly do not, and k-quants (`Q2_K` to `Q6_K`) have no CUDA row-interleaved implementation.

## Compatibility rules from upstream

- Do not use Unsloth quants with `_XL` in the name if they contain `f16` tensors; they are likely not to work. Other Unsloth files are fine.
- Mainline GGUFs for DeepSeek with MLA work again (PR 394, PR 409 recovered prompt speed).
- Quants made with the Thireus quantization suite need the build option `-DGGML_MAX_CONTEXTS=2048`.
- The fork diverged from llama.cpp in mid 2024: new mainline-only quant types or architectures may not load. Check the README "Model Support" list for your architecture before downloading.

## Architectures

The README lists supported models by PR, including DeepSeek V3/V4, Kimi, GLM-4.x to GLM-5, Qwen3, Qwen3-Next, Qwen3.5, gpt-oss, Gemma 3/4, Mistral, MiniMax, Step, Hunyuan, Ernie 4.5 MoE, Ling/Ring and others. Treat that list as the source of truth and re-read it for the exact model; do not infer support from mainline.

Split mode `graph` has its own architecture list (`docs/parameters.md`, section "Graph parallel models"): Llama, Qwen3/Qwen3-MoE/Qwen3-VL, Qwen3.5 (dense and MoE), GLM-4 MoE, GLM-DSA, DeepSeek2, gpt-oss (`OPENAI_MOE`), Gemma 4, Mistral 3/4, Command-R, Cohere2, MiniMax-M2, Step-3.5, Seed-OSS, Hunyuan MoE, Ernie 4.5 MoE, Mimo2, Mellum, Laguna.

## Getting files

```bash
export HF_TOKEN=...   # from a 0600 file, never inline; only for gated repos
hf download <repo> --include '<quant>/*' --local-dir /models/<name>
ls -lh /models/<name>/*.gguf
```

Split files: pass only the first shard (`...-00001-of-0000N.gguf`). Multimodal projector: separate `mmproj-*.gguf` passed with `--mmproj` (sharded mmproj is also supported).

Inspect tensors and layer count (needed for `-ot` regexes):

```bash
python3 gguf-py/scripts/gguf_dump.py /models/model.gguf | less
```

## Sizing

Weight bytes are about `params x bpw / 8`. Add KV cache (`references/performance-tuning.md`) and compute buffers. Use `-dr` (`--dry-run`) to print the memory plan without loading.

## Making quants

`llama-quantize` (in the `full` image and `build/bin`) supports custom per-tensor mixes using regular expressions (README: March 2025, PR 244). `llama-imatrix` computes importance matrices; commonly used for low-bit types; check the publisher's recipe. `convert_hf_to_gguf.py` is in the repo root. For recipe choice see `model-quantization`.
