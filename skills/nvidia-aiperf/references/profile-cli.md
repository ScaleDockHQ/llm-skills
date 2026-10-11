# AIPerf: `aiperf profile` and the CLI

> Verified against AIPerf 0.13.0 (docs `cli-options.md`, `tutorials/yaml-config.md`, `tutorials/gpu-telemetry.md`), 2026-10-11

Always confirm on the installed build: `aiperf profile --help`. Defaults below are the 0.13.0 documented ones.

## Commands

| Command                                                                  | Use                                                                         |
| ------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| `aiperf profile`                                                         | Run a benchmark (the main command)                                          |
| `aiperf chat`                                                            | Talk to an endpoint and print per-turn TTFT/TPS/ITL (sanity check)          |
| `aiperf plot`                                                            | PNG charts and multi-run comparison from artifact directories               |
| `aiperf config init / validate / expand`                                 | Generate a YAML template, validate a file, expand a sweep to its variations |
| `aiperf analyze-trace`                                                   | ISL/OSL distributions and cache hit rates of a Mooncake trace file          |
| `aiperf synthesize`, `aiperf proxy`, `aiperf plugins`, `aiperf validate` | Trace synthesis, proxy, plugin listing, validation                          |
| `aiperf kube ...`                                                        | Kubernetes operator workflows (`init`, `profile`, `sweep`, `results`, ...)  |

## Minimal run

```bash
aiperf profile \
  --model "$MODEL" --url "$URL" \
  --endpoint-type chat --streaming \
  --tokenizer "$TOKENIZER" \
  --isl 1024 --osl 256 \
  --concurrency 16 --request-count 200 \
  --warmup-request-count 20 --random-seed 42 \
  --ui simple
```

`--ui` defaults to `dashboard` (a Textual TUI) in an interactive terminal and `none` otherwise; use `simple` or `none` in CI, logs, and any multi-run or sweep.

## Flags by group (0.13.0)

### Endpoint

| Flag                                        | Meaning                                                                                                                                                                                                                                                                                                                    |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `-m/--model`                                | Served model name(s); comma list allowed. `--model-selection-strategy round_robin\|random\|weighted` for several                                                                                                                                                                                                           |
| `-u/--url`                                  | Server origin(s), default `http://localhost:8000`; repeat for load balancing (`--url-strategy round_robin`); a missing scheme gets `http://`                                                                                                                                                                               |
| `--endpoint-type`                           | `chat` (default), `completions`, `embeddings`, `responses`, `messages`, `audio_transcription`, `cohere_rankings`, `hf_tei_rankings`, `huggingface_generate`, `image_generation`, `image_edit`, `video_generation`, `image_retrieval`, `nim_embeddings`, `nim_rankings`, `solido_rag`, `chat_embeddings`, `raw`, `template` |
| `--endpoint`                                | Override the request path (for example `/v1/custom`)                                                                                                                                                                                                                                                                       |
| `--streaming`                               | Stream tokens; required for TTFT and ITL; auto-disabled where the endpoint type cannot stream                                                                                                                                                                                                                              |
| `--api-key`                                 | Sent as `Authorization: Bearer <key>`                                                                                                                                                                                                                                                                                      |
| `-H/--header`                               | Extra headers (Input group)                                                                                                                                                                                                                                                                                                |
| `--extra-inputs`                            | Extra request-body fields, for example `--extra-inputs '{"temperature": 0}'` or `chat_template_kwargs`                                                                                                                                                                                                                     |
| `--request-timeout-seconds`                 | Per-request timeout, default 21600                                                                                                                                                                                                                                                                                         |
| `--wait-for-model-timeout`                  | Seconds to wait for the model to answer a one-token inference before starting (default 0 = skip); `--wait-for-model-mode models\|inference\|both`                                                                                                                                                                          |
| `--use-server-token-count`                  | Use `usage` from the server instead of client tokenization                                                                                                                                                                                                                                                                 |
| `--use-legacy-max-tokens`                   | Send `max_tokens` instead of `max_completion_tokens` for older servers                                                                                                                                                                                                                                                     |
| `--per-chunk-usage`                         | Ask for per-chunk usage so ITL corrects for servers that bundle tokens in the first chunk                                                                                                                                                                                                                                  |
| `--connection-reuse-strategy`               | `pooled` (default), `never`, `sticky-user-sessions`                                                                                                                                                                                                                                                                        |
| `--reset-kv-cache`, `--reset-kv-cache-path` | Once-per-run POST to reset the prefix cache (default path `/reset_prefix_cache`)                                                                                                                                                                                                                                           |
| `--server-profiler`                         | POST `/start_profile` and `/stop_profile` around the profiling phase                                                                                                                                                                                                                                                       |

### Tokenizer

`--tokenizer` (HF id, local path, or `builtin`; defaults to the model name), `--tokenizer-revision` (default `main`), `--tokenizer-trust-remote-code` (executes repo code: only for trusted repos), `--apply-chat-template` (count ISL with the chat template; off by default).

### Load

| Flag                                                                                           | Meaning                                                                                            |
| ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `--concurrency`                                                                                | In-flight requests; a new one starts when one completes. Comma list = sweep                        |
| `--request-rate`                                                                               | Requests per second (fractions allowed); with `--concurrency` it becomes a cap. Comma list = sweep |
| `--arrival-pattern`                                                                            | `poisson` (default), `constant`, `gamma`, `concurrency_burst`; `--arrival-smoothness` for gamma    |
| `--request-count`                                                                              | Total requests; synthetic default `max(10, concurrency * 2)`. Comma list = sweep                   |
| `--benchmark-duration`, `--benchmark-grace-period`                                             | Time-bounded run; responses within the grace period (default 30 s) still count                     |
| `--prefill-concurrency`                                                                        | Cap on requests in prefill (long-context memory safety)                                            |
| `--concurrency-ramp-duration`, `--request-rate-ramp-duration`                                  | Gradual ramp                                                                                       |
| `--warmup-request-count`, `--warmup-duration`, `--warmup-concurrency`, `--warmup-request-rate` | Warmup phase, excluded from metrics                                                                |
| `--failed-request-threshold`                                                                   | Abort early when the failed-request ratio exceeds this (0-1)                                       |
| `--request-cancellation-rate`, `--request-cancellation-delay`                                  | Cancellation testing                                                                               |
| `--user-centric-rate`, `--num-users`                                                           | Per-user rate limiting for KV-cache benchmarking                                                   |

### Output

| Flag                                                     | Meaning                                                                                                     |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `--output-artifact-dir`                                  | Default `artifacts`                                                                                         |
| `--profile-export-prefix`                                | Base name for every exported file                                                                           |
| `--export-level`                                         | `summary`, `records` (default, per-request JSONL), `raw` (request and response bodies: may contain prompts) |
| `--slice-duration`                                       | Time-sliced metrics (warmup effects, drift)                                                                 |
| `--export-outputs-json`                                  | Write generated text per request                                                                            |
| `--auto-plot`                                            | Run `aiperf plot` after the benchmark                                                                       |
| `--otel-url`, `--mlflow-tracking-uri`, `--wandb-project` | Stream or upload results (need the matching extra)                                                          |

### Telemetry and context

- `--server-metrics` (on by default, scrapes `<url>/metrics`; extra URLs allowed) and `--no-server-metrics`; `--server-metrics-formats json csv jsonl parquet`.
- `--gpu-telemetry [pynvml|amdsmi|dashboard|<dcgm urls>|<custom_metrics.csv>]` and `--no-gpu-telemetry`. Default DCGM endpoints are `localhost:9400` and `localhost:9401`, always attempted; the bare flag adds the console display. `pynvml` and `amdsmi` read local GPUs without DCGM. See the `dcgm-exporter` skill for the exporter.
- `--network-latency-automatic` or `--network-latency-mean <ms>`: subtract network RTT and emit `network_adjusted_*` metrics next to the raw ones.
- `--export-http-trace`: DNS, TCP/TLS, TTFB timing.

## YAML config

`aiperf profile --config benchmark.yaml` (alias `-f`). CLI flags layer on top of the file. Schema version `"2.0"`:

```yaml
schemaVersion: "2.0"
benchmark:
  model: meta-llama/Llama-3.1-8B-Instruct
  endpoint:
    url: http://localhost:8000
    type: chat
    streaming: true
  dataset:
    type: synthetic
    entries: 500
    prompts: { isl: 512, osl: 128 }
  phases:
    - { name: warmup, type: concurrency, concurrency: 8, requests: 50 }
    - { name: profiling, type: concurrency, requests: 500 }
  artifacts:
    dir: ./artifacts/my-test
sweep:
  type: grid
  parameters:
    concurrency: [8, 16, 32, 64]
```

Values support `${VAR:default}` environment substitution (keep secrets in the environment). `aiperf config init --list` shows bundled templates, `aiperf config validate --config-file f.yaml` checks a file, `aiperf config expand --config-file f.yaml` prints the expanded sweep. Note `request-count` on the CLI corresponds to `phases.profiling.requests`.

## Outputs

Per run, in the artifact directory: `profile_export_aiperf.json` and `.csv` (aggregates), `profile_export.jsonl` (per request, with `--export-level records` or `raw`), `inputs.json` (the prompts used), `logs/aiperf.log`, plus `*_gpu_telemetry.jsonl` and `*_server_metrics.{json,csv}` when collected. Read results with jq:

```bash
D=artifacts/<run-dir>
jq '{ttft_p99: .time_to_first_token.p99, itl_avg: .inter_token_latency.avg, tput: .output_token_throughput.avg, reqs: .request_count.avg}' "$D/profile_export_aiperf.json"
jq 'keys' "$D/profile_export_aiperf.json" | head -40
```

(Key names follow the metric tags in `workloads-and-metrics.md`; check `jq keys` on your version.)

Official sources: `docs/cli-options.md`, `docs/tutorials/yaml-config.md`, `docs/tutorials/gpu-telemetry.md`, `docs/tutorials/working-with-profile-exports.md` at https://github.com/ai-dynamo/aiperf.
