# Performance tuning and benchmarking

> Verified against vLLM v0.31.0 (docs `configuration/optimization.md`, `benchmarking/cli.md`), 2026-10-11

Tune one thing at a time, restart, and measure with the same workload. Record the vLLM version or image digest
next to every number: results from different versions are not comparable.

## Measure first

```bash
# A server must already be running. Never benchmark against a server other people use.
vllm bench serve --backend vllm --model <served-or-hf-name> --endpoint /v1/completions \
  --dataset-name random --random-input-len 2048 --random-output-len 256 \
  --num-prompts 200 --max-concurrency 16 --request-rate inf
```

- Other subcommands: `vllm bench latency`, `throughput`, `sweep`, `startup` (cold start), `mm-processor`.
- Metrics: TTFT (request sent to first streamed output), ITL (gaps between streamed outputs), TPOT (per
  request, excluding the first token). With speculative decoding ITL and TPOT diverge, so compare the same
  metric only. `--plot-timeline` helps debugging.
- For realistic traffic shapes (chat vs RAG vs agent loops, prefix reuse) upstream recommends GuideLLM. For a
  quick tokens/s check against any OpenAI-compatible endpoint, the repo-wide `scripts/bench.sh` of the skill
  `self-hosted-llms` also works.
- Sweep concurrency (1, 4, 16, 64). Single-stream tok/s measures decode speed; throughput at the concurrency
  you actually run measures what users feel.

## Knobs, in the order to try them

| Symptom                               | Try                                                                                                                                                                            |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Out of memory at load                 | Lower `--max-model-len`, `--max-num-seqs`, `--gpu-memory-utilization`; use `--kv-cache-dtype fp8`; quantize; raise TP                                                          |
| `Estimated maximum model length is N` | KV cache cannot hold one full request. Lower `--max-model-len` to N or free memory                                                                                             |
| Low throughput, free KV memory        | Raise `--max-num-seqs` and `--max-num-batched-tokens` (above 8192 for small models on big GPUs)                                                                                |
| Bad ITL under mixed load              | Lower `--max-num-batched-tokens` (e.g. 2048): smaller prefill chunks interrupt decodes less                                                                                    |
| Bad TTFT                              | Raise `--max-num-batched-tokens`; make sure `--enable-prefix-caching` is on if prompts share prefixes                                                                          |
| `num_preemptions` rising              | The KV cache is too small for the concurrency: raise `--gpu-memory-utilization`, lower `--max-num-seqs` or `--max-model-len`, add TP or PP                                     |
| Decode-bound single user              | Speculative decoding (`combos/eagle3.md`), FP8/NVFP4 weights, a faster attention or MoE backend                                                                                |
| Long startup                          | Compilation and CUDA graphs: keep `~/.cache/vllm` on persistent storage, reduce `--cudagraph-capture-sizes`, or use `--enforce-eager` for quick tests only (slower at runtime) |

- When chunked prefill is off, `--max-num-batched-tokens` must exceed `--max-model-len` or startup can crash.
- Preemption mode in V1 is recompute; there is no swap space (`--swap-space` was removed).
- `--gpu-memory-utilization` is a per-instance budget in v0.31.0 (default 0.92), not shared across instances on one GPU.
  For multiple instances on one GPU, use `--kv-cache-memory-bytes` per instance (see `serve-config.md`).
- Defaults for `--max-num-batched-tokens` and `--max-num-seqs` depend on hardware and usage context; read the
  startup log for the values actually used.

## CPU provisioning (often forgotten)

Each GPU deployment runs one API server, one engine core and one worker per GPU: at least `2 + N` physical cores
(hyperthreads count half). With DP or several API servers: `A + DP + N + (1 if DP > 1 else 0)`. The engine core
busy-loops, so starvation shows up as low GPU utilization. Check container CPU limits (`--cpus`, Kubernetes
requests/limits) before tuning anything else.

## Attention, kernel and quantization backends

- Attention backend is selected automatically; override with `--attention-backend <name>` (the old
  `VLLM_ATTENTION_BACKEND` env var is gone). Candidates in v0.31.0 include FlashAttention, FlashInfer, Triton,
  FlashMLA and ROCm backends; read the startup log (`Using ... backend`) before forcing one.
- MoE and linear kernels: `--moe-backend`, `--linear-backend`; on SM120/SM121 (RTX Blackwell, DGX Spark) the
  `b12x` NVFP4 kernels are the supported fast path. See `models-and-formats.md` for the matrix.
- FP8 KV cache (`--kv-cache-dtype fp8`) roughly doubles token capacity; check output quality on your tasks.
- Calibrated or pre-quantized checkpoints beat on-the-fly `--quantization fp8` for accuracy; see
  `combos/llm-compressor-fp8.md`.

## Parallelism for speed

- TP inside a node needs fast interconnect (NVLink best, PCIe workable). TP across slow links (Ethernet) hurts
  decode latency; prefer PP across nodes, or DP replicas when the model fits one node.
- Expert parallel (`--enable-expert-parallel`) for large MoE models; DP attention for MLA models. Details and
  flags are in `parallelism-multinode.md`.

## Unified-memory systems (DGX Spark, GB10)

- CPU and GPU share 128 GB. NVIDIA's Spark playbook uses `--gpu-memory-utilization 0.8`; higher values can starve the OS and freeze the box (the exact threshold is unverified);
  leave several GB free and watch `free -h`.
- Memory-bandwidth-bound decode: MoE and NVFP4 models give the best tokens/s; dense 70B-class models are slow.
- Page cache from reading weights counts against memory pressure: drop caches between runs
  (`sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'`) when loading fails with unexplained OOM.
