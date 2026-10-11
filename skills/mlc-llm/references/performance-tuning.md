# Tuning MLC LLM

> Verified against MLC LLM main (8978ea9a; tags v0.20.0 and v0.26.dev0), 2026-10-11

Change one lever at a time. Benchmark with `/stats` in `mlc_llm chat`, or send repeated requests and read `/metrics` (`references/observability.md`). Use `--mode`, then memory, then compile options.

| Lever            | How                                                                                                          | Notes                                                                                                                                          |
| ---------------- | ------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Engine mode      | `--mode local\|interactive\|server`                                                                          | `local` (default) batch 4; `interactive` batch 1; `server` infers the largest batch and total sequence length from free memory for concurrency |
| Batch and length | `--overrides "max_num_sequence=32;max_total_seq_length=4096"`                                                | Explicit values win over the mode preset                                                                                                       |
| Memory fraction  | `--overrides "gpu_memory_utilization=0.85"`                                                                  | Fraction of GPU memory the engine may use (see `EngineConfig` in `python/mlc_llm/serve/config.py`); lower it on shared GPUs                    |
| Prefill          | `--prefill-mode hybrid\|chunked`, `prefill_chunk_size`                                                       | Smaller chunks lower peak memory and latency spikes                                                                                            |
| Prefix cache     | `--prefix-cache-mode radix` (default)                                                                        | Helps shared system prompts; `disable` to save memory                                                                                          |
| Context          | `context_window_size`, `sliding_window_size`, `attention_sink_size`                                          | Lower context cuts KV memory                                                                                                                   |
| Parallelism      | `tensor_parallel_shards`                                                                                     | Only when a model does not fit one GPU or for latency                                                                                          |
| Speculation      | `--speculative-mode`, `spec_draft_length`                                                                    | Needs a draft model; test acceptance on your prompts                                                                                           |
| Quantization     | `q4f16_1` default choice; `q4f32_1` for devices without fast fp16                                            | `q0f16` is unquantized fp16                                                                                                                    |
| Compile opts     | `--overrides "opt=O2"`, or `mlc_llm compile --opt "cutlass_attn=1;cutlass_norm=1;cublas_gemm=1;cudagraph=1"` | `O2` is the JIT default; `O3` may break the system; set `cudagraph=0` when calibrating                                                         |

JIT is deterministic per (model config, overrides, opt, device, library version): a changed override re-compiles into a new cached library under `$MLC_LLM_HOME/model_lib/`. Pre-warm by running once, then set `MLC_JIT_POLICY=READONLY` in production so a mis-set flag fails fast instead of compiling under load.

## Quality gate

After changing quantization, `opt` level or speculation, compare outputs on a fixed prompt set against the baseline before keeping it.
