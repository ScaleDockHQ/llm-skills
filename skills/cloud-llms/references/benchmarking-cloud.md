# Benchmarking cloud LLMs

> Verified against the shared bench.sh interface used by self-hosted-llms and cloud-llms, vLLM v0.31.0 metrics docs, LiteLLM v1.105.0 health docs, 2026-10-11

## What it is and when to choose it

A repeatable way to measure latency and throughput of a cloud backend, with the same protocol used for local and self-hosted models so numbers are comparable. Benchmark before and after every deploy, scale, model change or engine update ("Measure before and after").

## Setup

The skill ships `scripts/bench.sh` (the same script as `self-hosted-llms`; bash + curl + jq, no Python):

```bash
scripts/bench.sh --base-url URL --model NAME [--runs N] [--warmup N] [--max-tokens N] \
  [--prompt-tokens N] [--concurrency N] [--key-file PATH] [--timeout SECONDS]
```

Environment fallbacks: `LLM_BASE_URL`, `LLM_MODEL`, `LLM_API_KEY`. Prefer `--key-file` (a file with `chmod 600`) so the key never appears in shell history or process lists.

It reports:

- **Median TTFB**: time to the first response byte; approximates time to first token (TTFT), and includes any cold start.
- **Decode tok/s**: completion tokens / (total - TTFB), single stream.
- **Prefill tok/s**: prompt tokens / TTFB, only with `--prompt-tokens N` (a cold run with a unique prefix and a warm run with an identical prompt, which exercises prefix caching).
- **Aggregate tok/s under concurrency**: total completion tokens / slowest request time across `--concurrency N` parallel streams (default 1 = skipped).

Defaults: `--runs 5`, `--warmup 1`, `--max-tokens 256`, `--timeout 600` seconds per request (raise it for cold starts on scale-to-zero backends). `--help` lists every option.

## Minimal working config

```bash
# Through the gateway (what clients experience)
scripts/bench.sh --base-url https://llm.example.com/v1 --model chat \
  --runs 10 --warmup 2 --max-tokens 256 --prompt-tokens 1000 --key-file ~/.config/llm/gateway.key

# Directly against the backend (isolates gateway and network overhead)
scripts/bench.sh --base-url http://10.0.0.1:8000/v1 --model <served-model-name> \
  --runs 10 --warmup 2 --max-tokens 256 --prompt-tokens 1000 --key-file ~/.config/llm/vllm.key

# Throughput at expected concurrency
scripts/bench.sh --base-url https://llm.example.com/v1 --model chat \
  --runs 5 --concurrency 16 --max-tokens 256 --key-file ~/.config/llm/gateway.key
```

## How it plugs into the stack

- Use the gateway alias for user-facing numbers and the backend URL for engine numbers; the difference is gateway plus network overhead.
- Before benchmarking, check health (`/health/liveliness` on LiteLLM, `/health` on vLLM) so you do not measure a cold start by accident, unless cold start is what you are measuring.
- For self-hosted engines, vLLM's `/metrics` (for example `vllm:num_requests_running`, `vllm:num_requests_waiting`) shows whether requests queued during the run.

## Operating: protocol

Same protocol as local benchmarks, plus cloud-specific controls:

1. **Fix the inputs**: same model ID (pinned version), prompt size, `max_tokens`, temperature, concurrency.
2. **Warm up**: discard warmup runs; serverless and scale-to-zero backends need a separate cold-start measurement.
3. **Measure from the right place**: run the client in the same region as your real clients (or the gateway). A laptop on home Wi-Fi measures your network.
4. **Record context**: provider, region, instance or deployment type, time of day, date, image tag, engine flags.
5. **Repeat**: managed APIs vary with shared load. Run at different times of day and keep medians, not best runs.
6. **Compare cost per task**, not just speed: combine aggregate tok/s with the cost formulas in `cost-and-quotas.md`.

## Tuning knobs worth knowing

- `--prompt-tokens`: long prompts expose prefill speed and prompt-caching effects (run twice with the same prompt to see cache hits on providers that cache).
- `--concurrency`: step through 1, 4, 16, 64 to find where latency degrades.
- `--max-tokens`: long outputs stabilize decode tok/s.

## Known pitfalls

- **Network latency** dominates TTFB for short prompts on remote APIs; subtract a baseline (for example, time a `/v1/models` call) when comparing engines.
- **Provider-side variance**: shared-capacity APIs differ by hour and region; one run proves little.
- **Rate limits** cap concurrency tests on APIs; a 429 is a quota result, not a speed result.
- **Cold starts** mixed into warm numbers on serverless backends.
- **Different models under one alias**: fallbacks during a test silently change the backend; check gateway logs.
- Benchmarking a frontier API is mostly measuring their capacity that day; use it for SLO checks, not engine comparisons.

## Official links

- vLLM metrics: https://docs.vllm.ai/en/latest/usage/metrics/
- LiteLLM health checks: https://docs.litellm.ai/docs/proxy/health
