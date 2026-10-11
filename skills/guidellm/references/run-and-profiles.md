# GuideLLM: run, profiles and constraints

> Verified against GuideLLM 0.8.1 (docs `getting-started/benchmark.md`, `guides/over_saturation_stopping.md`, `guides/knee_detection.md`, README), 2026-10-11

Always confirm on your build: `guidellm run --help`.

## Option format

`guidellm run --<option> kind=<TYPE>,key=value,...`. Flat settings use comma-separated `key=value`; nested values need JSON or YAML (`--data '{"kind":"huggingface","source":"org/ds","load_kwargs":{"name":"3.0.0"}}'`). Dotted keys also work for nesting (`extras.body.ignore_eos=false`, `source.kind=json_file`). A saved scenario (YAML or JSON) loads with `--config` (aliases `--scenario`, `-c`); CLI options override scenario values. A built-in scenario is selected by name (`--config chat`).

| Option                                                                      | Meaning                                                                                              |
| --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `--backend`                                                                 | One backend: `kind=openai_http,target=...,model=...,request_format=...` (see `data-and-backends.md`) |
| `--data`                                                                    | Repeatable data source                                                                               |
| `--profile`                                                                 | Traffic pattern (below). Default `sweep`                                                             |
| `--constraint`                                                              | Repeatable stop condition, applied to each strategy in the profile                                   |
| `--seed`                                                                    | `kind=static,value=42`; default is a fixed value, so reruns with the same arguments are reproducible |
| `--data-loader`                                                             | `kind=pytorch,samples=1000` limits loaded rows (`-1` all)                                            |
| `--tokenizer`                                                               | `kind=huggingface_auto,model=<id-or-path>`                                                           |
| `--output`                                                                  | Repeatable output; any `--output` replaces the default JSON and CSV                                  |
| `--metrics`                                                                 | SLO objectives and report-size control                                                               |
| `--override`                                                                | Per-strategy lists: `--override profile.streams 1,2,4,8`                                             |
| `--label`                                                                   | Metadata labels for the report, for example `--label gpu=<name>`                                     |
| `--disable-console-interactive` (`--disable-progress`), `--disable-console` | Quiet runs for CI                                                                                    |

## Profiles

| `kind`                     | Parameters                                                                                           | Use                                                                    |
| -------------------------- | ---------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `synchronous`              | none                                                                                                 | One request at a time: baseline latency                                |
| `throughput`               | `max_concurrency`, `rampup_duration`                                                                 | Saturate the server: peak throughput                                   |
| `concurrent`               | `streams` (list allowed), `rampup_duration`, `max_concurrency`                                       | Fixed parallel streams (closed loop)                                   |
| `constant` (alias `async`) | `rate` (list allowed), `rampup_duration`, `max_concurrency`                                          | Fixed arrival rate, open loop                                          |
| `poisson`                  | `rate`, `max_concurrency`                                                                            | Random arrivals around a rate; use `--seed`                            |
| `sweep`                    | `sweep_size`, `rampup_duration`, `strategy_type` (`constant` or `poisson`), `max_concurrency`        | Synchronous, then throughput, then `sweep_size - 2` interpolated rates |
| `knee`                     | `initial_streams` or `min_streams`/`max_streams`/`count`, `adaptive`, `points_each_side`, `max_step` | Concurrency points around where output throughput stops rising         |
| `goodput`                  | `target_attainment`, `tolerance`                                                                     | Search the highest concurrency meeting the SLOs in `--metrics`         |
| `replay`                   | `time_scale`, `schedule_turn` (`idle_gap` or `timestamp`)                                            | Replay trace timestamps                                                |

All profiles accept `warmup` and `cooldown` (a number in (0, 1) is a share of the run, 1 or more is seconds or requests). Multi-valued parameters were previously written inside `--profile` as JSON lists; 0.8 deprecates that in favour of `--override profile.<name> <values>`.

Open-loop profiles (`constant`, `poisson`) can queue unboundedly past capacity; closed-loop `concurrent` cannot. For capacity planning prefer `concurrent` ladders, `knee` or `goodput`; use rate profiles to reproduce a known arrival rate.

## Constraints

| `kind`                         | Parameters                                                                      |
| ------------------------------ | ------------------------------------------------------------------------------- |
| `max_duration`                 | `seconds`                                                                       |
| `max_requests`, `min_requests` | `count`                                                                         |
| `max_errors`                   | `count`                                                                         |
| `max_error_rate`               | `rate`, `window`                                                                |
| `max_global_error_rate`        | `rate`, `minimum`                                                               |
| `over_saturation`              | `min_seconds`, `max_window_seconds`, `moe_threshold`, `mode=enforce` and others |

Constraints apply per strategy: `max_requests,count=1000` with a sweep runs up to 1000 requests for each point. Over-saturation detection watches concurrency and TTFT slopes and stops queuing when both climb significantly, so a point past capacity ends early; in enforce mode in-flight requests are also cancelled.

## Trace replay

```bash
guidellm run --backend kind=openai_http,target=$URL \
  --data kind=trace_synthetic,source.kind=json_file,source.path=trace.jsonl,time_scale=1.0 \
  --profile kind=replay,time_scale=0.5
```

Default columns: `timestamp`, `input_length`, `output_length` (override with `timestamp_column`, `prompt_tokens_column`, `output_tokens_column`). Supported trace formats (Mooncake, WEKA, OTEL) are in `docs/en/guides/trace_replay.md`. `min_concurrent_sessions` raises parallelism and `copies` extends short traces.

## Re-export a report

`guidellm export <path/to/benchmarks.json> --output kind=html` (0.7.2+, replaced `benchmark from-file`).
