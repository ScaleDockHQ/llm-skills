# Choosing Hardware: sizing math

> Verified against vendor bandwidth and capacity figures in references/hardware-matrix.md (NVIDIA, Apple, Intel pages), Ollama FAQ (parallel requests and KV cache types), llama.cpp server README (`--cache-type-k`, `--fit`, `--n-cpu-moe`), 2026-10-11

The formulas are arithmetic, not upstream claims. The hardware numbers fed into them are verified in `hardware-matrix.md`. Every output below is a planning estimate. Measure the real model, quant and engine before buying.

## 1. Weights

```
weights_bytes = parameters x bits_per_weight / 8
```

Weights-only memory in GB (1 GB = 10^9 bytes) at nominal precision. Real quant files are larger than the nominal figure because they store scales and keep some tensors at higher precision, so replace these with the actual file size from the model page.

| Parameters | 16-bit | 8-bit | 4-bit |
| ---------- | ------ | ----- | ----- |
| 8B         | 16     | 8     | 4     |
| 14B        | 28     | 14    | 7     |
| 32B        | 64     | 32    | 16    |
| 70B        | 140    | 70    | 35    |
| 120B       | 240    | 120   | 60    |
| 235B       | 470    | 235   | 117.5 |

MoE models store all experts, so memory follows total parameters, while per-token reads follow active parameters (section 4).

## 2. KV cache

```
kv_bytes = 2 x layers x kv_heads x head_dim x bytes_per_element x context_tokens x concurrent_sequences
```

Read `layers`, `kv_heads` (grouped-query `num_key_value_heads`) and `head_dim` from the model's `config.json`. Models with sliding-window, MLA, state-space or hybrid layers need the model card or engine docs instead, because the formula overstates them.

Illustrative numbers (not a specific model): 48 layers, 8 KV heads, head dim 128, FP16 cache.

- Per token: 2 x 48 x 8 x 128 x 2 bytes = 196,608 bytes (192 KiB).
- 32,768 tokens, one sequence: 6.0 GiB.
- 8 concurrent sequences at 32,768 tokens: 48 GiB.
- An 8-bit cache halves those figures, a 4-bit cache quarters them. Ollama's FAQ describes `q8_0` as about half of `f16` memory and `q4_0` as about a quarter, with `q4_0` loss more noticeable at higher context and for high-GQA models. llama.cpp exposes the same idea through `--cache-type-k` and `--cache-type-v`.

**Quality gate.** KV-cache quantization changes numerics. Gate it with `llm-evals` before using it to make a model fit: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.

Concurrency multiplies this term. Ollama states that required memory scales with `OLLAMA_NUM_PARALLEL` times `OLLAMA_CONTEXT_LENGTH`, and that a 2K context with 4 parallel requests becomes an 8K context allocation. Other engines expose their own limits (vLLM `--max-num-seqs`, llama.cpp `--parallel`); see the engine skills.

## 3. Total and headroom

```
total = weights + kv_cache + runtime_overhead + os_headroom
```

- Plan at least 10 to 20 percent of device memory free for runtime buffers and activations. This is a planning heuristic, not an upstream figure. Use more on unified-memory machines, because the OS and other apps share the pool.
- llama.cpp can fit unset arguments to device memory with `--fit` and a per-device margin with `--fit-target`. It also keeps MoE expert weights on the CPU with `--cpu-moe` or `--n-cpu-moe N` when VRAM is short. That trades speed for capacity.
- Splitting across several GPUs adds per-device overhead. Ollama loads onto one GPU if the model fits, and spreads only when it does not, because PCIe transfer costs speed.

## 4. Decode bandwidth ceiling

Decode generates one token at a time per sequence. Each step reads the active weights (and the KV cache for that sequence) from memory, so memory bandwidth bounds speed.

```
decode_tok_s_ceiling ~= memory_bandwidth_GBps / bytes_read_per_token_GB
```

`bytes_read_per_token` is the active weights in GB (the full weights for a dense model) plus the KV cache read. Real speed is lower: kernels do not reach peak bandwidth, and attention, sampling and launch overhead add time.

Worked ceilings for a dense 70B at 4-bit (35 GB read per token, KV ignored):

| Hardware                       | Bandwidth (GB/s) | Ceiling (tok/s) |
| ------------------------------ | ---------------- | --------------- |
| DGX Spark (GB10)               | 273              | 7.8             |
| Mac Studio M5 Max, 32-core GPU | 460              | 13.1            |
| Mac Studio M5 Max, 40-core GPU | 614              | 17.5            |
| RTX PRO 6000 Blackwell         | 1792             | 51.2            |
| H100 (3.35 TB/s)               | 3350             | 95.7            |
| H200 (4.8 TB/s)                | 4800             | 137.1           |

For a dense 32B at 4-bit (16 GB): RTX 5090 at 1792 GB/s gives a ceiling of 112 tok/s, and DGX Spark gives 17.1 tok/s.

For an illustrative MoE with 120B total and 5B active parameters at 4-bit, the model needs about 60 GB of memory but reads about 2.5 GB per token. On DGX Spark the ceiling is 273 / 2.5 = 109 tok/s. This is why large-memory, lower-bandwidth machines suit big MoE models far better than big dense ones.

**Batching changes the picture.** With several sequences in one step, the weights are read once and shared, so aggregate throughput rises with concurrency while per-user speed stays near the single-stream figure until compute or KV capacity binds. A high-bandwidth GPU with a batching engine serves many users; a unified-memory box serves a few.

## 5. Prefill is compute-bound

Prompt processing is limited by compute (tensor throughput), not memory bandwidth. Long prompts, RAG and agent tool outputs make time-to-first-token depend on compute. Do not use the bandwidth ceiling to predict prefill speed. TensorFold's own README notes prompt processing on Apple Silicon can trail mlx_lm for some models, so measure prefill separately.

## 6. Multi-device

- **Tensor parallel across GPUs** needs fast interconnect. The GeForce RTX 5090 spec lists NVLink as **No**, so multi-card consumer rigs communicate over PCIe. Datacenter systems use NVLink (the NVIDIA GB200 NVL72 page lists 130 TB/s of NVLink bandwidth across the rack).
- **DGX Spark** has a ConnectX-7 NIC at 200 Gbps, and NVIDIA states up to four systems can be connected for larger models. A link is far slower than local memory, so test whether a model split across nodes is worth it.
- **Apple Silicon** clusters over Thunderbolt 5 exist as a connectivity option (Mac Studio lists Thunderbolt 5 at up to 120 Gb/s). Whether a given engine supports multi-Mac inference is engine-specific; TensorFold lists two-Mac recipes for qualified models only.

## 7. Checklist

1. Write the model, whether it is dense or MoE, quant, context, and peak concurrency.
2. Compute weights, then KV, then add headroom.
3. Compare with usable memory, not marketing memory (unified-memory GPU share is capped).
4. Compute the bandwidth ceiling from active bytes. If it is below the speed users need, change hardware, quant or model.
5. Check engine support in `choosing-inference-engine`.
6. Gate any quant or KV change with `llm-evals`.
7. Benchmark before buying more than one unit.

## Sources

- https://docs.ollama.com/faq
- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- https://github.com/ashhart/TensorFold
- Bandwidth and capacity inputs: see `hardware-matrix.md` sources
