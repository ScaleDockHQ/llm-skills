# Performance tuning

> Verified against ExLlamaV3 v1.6.1 (README, doc/env_vars.md) and TabbyAPI main (config_sample.yml), 2026-10-11

Tune in this order and measure each step with a repeatable request set (`scripts/bench.sh` of `self-hosted-llms` works against any OpenAI endpoint, or time requests using the `timings` object in responses). Run a quality gate after changing bitrate, cache mode or drafting.

## 1. Fit and context

- Pick bpw to fit weights with headroom (`models-and-formats.md`).
- `max_seq_len` sets the longest single request; `cache_size` is the shared token pool across concurrent requests (multiple of 256). With N parallel users you need roughly N times the context each needs inside `cache_size`.
- `cache_mode`: `FP16` default; `8,8` halves KV memory; lower k/v bits save more with growing quality risk (range 2 to 8). Quantizing K usually hurts more than V (common experience, not an upstream claim).
- `autosplit_reserve` larger if loads OOM on activation spikes.
- `chunk_size` (default 2048): lower reduces VRAM spikes, slows prefill; try 512 to 4096.
- `output_chunking: true` (default) allocates cache as generation proceeds rather than for the whole completion.

## 2. Concurrency

`max_batch_size`: defaults to 32 for transformer architectures and 4 for recurrent/hybrid models because they need more VRAM per slot; reduce if you serve one user to save VRAM, raise only with spare VRAM. TabbyAPI uses continuous batching with paged attention (Ampere+).

## 3. Prefix and tiered caching

Prompt cache hits avoid prefill. `sysmem_kv_cache` keeps evicted pages in RAM and restores them on hits; `disk_cache_dir` persists across restarts (experimental, ExLlamaV3 1.6.2+). Hybrid/recurrent models can only replay from checkpoints: tune `recurrent_checkpoint_interval_pp` (denser grid makes early-edit replays cheaper at about 2 to 3 percent slower cold prefill, per config comments).

## 4. Speculative decoding

```yaml
draft_model:
  draft_mode: model # model | disabled | mtp | ngram
  draft_model_name: Qwen3-0.6B-exl3 # same tokenizer family as the target
  draft_cache_mode: 8,8
  draft_num_tokens: # blank uses the mode default
  dynamic_draft: true # adapt token count to acceptance; ceiling is draft_num_tokens
  hybrid_draft_tokens: 0 # >0 drafts verbatim repeats of earlier context (editing, reciting)
```

- `model`: a small EXL3 model of the same family; disabled when `draft_model_name` is empty.
- `mtp`: use the multi-token-prediction head some checkpoints ship.
- `ngram`: no extra weights; `ngram_match_min` (default 2) sets the match length. Good for code editing.
- Drafting costs VRAM and helps most at batch size 1 with predictable text. v1.6.1 added a hybrid mode (draft model plus long n-gram) and lower VRAM for recurrent drafters. Benchmark with and without; acceptance depends on sampling temperature.
- The MiaAI fork adds DFlash2/DSpark diffusion drafters (fork README), not in upstream.

## 5. Warmup and graphs

`warmup: true` triggers kernel autotune and CUDA graph capture at load so the first request is not slow (adds seconds to load). Decode paths use CUDA graphs on CUDA (`EXL3_GRAPHS=1` default; a few percent faster decode). `EXL3_BC_ATTN` (default 1) runs decode attention as one captured C++ call; it declines for TP and some cache modes. Set a flag to 0 only for A/B tests or to work around a bug.

## 6. Allocator

ExLlamaV3 enables expandable segments in Torch's allocator unless `PYTORCH_CUDA_ALLOC_CONF` is set (faster than cudaMallocAsync); `memory.cuda_malloc_async: true` forces the async allocator.

## 7. Multi-GPU

See `parallelism-multinode.md`. Use `nccl` TP on NVLink, `native` on PCIe, and compare against plain layer split.

## Environment variables (selection)

Read `doc/env_vars.md` of your version for the full list (set before loading a model; most are for A/B testing). Verified examples: `EXL3_GRAPHS`, `EXL3_BC_ATTN`, `EXL3_BC_ATTN_TRACE` (print which attention modules built the fast path, to check an A/B test is real), `EXL3_BC_MLA`, `EXL3_BC_DSA`, `EXL3_BC_GDN`, `EXL3_MOE_SHARED_COOP`, `EXL3_MOE_CPU_THREADS`, `EXL3_GDN_SUB_CHUNK` (default 2048), `EXL3_GR_MIX_TILED`. Defaults differ between CUDA and ROCm builds (for example `EXL3_GRAPHS` is 0 on ROCm).

## Quality gate

Compare a fixed prompt set (and an eval such as your task benchmark) between the baseline config and the tuned one; see `llm-evals`. KV-cache quantization, lower bpw and drafting parameters can each change results.
