# Performance tuning

> Verified against KTransformers v0.7.1 (kt-kernel README parameter guidelines, Qwen3-Coder-Next and Native-Precision tutorials, `experts-sched-Tutorial.md`), 2026-10-11

Decode speed is bounded by CPU memory bandwidth and by how many experts the GPU holds; prefill speed by CPU compute, PCIe, and the layerwise-prefill
settings. Change one knob at a time, and record version, model, method, threads, GPU experts, prompt and output lengths, and concurrency.

```bash
kt bench            # full benchmark (check `kt bench --help`)
kt microbench       # micro-benchmark
# Or replay your own prompts over HTTP at the production concurrency (shared script: self-hosted-llms skill)
```

## Order of knobs

1. **Backend fit.** The wrong CPU variant is the biggest loss. `python -c "import kt_kernel; print(kt_kernel.__cpu_variant__)"` should say `amx` on AMX CPUs,
   an `avx512*` variant otherwise. `KT_KERNEL_DEBUG=1` shows the detection.
2. **Threads.** `--kt-cpuinfer` = physical cores; `--kt-threadpool-count` = NUMA nodes. Try fewer threads if other services share the box.
3. **GPU experts.** Raise `--kt-num-gpu-experts` (or `--kt-gpu-experts-ratio`) until VRAM nearly full while a `chunked-prefill-size` prompt still fits. More means lower
   latency. Upstream's examples: 32 on a 24 GB card for Qwen3-30B-A3B, 100 FP8 / 60 BF16 for Qwen3-Coder-Next.
4. **Placement.** Try `--kt-expert-placement-strategy frequency` with collected statistics, and `--kt-enable-dynamic-expert-update` with a prefill threshold, especially
   at low GPU-expert ratios.
5. **Deferred experts.** `--kt-max-deferred-experts-per-token` 1 to 4, re-check accuracy.
6. **Prefill.** Native methods: tune `--kt-gpu-prefill-token-threshold` (about 1024 to 4096) and `--chunked-prefill-size` (4096 to 16384). Larger chunks and the
   layerwise path help long prompts and need extra VRAM.
7. **Memory fractions.** `--mem-fraction-static` 0.80 to 0.92 and `--max-total-tokens` size the KV pool.
8. **Weights precision.** `FP8` halves RAM versus BF16; INT4 saves more with accuracy risk (AMXINT4 particularly).
9. **Hardware.** DDR channels and speed, PCIe 5.0, and NUMA locality matter more than any flag.

## Reference numbers (upstream, single concurrency)

Qwen3-Coder-Next FP8 on 1x RTX 5090 (32 GB) with 2x AMD EPYC 9355 over PCIe 5.0: prefill/decode tokens per second of 362/75.9 at 64 tokens, 1746/75.6 at 2048, 2407/69.1 at 8192, 6233/51.7 at 32768.
DeepSeek-R1-0528 FP8 on 8x L20 plus Xeon Gold 6454S: 227.85 total and 87.58 output tokens per second at 8-way concurrency (README). Treat them as upper-bound
expectations on tuned, expensive hardware, not promises.

## OOM during prefill

Layerwise prefill needs extra VRAM. Reduce `--kt-num-gpu-experts`, `--chunked-prefill-size`, `--max-total-tokens`, or `--mem-fraction-static` (lower reserves more headroom). Test with an
input of length `chunked-prefill-size` before declaring a config safe.
