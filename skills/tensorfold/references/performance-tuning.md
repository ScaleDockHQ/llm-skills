# TensorFold: performance and memory tuning

> Verified against TensorFold v1.0.7, 2026-10-11

README, RUNBOOK.md, docs/recipes/cuda.md, recipe READMEs

Measure on your own box; recipe and README tables are not your baseline. Upstream tracks receipts in `docs/cache-benchmarks.md` and `docs/memory-profiling.md`.

## Order of knobs

1. **Memory first.** Startup prints the capacity and memory it fitted. After a memory refusal reduce `--context` or the reply limit, or pick a smaller qualified checkpoint. A larger context needs more cache space. The `/memory` endpoint (read-only) reports process footprint, lifetime peak, backend allocation counters and the retained-prefix plan.
2. **`--context N`** covers prompt plus reply. Do not set it larger than you need; `/v1/models` advertises it as `context_length`.
3. **`--parallel N`** trades per-request speed for aggregate throughput; Flash Next serves one reply at a time regardless.
4. **`--prompt-cache-gib`** sizes retained prefixes (16 GiB default on CUDA). Disable (0) only to reclaim memory. `--prompt-cache-over-cap` is required for explicit budgets above the default allowance on Nemotron and Flash Next.
5. **Drafts.** Leave on. `--no-drafts` for quality A/B only. Qwen3.8-27B needs `--drafter` (4-bit prepared by default; `--drafter-bits 0` keeps bf16).
6. **Sampling and reasoning.** `--no-thinking` and `--reasoning-effort`/`--thinking-budget` bound hidden tokens; `--max-tokens` default is 4096.
7. **Metal idle:** `--keep-warm` default 900 s; 0 disables.

## Linux/GB10 specifics

- `TF_HEAT_HIGH` and `TF_HEAT_LOW` (degrees C, set together) make each prompt chunk wait while the hottest thermal zone is above the high band; the server logs `heat_wait_s`, and tokens are unchanged.
- `TENSORFOLD_CUDA_KERNELS` can select a captured Triton set; `native` forces built-ins.
- Upstream issue #627 reports Nemotron decode on GB10 about 1.4% (code) / 3.0% (prose) slower on 1.0.3 than 1.0.2, with the prose gap still present on 1.0.5. Benchmark before and after updating.
- Recipes that pin a large KV pool or set `TENSORFOLD_MEMORY_RESERVE_GIB=0` hold almost all of a Spark's unified memory; on that memory "running out tends to freeze the machine rather than fail an allocation". Keep them in an exclusive llama-swap group.

## Recipe-level trade-offs (verified from the recipes' READMEs, not from release docs)

- **FP8 KV cache** (`KV_DTYPE=fp8`, default in both recipes): about 1.8-1.9x KV pool on Flash Next, 2x on the 27B (32 KiB vs 64 KiB a token). Lossy: on Flash Next teacher-forced top-1 agreed with bf16 98.8% of the time; 27B measured 98.7% with the FP8 cache. Exactness holds against the FP8 cache itself, not bf16. `KV_DTYPE=bf16` is the exact option.
- **FP8 prompts** (`PREFILL_FP8=1`, 27B recipe default): about +52% prefill measured by the recipe author with a much larger KL (0.0419 vs 0.0031 for FP8 cache alone). Set `PREFILL_FP8=0` first if quality matters.
- **YaRN** (27B `YARN_FACTOR=4`, Flash Next `CONTEXT=1048576`) extends to a 1,048,576-token window; cold prefill is slow at length (27B: 205 s for 195k, 924 s for 491k, 2,664 s for 884k tokens), so use client timeouts of an hour or more. YaRN changes short-range replies slightly; leave it off if prompts are short.
- **Quant choice on Flash Next** (`QUANT=nvfp4|int4ar`): INT4-AutoRound is faster but uses 5 routed experts a token instead of 10; its authors report about 10% lower general capability.

## Measuring

```bash
# canonical repo script (see the self-hosted-llms skill); never quote vendor tables as your own numbers
curl -fsS http://127.0.0.1:8080/health | jq .
curl -fsS http://127.0.0.1:8080/metrics | grep -E 'tensorfold:(requests_running|kv_cache_usage_ratio|generation_tokens_total)'
```
