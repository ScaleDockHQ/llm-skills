# Sizing and expectations on CPU

> Verified against llama.cpp b11557 (server README, build.md), arithmetic from the stated formulas, 2026-10-11

The numbers here are arithmetic, not benchmarks. Measure on the host with `llama-bench` before promising anything.

## Bandwidth ceiling for decode

Each generated token reads (roughly) all active weights once from RAM:

```text
decode tokens/s  <=  usable memory bandwidth (GB/s)  /  bytes read per token (GB)
bytes per token  ~  size of the quantized weights  (dense)  |  active parameters x bits / 8  (MoE)
```

Usable bandwidth is below the spec-sheet peak (typically a fraction of it, depends on threads and NUMA). Measure it, then compare with the ceiling: a result far below means a build, thread or NUMA problem; at the ceiling means the host is bandwidth-bound and only a smaller quant, fewer active parameters or faster memory help. Prefill is compute-bound and scales with cores and vector width (AVX-512, AMX, KleidiAI i8mm), so CPU prefill on long prompts is the real pain point.

## Memory budget

```text
weights (GGUF file size)
+ KV cache = 2 x layers x kv_heads x head_dim x bytes_per_element x context_tokens x parallel_slots
+ compute buffers and runtime overhead (measure)
+ OS, page cache and other services (keep a large margin)
<= RAM
```

Read `layers`, `num_key_value_heads` and `head_dim` from the model's `config.json`.

## Choosing quants

- Smaller quant = fewer bytes per token = faster decode on a bandwidth-bound CPU. Q4_K_M is the common balance; step up to Q5/Q6 only if you measure a quality need, down to Q3/IQ quants only after an eval (`gguf-quantization`).
- Very low-bit quants can cost more compute per byte; on a CPU with weak vector units they may not be faster. Test both.
- A quantized KV cache (`-ctk q8_0 -ctv q8_0`) trims memory at some quality risk; gate it with an eval.

## MoE on RAM-heavy hosts

A large Mixture-of-Experts model reads only active experts per token, so a big-RAM CPU host can run models far larger than its dense equivalent would allow, at a speed set by active parameters. Weights still have to fit in RAM. If a GPU exists, llama.cpp can keep the experts on CPU and the rest on GPU (`-ncmoe N` or `-cmoe`; `llama-cpp` skill). For CPU-focused MoE speedups see `ik-llama-cpp`.

## When CPU is the wrong answer

Interactive chat on a 30B+ dense model, long-prompt agents and many concurrent users. Use a GPU, Apple Silicon (`apple-silicon`) or a hosted API (`cloud-llms`).
