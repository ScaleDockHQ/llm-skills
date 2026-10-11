# NVIDIA NIM performance tuning

> Verified against NIM LLM 2.0.13, 2026-10-11

Sources: GPU memory troubleshooting, speculative decoding, request troubleshooting and benchmarking pages.

## Memory math

Per-GPU weight memory is roughly `parameters x bytes_per_parameter / TP`. Bytes per parameter: BF16 2,
FP16 2, FP8 1, INT4 0.5, NVFP4 0.5. Llama 3.1 8B in BF16 on one GPU is about 16 GB of weights, which fits a
24 GB card with room for KV cache. This is a heuristic; the profile's `[requires >=N GB/gpu]` annotation
is the planning number. Weights are the largest consumer; KV cache and overhead come on top.

## Tuning order

1. Start with the profile NIM selects; a `throughput` or `latency` variant may exist, so list profiles.
2. If memory is tight, lower `NIM_MAX_MODEL_LEN` (or `--max-model-len`) as the low-memory hint suggests.
3. Raise tensor parallelism only through a profile that supports it.
4. Consider an FP8 or smaller-precision profile where the model offers one.
5. Backend flags after `nim-serve` (for example prefix caching, `--max-num-batched-tokens`); verify they
   exist in the image's vLLM version with `--dry-run`.
6. Speculative decoding: only where concurrency leaves spare compute; measure.
7. `NIM_DISABLE_CUDA_GRAPH` trades speed for memory and diagnosability.

## Benchmark it

NIM has a benchmarking page using standard load tools. At minimum, drive `/v1/chat/completions` with
streaming at your real concurrency and prompt lengths, and read vLLM metrics from `/v1/metrics`. The
repo's `self-hosted-llms` skill carries a shared `bench.sh` for quick OpenAI-API checks.

## Client timeouts

A ready server can still exceed a client timeout. Compare a short request, bound `max_tokens`, set the
client timeout to expected generation time, and check proxy timeouts in between.

## Cache and startup

Model download and engine load dominate first start. Persist the cache, use `NIM_CACHE_PROBE_TIMEOUT`
awareness for network mounts, and pre-populate with `download-to-cache` or a `NIMCache`.
