# Xinference performance tuning

> Verified against Xinference v4.0.0 (docs inference.readthedocs.io, GitHub releases, xinference/deploy/cmdline.py), 2026-10-11

Xinference wraps engines, so most throughput work is engine tuning passed as launch kwargs. Measure first
(`observability.md`), change one thing, record the version.

| Goal or symptom                                   | Action                                                                                                                                                                     |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| LLM throughput on NVIDIA                          | Use `vllm` or `sglang` instead of `transformers`; set `--gpu_memory_utilization`, `--max_model_len` (vLLM kwargs) explicitly; see the `vllm` and `sglang` skills for flags |
| More concurrent users                             | `--replica N` (replicas can share a GPU), then more workers; Xavier shares prefix KV across replicas (`parallelism-multinode.md`)                                          |
| Long prompts, repeated prefixes                   | `enable_xavier=True`; SGLang RadixAttention; check `usage.prompt_tokens_details.cached_tokens`                                                                             |
| TTFT vs decode interference                       | P/D separation (v3.4+, v4.0 cross-engine); measure against plain replicas first                                                                                            |
| Retune context or memory without a long reload    | `enable_weight_cache=true` then `xinference reload` (v4.0, vLLM 0.31.0+ or SGLang 0.5.21+)                                                                                 |
| Transformers engine slow                          | Continuous batching is on by default for LLMs; `XINFERENCE_BATCH_SIZE` (32) and `XINFERENCE_BATCH_INTERVAL` (0.003) tune it                                                |
| GGUF or low memory                                | `llama.cpp`: `n_gpu_layers` unset enables auto estimation (approximate, OOM possible); lower `n_ctx`; raise `n_parallel` only for parallel requests                        |
| Multimodal llama.cpp "exceeds available context"  | Context shift is off for multimodal: raise `n_ctx` or lower `n_parallel`                                                                                                   |
| Docker vLLM crashes with OOM-looking worker death | Raise `--shm-size` (default 64 MB is too small)                                                                                                                            |
| Slow first launch                                 | Virtualenv creation and package install; use a mirror, keep `XINFERENCE_VIRTUAL_ENV_SKIP_INSTALLED=1`, pre-download with **Download only**                                 |
| Launch storms                                     | `XINFERENCE_MAX_CONCURRENT_LAUNCHES` (5) avoids heartbeat timeouts                                                                                                         |
| 503 under load                                    | `XINFERENCE_HTTP_LIMIT_CONCURRENCY` is set too low (unset by default); also reload drains return 503                                                                       |
| Cap runaway generations                           | `XINFERENCE_MAX_TOKENS`                                                                                                                                                    |

Per-model environment variables go on the launch (`--env KEY VALUE`), not the server. Image and video engines
batch natively and do not use a Xinference step scheduler.

Capacity planning: `xinference cal-model-mem` or **Recommend configuration** estimate memory from metadata for
one sequence and 2048 tokens; real use needs headroom for longer contexts and concurrency. Use
`choosing-hardware` for sizing math.
