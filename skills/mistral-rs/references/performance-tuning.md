# Performance tuning

> Verified against mistral.rs v0.9.4 (docs `guides/perf/throughput-tuning`, `guides/perf/paged-attention`, `reference/cli/bench`, `guides/models/model-family-notes`), 2026-10-11

Change one thing at a time. Record the version, model, quant, flags, prompt and output lengths and concurrency with every number.
`mistralrs bench` measures a single request at the kernel level; for server tuning replay production-shaped traffic over HTTP.

```bash
mistralrs bench -m Qwen/Qwen3-4B --quant 4                       # single-request prefill and decode rates
# Concurrent load: the shared script from the self-hosted-llms skill (npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms)
```

## Levers, in order of impact

1. **Quantization**: the largest throughput lever, traded against quality (`models-and-formats.md`). Pre-quantized UQFF shortens
   start-up only, not steady-state speed.
2. **Paged attention (CUDA default)**: gives continuous batching against a shared block pool, block-level prefix sharing, and the
   FlashInfer and CUDA-graph decode paths. Without it (Metal, CPU, `--paged-attn off`) the default scheduler is first-come-first-served and
   batches only equal-length sequences. Size the pool explicitly: `--pa-context-len`, `--pa-memory-mb` or `--pa-memory-fraction`.
3. **Concurrency**: `--max-seqs` (CLI default 32; Python `Runner` 16). More sequences need more KV blocks. If the pool runs out
   mid-generation the scheduler preempts a sequence, frees its blocks and recomputes later. Watch `mistralrs_sequences_waiting` and
   `mistralrs_kv_cache_blocks_used` against `_total`.
4. **Batch shaping** (paged attention): `--max-num-batched-tokens` 4096, `--max-prefill-chunk-tokens` 512 (CUDA text prompts
   only), `--max-decode-steps-before-prefill` 8. Larger prefill chunks raise prefill throughput but delay active decodes; a higher
   decode-steps value favours inter-token latency, a lower one favours time to first token. Measure both p50 and p95.
5. **Prefix cache**: `--prefix-cache-n` (default 16; 0 disables). Worth raising for multi-turn chat or a shared long system prompt;
   check `mistralrs_prefix_cache_hits_total / lookups_total`. Without paged attention, whole sequences are cached and the oldest are
   dropped, not offloaded.
6. **KV cache dtype**: `--pa-cache-type f8e4m3` halves KV bytes versus BF16 for more concurrent context; verify quality on your tasks.
7. **Speculative decoding** (`features.md`): MTP, DFlash. Gains depend on acceptance rate; check `mistralrs_speculative_*`.
8. **Multi-GPU**: NCCL tensor parallelism is for fitting bigger models and bandwidth, not free speedup on small ones.

## Memory planning

Automatic device mapping reserves for `--max-seq-len` (4096) and `--max-batch-size` (1). Raise them for long prompts or big batches so
layers are not placed too greedily. Another process on the GPU plus the default 90% KV claim causes OOM at start; lower
`--pa-memory-fraction`.

## CUDA fast paths

FlashInfer paged decode and CUDA graphs are on by default where supported. `MISTRALRS_FLASHINFER_DECODE=0` and
`MISTRALRS_CUDA_GRAPHS=0` exist for debugging and comparisons only. Graphs help steady-state single-token decode, not prefill, and
capture costs time the first time a shape appears. Other switches: `MISTRALRS_MOE_BACKEND` (MoE kernels),
`MISTRALRS_GGUF_AFFINE_BACKEND=on` (faster GGUF matmuls at batch 8+, costs a second weight copy), `MISTRALRS_NO_MLA=1` (turns off
DeepSeek MLA acceleration).

## CPU

Default worker count is the high-capacity cores on heterogeneous Linux CPUs, otherwise physical cores. Override with
`RAYON_NUM_THREADS` or `CANDLE_NUM_THREADS`; pin with `CANDLE_CPU_MASK=15-19` (cpulist syntax; it also sets the default worker
count) or try `CANDLE_CPU_AFFINITY=1`. Hard affinity can hurt some CPU and model pairs. `mkl` is a build feature for Intel CPUs.

## Apple Silicon

Metal uses unified memory: keep model plus KV under what macOS allows, with headroom. Paged attention is off by default there, so
concurrency is limited; run few `--max-seqs`. AFQ quant formats are Metal-optimised (`--quant afq4`).

## Interpreting the numbers

- Time to first token = queueing + prefill (`mistralrs_time_to_first_token_seconds`).
- Inter-token latency stalls show up in high quantiles of `mistralrs_inter_token_latency_seconds`; averages hide them.
- Throughput: `rate(mistralrs_decode_tokens_processed_total[1m])`.
- `mistralrs_sequences_completed_total{reason="canceled"}` rising means clients are timing out.
