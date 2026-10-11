---
name: choosing-hardware
description: Choose and size hardware for running an LLM, from model size, quantization, context and concurrency, using VRAM and memory-bandwidth math plus a spec table for NVIDIA RTX, datacenter, Blackwell and DGX Spark, AMD Instinct, Radeon and Strix Halo, Apple Silicon and Intel. Use when asked which GPU to buy or rent, how much VRAM or memory a model needs, whether a model fits, DGX Spark vs Mac Studio vs RTX 5090 vs H100, unified memory vs VRAM, or expected tokens per second. For engines use choosing-inference-engine. For where to host use choosing-llm-hosting.
license: MIT
compatibility: Read-only discovery uses a POSIX shell with optional nvidia-smi, rocm-smi, system_profiler, lscpu and free. The math needs only a calculator. Any purchase, install or system tuning needs the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Choosing Hardware

Turn a model, a quantization, a context length and a number of concurrent users into a memory budget and a bandwidth ceiling, then pick hardware that clears both with headroom.

**Scope:** sizing and choosing the machine. Choosing the engine stays in `choosing-inference-engine`. Choosing local, owned server or cloud stays in `choosing-llm-hosting`. Running it stays in `local-llms` and `self-hosted-llms`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Nothing here prints secrets.

```bash
uname -sm
nvidia-smi --query-gpu=name,memory.total,compute_cap,driver_version --format=csv,noheader 2>/dev/null
nvidia-smi topo -m 2>/dev/null | head -12
rocm-smi --showproductname --showmeminfo vram 2>/dev/null | head -20
system_profiler SPHardwareDataType 2>/dev/null | grep -E 'Chip|Memory'
sysctl iogpu.wired_limit_mb 2>/dev/null
free -h 2>/dev/null; lscpu 2>/dev/null | grep -E 'Model name|Flags' | head -2
```

Ask the user only what discovery cannot show: the model (or size class and whether it is dense or MoE), the quantization they will accept, the context length they really need, the peak number of concurrent requests, and the budget or power limit.

## Decision flow

1. **Weights.** `weights_bytes = parameters x bits_per_weight / 8`. Use the real file size from the model page when you have it, because quant formats store extra scales. See `references/sizing-math.md`.
2. **KV cache.** `kv_bytes = 2 x layers x kv_heads x head_dim x bytes_per_element x context_tokens x concurrent_sequences`. Read the layer and head counts from the model's `config.json`. Hybrid, state-space and MLA models differ, so use the model card for those. Quantizing the KV cache shrinks this but changes numerics (see Rules).
3. **Add overhead and headroom.** Runtime buffers, activations, graphs and the OS take a share. Plan for at least 10 to 20 percent free (a planning heuristic, not an upstream number), and more on unified-memory machines where the OS shares the pool.
4. **Does it fit?** Compare the total with the memory column in `references/hardware-matrix.md`.
   - Fits in one device: done with capacity.
   - Does not fit: lower the quant, lower the context or concurrency, use a MoE with fewer active parameters, add devices (tensor parallel needs fast links), or accept CPU offload (slow).
5. **Bandwidth ceiling.** Decode reads the active weights (and the KV cache) once per generated token per step. `decode_tok_s_ceiling ~= memory_bandwidth / bytes_read_per_token`. Real speed is lower. Batching amortizes weight reads, so aggregate throughput rises with concurrency until compute or KV memory becomes the limit.
6. **Pick by profile.**
   - One user, quality matters, model up to about 30B dense: one 24 to 32 GB GPU, or a Mac with 48 GB or more.
   - One user, large MoE or 70B-class at 4-bit: unified memory (DGX Spark, Strix Halo, Mac Studio) or a 96 GB workstation GPU. Expect lower tok/s than a high-bandwidth GPU of the same capacity.
   - Several users, interactive: a high-bandwidth GPU with room for KV cache for every sequence. Capacity per user decides, not just weights.
   - Many users or agents, throughput: datacenter GPUs (H100, H200, B200 class) and a batching engine.
   - Frontier-size models: multi-GPU nodes or rack-scale systems, and multi-node serving.
   - Prefer renting first when the workload is unproven. Use `choosing-llm-hosting` for the local, owned or cloud decision.
7. **Match the engine to the hardware.** Check `choosing-inference-engine` before buying, because some engines do not run on some hardware.
8. **Write the decision.** Record the model, quant, context, concurrency, the memory total, the bandwidth ceiling, the chosen hardware and the one number that would change the choice.

## Profiles at a glance

Capacities and bandwidths are from vendor pages read on 2026-10-11. Full table and sources: `references/hardware-matrix.md`.

| Class                   | Example                     | Memory                     | Bandwidth            | Notes                                                       |
| ----------------------- | --------------------------- | -------------------------- | -------------------- | ----------------------------------------------------------- |
| Consumer NVIDIA         | GeForce RTX 5090            | 32 GB GDDR7                | 1792 GB/s            | CUDA compute 12.0, no NVLink                                |
| Workstation Blackwell   | RTX PRO 6000 Blackwell      | 96 GB GDDR7 ECC            | 1792 GB/s            | Largest single-card memory in this table outside datacenter |
| Grace Blackwell desktop | DGX Spark (GB10)            | 128 GB LPDDR5x unified     | 273 GB/s             | Large capacity, modest bandwidth; two to four can be linked |
| Datacenter Hopper       | H100, H200                  | 80 GB, 141 GB HBM          | 3.35, 4.8 TB/s       | Many-user serving                                           |
| Apple Silicon desktop   | Mac Studio M5 Max, M5 Ultra | 36 to 128 GB, 96 to 512 GB | 460 to 614, 1.2 TB/s | Unified memory; GPU share is capped by macOS                |
| AMD Instinct            | MI300X, MI325X, MI355X      | 192, 256, 288 GiB          | not verified         | ROCm; check engine support                                  |
| Intel Arc               | Arc B580                    | 12 GB GDDR6                | 456 GB/s             | Budget, small models                                        |

## Rules

- **Ask before changing the system.** Purchases, installs, `sysctl` changes, power limits and BIOS settings need approval and an undo path.
- **Secrets never touch output.** Keys live in `0600` files or environment variables.
- **Verify upstream.** Specs, prices and support lists come from vendor pages read on the writing date. Re-check the exact SKU before buying. Street prices are not in this skill.
- **Gate numerics changes with `llm-evals`.** Choosing a lower weight quant to fit, quantizing the KV cache, or adding speculative decoding to hit a speed target can change outputs. Run the same eval set before and after. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
- **Estimates are ceilings.** Treat the bandwidth math as an upper bound and benchmark the real model, quant and engine before committing. The `self-hosted-llms` skill ships a benchmark script.
- **Capacity is per sequence.** Concurrency multiplies KV cache. Ollama, for example, multiplies context by the number of parallel requests (`OLLAMA_NUM_PARALLEL` times `OLLAMA_CONTEXT_LENGTH`).
- **Unified memory is not free VRAM.** On Apple Silicon the GPU limit is a share of RAM. Raising it with `iogpu.wired_limit_mb` is undocumented by Apple, resets on reboot and can cause swapping or freezes if set too high. Leave several GB for the OS.

## Reference index

- `references/hardware-matrix.md`: verified specs and engine support for NVIDIA, AMD, Apple and Intel hardware, with sources. Load for steps 4, 6 and 7.
- `references/sizing-math.md`: the formulas, worked examples, weight-size tables by parameter count and quant, and bandwidth ceilings. Load for steps 1 to 5.

## Companion skills

Install any of these with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `choosing-inference-engine`: pick the engine for the hardware. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-inference-engine`.
- `choosing-llm-hosting`: decide local, owned server, rented GPUs, serverless or API. Install: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`.
- `local-llms`: run models on a laptop or desktop. Install: `npx skills add ScaleDockHQ/llms-skills --skill local-llms`.
- `self-hosted-llms`: serve on your own NVIDIA servers and DGX Spark, with memory budgeting and a benchmark script. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `cloud-llms`: rent GPUs, serverless or managed endpoints. Install: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms`.
- `model-quantization`: produce the smaller quant that makes a model fit. Install: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`.
- `llm-evals`: quality gate for numerics changes. Install: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`.
