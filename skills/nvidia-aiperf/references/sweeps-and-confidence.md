# AIPerf: sweeps, goodput and confidence

> Verified against AIPerf 0.13.0 (docs `tutorials/sweeps.md`, `tutorials/multi-run-confidence.md`, `tutorials/goodput.md`, CLI options), 2026-10-11

## Sweeps from the CLI

A comma list on a "magic-list" flag (`--concurrency`, `--request-rate`, `--isl`, `--osl`, `--request-count`, `--benchmark-duration`, `--prefill-concurrency`) turns one command into a sweep:

```bash
aiperf profile --model "$MODEL" --url "$URL" --endpoint-type chat --streaming --tokenizer "$TOK" \
  --isl 1024 --osl 256 --concurrency 1,2,4,8,16,32,64 --request-count 300 \
  --warmup-request-count 30 --random-seed 42 --parameter-sweep-same-seed \
  --parameter-sweep-cooldown-seconds 10 --ui simple
```

- Several lists together form a Cartesian product (`--sweep-type grid`, default) or are paired element-wise (`--sweep-type zip`, equal lengths).
- **Seed:** by default each variation derives its own seed (`base_seed + index`), so each point sees different prompts. For a clean curve pass `--random-seed N --parameter-sweep-same-seed`.
- Layout: `<base>/<dir_name>/` where `dir_name` looks like `concurrency_10`. The dashboard UI is rejected in sweeps and multi-run: use `--ui simple` or `none`.
- `aiperf config expand --config-file f.yaml` lists the variations of a YAML sweep before spending GPU time.
- Larger designs (YAML `sweep:` with `grid`, `zip`, `scenarios`; Sobol / Latin Hypercube; adaptive Bayesian search with `--search-*` flags; named recipes via `--search-recipe`, for example `max-throughput-ttft-sla`, `pareto-sweep`) are documented in `docs/tutorials/sweeps.md`, `docs/tutorials/adaptive-search.md` and `docs/sweeping/search-recipes.md`. Check the recipe's flags on your build (`aiperf profile --help | grep -i -A2 recipe`).

## Open-loop vs closed-loop load

- `--concurrency N` is closed loop: N requests in flight, a new one when one finishes. It cannot overload a server; latency rises with N.
- `--request-rate R` is open loop: arrivals follow `--arrival-pattern` (default `poisson`), so queues can grow without bound past capacity. Use it to find the saturation rate. Combine with `--concurrency` to cap in-flight requests.
- Time-based: `--benchmark-duration` with `--benchmark-grace-period` (default 30 s).

## Goodput (SLO throughput)

```bash
aiperf profile ... --goodput "time_to_first_token:200 inter_token_latency:25 request_latency:15000"
```

Space-separated `tag:value` pairs in the metric's display unit (ms for latencies; `output_token_throughput_per_user` in tokens/s). A request counts as good only if it meets every SLO. Two metrics result: `goodput` (good requests per second, in the console table) and `good_request_fraction` (good / (successful + errored); in the JSON, CSV and Parquet exports only). A CI gate on attainment:

```bash
jq -e '.good_request_fraction.avg >= 0.99' artifacts/<run-dir>/profile_export_aiperf.json >/dev/null && echo PASS || echo FAIL
```

Pick SLOs from the product requirement, not from a previous run's output.

## Multi-run confidence

```bash
aiperf profile ... --num-profile-runs 5 --confidence-level 0.95 --profile-run-cooldown-seconds 30 --ui simple
```

- 1 to 10 runs. Warmup runs only before the first run by default (`--no-profile-run-disable-warmup-after-first` to warm up every time). With more than one run a consistent seed (`--random-seed 42`) is set for you unless you disable it (`--no-set-consistent-seed`).
- `--vary-seed-per-trial` also varies prompts per trial (captures input variance; default off, so the intervals show pure runtime variance).
- Layout: `<base>/profile_runs/run_0001/...` and `<base>/aggregate/profile_export_aiperf_aggregate.{json,csv}` with per-metric `mean`, `std`, `min`, `max`, `cv`, `se`, `ci_low`, `ci_high`.
- Adaptive stop: `--convergence-metric time_to_first_token --convergence-stat p99 --convergence-mode ci_width --convergence-threshold 0.05` stops early when the interval narrows (`--num-profile-runs` is the cap; `distribution` mode needs `--export-level records` or `raw`).

Reading it (upstream guidance): CV under 0.05 is excellent, 0.05-0.10 good, 0.10-0.20 only large differences are meaningful, over 0.20 investigate or add runs. Non-overlapping intervals are strong evidence of a difference; heavy overlap means "no measurable difference". Report p99 metrics with their own interval: tail metrics need more runs than means.

## Hygiene for comparisons

Same seed, workload, tokenizer, client host and warmup; restart or reset the server between A and B when prefix caching could carry state (`--reset-kv-cache` where supported, see `combos/vllm-concurrency-sweep.md`); run A and B interleaved if the machine's load drifts; keep the exact command with the result.
