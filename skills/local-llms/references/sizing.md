# Sizing a model for your machine

> Verified against llama.cpp b11555 quantize README, Ollama v0.40.3 docs, LM Studio 0.4.26 docs, 2026-10-11

Before you download anything, check that the model will fit in memory. A model fits when this is true:

```
weights + KV cache + runtime overhead + OS/app headroom  <=  usable accelerator memory
```

If the total does not fit in GPU memory, the runtime moves layers to the CPU ("offloading"). The model still runs, but much more slowly.

## 1. Weights

```
weights_bytes ≈ parameters × bits_per_weight / 8
```

Bits per weight for common GGUF quants, from the llama.cpp quantize README (measured on an 8B model; the ratio is similar for other sizes):

| Quant | bits/weight | Notes |
| --- | --- | --- |
| Q8_0 | 8.50 | Near-lossless. Use it when it fits |
| Q6_K | 6.56 | Very close to Q8_0 |
| Q5_K_M | 5.70 | Good quality/size balance |
| Q4_K_M | 4.89 | Common default (llama.cpp `-hf` picks it when present) |
| IQ4_XS | 4.46 | Smaller than Q4_K_M with similar quality |
| Q3_K_M | 4.00 | Noticeable quality loss |
| IQ2_M | 2.93 | Only for very large models that won't fit otherwise |
| F16 / BF16 | 16 | Unquantized |

MLX quants are named by bits (`4bit`, `6bit`, `8bit`). MLX also stores scales per group, so a "4bit" MLX model takes a bit more than 4 bits per weight.

**Shortcut:** the file size on Hugging Face (the sum of all shards) is the weight size. Use that number, not a formula.

**MoE models:** all experts must be stored somewhere, so size by total parameters, not active parameters. Active parameters only affect speed. llama.cpp can keep expert weights in system RAM (`--cpu-moe`, `--n-cpu-moe N`), which lets a large MoE model run on a GPU with little VRAM.

## 2. KV cache

The KV cache grows linearly with the context window and with the number of parallel requests:

```
kv_bytes = 2 × n_layers × n_kv_heads × head_dim × context_tokens × bytes_per_element × parallel_slots
```

- `2` covers the K and V tensors.
- Read `n_layers` (`num_hidden_layers`), `n_kv_heads` (`num_key_value_heads`), and `head_dim` (or `hidden_size / num_attention_heads`) from the model's `config.json`. In a GGUF they are in the metadata, which llama.cpp prints at load time.
- `bytes_per_element`: f16 = 2, q8_0 ≈ 1.06, q4_0 ≈ 0.56.

Worked example: 32 layers, 8 KV heads, head_dim 128, 32,768 tokens, f16, 1 slot gives 2 × 32 × 8 × 128 × 32768 × 2 = 4 GiB.

Notes:
- Models with sliding-window or hybrid attention (for example SSM/attention mixes) need less than this formula says. Treat the formula as an upper bound.
- Ollama: memory scales with `OLLAMA_NUM_PARALLEL` × context. KV cache quantization (`OLLAMA_KV_CACHE_TYPE=q8_0`) needs flash attention.
- llama.cpp: `-ctk q8_0 -ctv q8_0` halves the cache. `-np` sets the number of slots.
- mlx-lm: `--kv-bits 4` or `--kv-bits 8` quantizes the cache, but disables batching.
- LM Studio: `lms load --estimate-only <model> --context-length N` prints an estimate without loading.

## 3. Runtime overhead

Plan for roughly 0.5 to 2 GB for compute buffers, the CUDA/Metal context, and a vision projector (`mmproj`) if the model has one. Larger batch sizes (`-b`, `-ub`, `--prefill-step-size`) increase it.

## 4. Headroom and usable memory

| Machine | Usable for the model |
| --- | --- |
| Discrete GPU (NVIDIA/AMD) | VRAM minus whatever the desktop already uses (`nvidia-smi` / `rocm-smi`). Leave about 1 GB free (llama.cpp's `--fit` defaults to a 1024 MiB margin per device) |
| Apple Silicon | Unified memory, but Metal can only wire part of it by default (commonly reported as about two-thirds to three-quarters depending on RAM; Apple doesn't document the exact figure, and llama.cpp prints `recommendedMaxWorkingSetSize` at startup). Keep at least 8 GB for macOS and your apps on 32 GB+ machines. See `macos-apple-silicon.md` |
| CPU only | System RAM minus OS/apps. Decode speed is limited by memory bandwidth |
| Integrated GPU (Windows/Linux) | Shared RAM. The GPU may only see a BIOS-set carve-out or a driver limit |

## 5. Offloading layers

When weights and KV cache don't fit in VRAM:
- llama.cpp: `-ngl auto` (the default) together with `--fit on` picks the layer count for you. Set `-ngl N` to choose it yourself. `-ot` / `--cpu-moe` move specific tensors to the CPU.
- Ollama: offloads automatically. `ollama ps` shows the split, for example `48%/52% CPU/GPU`.
- LM Studio: `lms load <model> --gpu 0.5|max|off`, or the GPU offload slider in the app.

Every layer on the CPU makes decoding slower. Partial offload is usually worse than picking the next smaller quant that fits entirely on the GPU.

## Quick sizing checklist

- [ ] Find usable memory (see the discovery commands in `SKILL.md`).
- [ ] Take the weight size from the file size, or compute it from the quant's bits per weight.
- [ ] Compute the KV cache for the context you actually need × parallel slots.
- [ ] Add 1–2 GB of overhead and the headroom from the table.
- [ ] If it doesn't fit: use a smaller quant, then a shorter context or quantized KV, then a smaller model, and only then partial offload.

## Official links

- llama.cpp quantization table: https://github.com/ggml-org/llama.cpp/blob/master/tools/quantize/README.md
- Ollama context length: https://docs.ollama.com/context-length
- Ollama FAQ (KV cache type, parallelism): https://docs.ollama.com/faq
- LM Studio `lms load`: https://lmstudio.ai/docs/cli/local-models/load
- mlx-lm server (KV quantization): https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/SERVER.md
