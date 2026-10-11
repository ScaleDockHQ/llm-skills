# AIPerf: workloads and metrics

> Verified against AIPerf 0.13.0 (docs `metrics-reference.md`, `benchmark-datasets.md`, `migrating.md`, CLI options), 2026-10-11

## Synthetic workloads

| Flag                                                                                                                   | Meaning                                                                                                              |
| ---------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `--isl N`, `--isl-stddev S`                                                                                            | Mean and spread of input tokens (default mean 550, stddev 0). Comma list sweeps                                      |
| `--osl N`, `--osl-stddev S`                                                                                            | Requested output tokens via `max_completion_tokens`; unset = the model decides                                       |
| `--seq-dist "128,64:25;512,128:50;1024,256:25"`                                                                        | Mixed `ISL,OSL:percent` pairs (percentages sum to 100)                                                               |
| `--random-range-ratio R`                                                                                               | Uniform window around the means; `--random-corpus-style vllm\|sglang` mirrors the respective `bench serve` semantics |
| `--prompt-prefix-pool-size`, `--prompt-prefix-length`, `--shared-system-prompt-length`, `--user-context-prompt-length` | Shared prefixes for prefix-cache tests                                                                               |
| `--conversation-num`, `--conversation-turn-mean`                                                                       | Multi-turn sessions                                                                                                  |
| `--random-seed`                                                                                                        | Deterministic dataset generation (multi-run sets 42 for you if unset)                                                |

Servers may stop before the requested OSL (EOS) unless they honour `min_tokens`/`ignore_eos`. To force exact lengths pass `--extra-inputs` fields your server supports (for vLLM, `ignore_eos` and `min_tokens` are accepted as extra body fields: verify in the vLLM docs for your version) and check the reported OSL.

## Real or custom data

- `--input-file <path>` with `--custom-dataset-type` (single-turn, multi-turn, random pool, trace types, raw payload replay). Formats: `docs/tutorials/custom-dataset.md`.
- `--public-dataset sharegpt` and others (`docs/benchmark-datasets.md`); datasets download from the Hub.
- Trace replay (Mooncake, Bailian, Baseten, BurstGPT, SageMaker data capture, agentic Weka/TraceLab): `--input-file` plus `--fixed-schedule` for timestamps; analyse first with `aiperf analyze-trace`.
- Exact prompts as-is: raw payload replay and `docs/tutorials/custom-prompt-benchmarking.md`. Prompts end up in `inputs.json` and, with `--export-level raw`, in the raw JSONL: treat artifacts as sensitive.
- Multimodal: image, audio and video generators (`--image-width-mean`, `--audio-length-mean`, `--video-duration`, ...), and `--endpoint-type` `embeddings`, `*_rankings`, `image_generation`, `video_generation`.

## Metrics (definitions from the metrics reference)

| Metric (tag)                                                          | Definition and caveat                                                                                                                                                  |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Time to First Token (`time_to_first_token`)                           | First content chunk time minus request start. Includes network, queueing, prefill and the first token                                                                  |
| Time to Second Token                                                  | Gap between the first and second content chunks                                                                                                                        |
| Inter Token Latency (`inter_token_latency`)                           | `(request_latency - TTFT) / (OSL - 1)`, exact only for one token per chunk. `--per-chunk-usage` corrects servers that bundle tokens in the first chunk. Needs OSL >= 2 |
| Inter Chunk Latency                                                   | Based on chunk arrival timestamps, not token counts                                                                                                                    |
| Request Latency (`request_latency`)                                   | End-to-end per request                                                                                                                                                 |
| Output Token Throughput Per User (`output_token_throughput_per_user`) | `1 / ITL`; excludes TTFT, so it is not comparable with aggregate throughput                                                                                            |
| Output Token Throughput (`output_token_throughput`)                   | Aggregate generated tokens per second over the run                                                                                                                     |
| Request Throughput                                                    | Completed requests per second                                                                                                                                          |
| Input/Output Sequence Length                                          | Tokens per request (client tokenizer, or server usage with `--use-server-token-count`)                                                                                 |
| Goodput, `good_request_fraction`                                      | SLO-compliant requests per second, and the fraction meeting every SLO (errors count in the denominator). See `sweeps-and-confidence.md`                                |
| Reasoning token count, spec-decode acceptance length                  | Present when the server reports them                                                                                                                                   |

Summary statistics per metric: avg, min, max, p99, p90, p50 (and others in the JSON), std.

## Reasoning models

AIPerf parses `reasoning_content`, so TTFT is the time to the first token of any kind (reasoning or answer) and it adds a separate time-to-first-output-token metric. GenAI-Perf ignored reasoning tokens and recorded TTFT at the first non-reasoning token, so numbers differ between the tools (upstream `migrating.md`). When comparing a reasoning model across tools or versions, compare TTFT and time-to-first-output-token separately. For vLLM, start the server with the right `--reasoning-parser` (see the `reasoning-models` skill).

## Comparing with other benchmark tools

`--random-corpus-style vllm` matches `vllm bench serve` random-dataset semantics, `sglang` matches `sglang.benchmark.serving` with `random-ids`; `--vllm-burstiness` is an alias of `--arrival-smoothness`. Equal flags do not guarantee equal numbers: tokenization, warmup and timing definitions differ, so compare tools only on identical inputs, and say which tool produced each number.
