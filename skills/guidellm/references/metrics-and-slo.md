# GuideLLM: metrics, SLOs and outputs

> Verified against GuideLLM 0.8.1 (docs `guides/metrics.md`, `guides/service_level_objectives.md`, `guides/outputs.md`, `guides/knee_detection.md`), 2026-10-11

## Metrics

| Metric                                            | Definition                                                                                                                                            |
| ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Time to First Token (TTFT)                        | Time to the first generated token                                                                                                                     |
| Time to First Output Token (TTFOT)                | First visible content token; differs from TTFT when reasoning or tool tokens come first                                                               |
| Inter-Token Latency (ITL)                         | Average gap between consecutive output tokens, excluding the first                                                                                    |
| Time Per Output Token (TPOT)                      | Average per output token, including the first                                                                                                         |
| Request latency                                   | Start to finish per request                                                                                                                           |
| Requests per second, concurrency                  | Rate and in-flight requests                                                                                                                           |
| Output tokens per second, total tokens per second | Throughput                                                                                                                                            |
| Request status                                    | Successful, incomplete, error counts                                                                                                                  |
| Dispatch delay, scheduled latency                 | `request_start - targeted_start`, and latency from the scheduled arrival. Large dispatch delay means the benchmark client could not keep the schedule |
| SLO attainment, request goodput                   | See below                                                                                                                                             |

Each metric has a statistical summary (mean, median, mode, variance, std, min, max, percentiles) per status. Warmup and cooldown define a measurement window: request-level metrics include any request overlapping the window; event-level metrics (TTFT, ITL, per-token rates) include only events inside it.

## SLO attainment and goodput

Declare per-request objectives in milliseconds; a request conforms only if it meets all:

```bash
guidellm run --backend kind=openai_http,target=$URL \
  --profile kind=concurrent,streams=32 \
  --data kind=synthetic_text,prompt_tokens=256,output_tokens=128 \
  --metrics '{"kind":"generative","slo":{"ttft_ms":200,"tpot_ms":50}}' \
  --constraint kind=max_duration,seconds=120
```

Objectives: `ttft_ms` (needs streaming), `tpot_ms` (compared against inter-token latency, not GuideLLM's TPOT), `e2el_ms` (request latency; works without streaming). Reported: **SLO attainment** (share of requests meeting all objectives; errors count against it) and **request goodput** (conforming requests per second). Past saturation, request rate flattens while goodput falls.

Search for capacity: `--profile kind=goodput,target_attainment=0.99` doubles concurrency until a level misses the target, then bisects to within `tolerance` (default 10%). The outcome is appended to `conclusions` in the report, with a warning when an interval straddles the target (the probe was too short to decide): lengthen `max_duration`. A probe stopped by an enforced constraint is never used as a bound.

`--profile kind=knee,...` runs concurrent points and estimates where output throughput stops increasing; with `adaptive=true` it adds points around the estimate.

## Outputs

Default: console summary plus `benchmarks.json` and `benchmarks.csv` in `GUIDELLM__DEFAULT_RESULTS_DIR` or the current directory. Any `--output` replaces that default: repeat it for each format you want.

| `kind` | File              | Content                                                         |
| ------ | ----------------- | --------------------------------------------------------------- |
| `json` | `benchmarks.json` | Config, metadata, statistics, retained request data; reloadable |
| `yaml` | `benchmarks.yaml` | Same, as YAML                                                   |
| `csv`  | `benchmarks.csv`  | Summary table, no request-level data                            |
| `html` | `benchmarks.html` | Self-contained report with charts                               |
| `plot` | `benchmarks.png`  | Static graphs (path extension selects png, jpg, svg, pdf)       |

`--output kind=json,path=results/run-001.json` sets the path. Large runs keep every request's prompt and output text by default: limit with `--metrics` `sample_size` (per status group: unset keeps all, `0` stats only; upstream recommends about 20 samples). Reports contain prompts and responses: keep them private.

Inspect a report:

```bash
jq 'keys' benchmarks.json
jq '.benchmarks | length' benchmarks.json
jq -r '.benchmarks[0] | keys[]' benchmarks.json | head -30
```

Key names inside `benchmarks.json` are not documented in the pages read for this skill: run `jq keys` and `jq '.benchmarks[0] | keys'` on your version before scripting against it (unverified).
