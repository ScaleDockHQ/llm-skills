---
name: nvidia-aiperf
description: Benchmark LLM serving with NVIDIA AIPerf (aiperf profile) for TTFT, ITL, throughput, goodput, concurrency and request-rate sweeps against any OpenAI-compatible endpoint (vLLM, SGLang, TensorRT-LLM, Dynamo, NIM). Use for aiperf install, synthetic or trace workloads, multi-run confidence intervals, GPU telemetry, GenAI-Perf migration, tokenizer or dashboard errors. Not for answer quality (lm-evaluation-harness) or the vllm bench CLI.
license: MIT
compatibility: Python >=3.11,<3.14 (pip, venv) on macOS or Linux, curl and jq. Needs a reachable OpenAI-compatible endpoint and a Hugging Face tokenizer (network, or a local path). Installs, load against shared or paid endpoints, and anything that sends prompts to a hosted service need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# NVIDIA AIPerf

Measure latency and throughput of a served model with repeatable, seeded load: one command, a results directory (JSON, CSV, per-request JSONL), and a number you can compare.

**Scope:** this one product: install, point at an endpoint, shape the workload, sweep load, read the metrics, repeat for confidence, update, troubleshoot. Which engine or hardware to choose belongs to `choosing-inference-engine` and `choosing-hardware`. Answer quality belongs to `lm-evaluation-harness` and `promptfoo`.

Work through the steps in order. Load a reference only when a step names it. Verified against AIPerf 0.13.0 (2026-10-11). Confirm flags on the installed version with `aiperf profile --help`.

## Discover first

Read-only; nothing here prints secrets.

```bash
python3 --version                       # AIPerf 0.13.0 needs >=3.11,<3.14
command -v aiperf && aiperf --version
pip index versions aiperf 2>/dev/null | head -1
ls artifacts/ 2>/dev/null | head        # earlier runs (default output dir)

# Endpoint (key presence only, never the value)
URL="${LLM_BASE_URL:-http://localhost:8000}"
[ -n "${LLM_API_KEY:-}" ] && echo "LLM_API_KEY set" || echo "LLM_API_KEY not set"
curl -fsS ${LLM_API_KEY:+-H "Authorization: Bearer $LLM_API_KEY"} "$URL/v1/models" | jq -r '.data[].id'
curl -fsS "$URL/metrics" 2>/dev/null | head -3   # Prometheus server metrics (vLLM, SGLang) if exposed
nvidia-smi -L 2>/dev/null; curl -fsS localhost:9400/metrics 2>/dev/null | head -2   # DCGM exporter
```

## Decision flow

1. No aiperf, or Python outside 3.11-3.13: `references/install.md` (venv, pinned version).
2. First run against a new endpoint: smoke test, then a real run (Workflow 1; flags in `references/profile-cli.md`).
3. Need a representative workload (fixed ISL/OSL, mixed lengths, ShareGPT, your own prompts, production traces): `references/workloads-and-metrics.md`.
4. Need a capacity curve ("max concurrency under an SLO"): sweeps and goodput in `references/sweeps-and-confidence.md`.
5. Deciding between two configs (engine flag, quant, GPU): repeat runs with confidence intervals, same seed (`references/sweeps-and-confidence.md`); vLLM walkthrough in `references/combos/vllm-concurrency-sweep.md`.
6. Reasoning model: TTFT counts the first reasoning token; read `references/workloads-and-metrics.md` before comparing with other tools.
7. Errors, empty metrics, hangs: `references/troubleshooting.md`.
8. Upgrading or moving from GenAI-Perf: `references/updating.md`.

## Rules

- **Pin the version.** `pip install aiperf==0.13.0` in a venv; results across versions are not comparable until the baseline is re-run.
- **`--url` is the server origin.** `http://host:8000`; the CLI docs append the path from `--endpoint-type` (override with `--endpoint`). Upstream YAML examples also show a full URL, so if you get 404s, test both forms.
- **`--streaming` for latency.** TTFT and ITL exist only on streaming runs; it is off by default.
- **Say how many tokens.** Synthetic prompts default to a 550-token mean input and no output cap. Set `--isl`/`--osl` (and for output-length-sensitive comparisons make the server honour it) or results are not comparable.
- **Seed and warm up.** Set `--random-seed`, a warmup (`--warmup-request-count`), and enough requests; the default request count for synthetic data is only `max(10, concurrency * 2)`.
- **Same everything but one thing.** Same model, tokenizer, seed, workload, load shape and client machine on both sides of a comparison.
- **Keys by environment or file.** `--api-key "$(cat ~/.config/llm/key)"` from a `0600` file; do not paste keys into commands or logs.
- **The client can be the bottleneck.** Run it on a machine with CPU headroom and low network latency to the server, or use `--network-latency-automatic` and say so.
- **Never publish a number without its command.** The summary prints the CLI command and artifact paths; keep both with the result.

## Workflows

### 1. First benchmark

- [ ] Install in a venv. -> `references/install.md`
- [ ] Get the served model name from `/v1/models` and a tokenizer (HF id, local path, or `builtin`).
- [ ] Smoke test: `aiperf profile --model <name> --url <origin> --endpoint-type chat --streaming --tokenizer <tok> --request-count 10 --ui simple`. -> `references/profile-cli.md`
- [ ] Real run: add `--isl`, `--osl`, `--concurrency`, `--warmup-request-count`, `--random-seed`, `--request-count`.
- [ ] Verify: request count equals what you asked, no errors in the summary, `profile_export_aiperf.json` exists.

### 2. Concurrency or rate sweep

- [ ] Comma lists sweep: `--concurrency 1,2,4,8,16,32` (or `--request-rate`). -> `references/sweeps-and-confidence.md`
- [ ] Add `--goodput "time_to_first_token:<ms> inter_token_latency:<ms>"` for SLO-based throughput.
- [ ] Verify: find the knee where goodput stops rising and p99 TTFT climbs; do not read the highest throughput as the operating point.

### 3. A/B comparison

- [ ] Same seed and workload; `--num-profile-runs 3` or more with `--ui simple`. -> `references/sweeps-and-confidence.md`
- [ ] Compare means with their confidence intervals and CV, not single runs.
- [ ] Verify: differences larger than the run-to-run CV, otherwise report "no measurable difference".

### 4. Realistic workloads

- [ ] Mixed lengths (`--seq-dist`), custom prompts (`--input-file`), or trace replay. -> `references/workloads-and-metrics.md`
- [ ] Prefix-cache effects: pair with `--reset-kv-cache` where the server supports it. -> `references/combos/vllm-concurrency-sweep.md`
- [ ] Verify: reported ISL/OSL in the summary match the intended distribution.

### 5. GPU and server context

- [ ] `--gpu-telemetry` (DCGM, `pynvml`, or `amdsmi`) and server Prometheus metrics (on by default). -> `references/profile-cli.md`
- [ ] Verify: telemetry files exist in the artifact directory.

## Reference index

- `references/install.md`: requirements, pip install and extras, maintenance status, first run.
- `references/profile-cli.md`: `aiperf profile` flags by group, YAML config, other subcommands, outputs.
- `references/workloads-and-metrics.md`: datasets, ISL/OSL, traces, metric definitions and pitfalls (reasoning, ITL, TTFT).
- `references/sweeps-and-confidence.md`: sweeps, multi-run statistics, goodput, convergence.
- `references/combos/vllm-concurrency-sweep.md`: vLLM server, cache reset, concurrency sweep.
- `references/troubleshooting.md`: symptoms, causes, fixes.
- `references/updating.md`: upgrade procedure, GenAI-Perf migration.

## Companion skills

- `vllm`: the usual server under test. Install: `npx skills add ScaleDockHQ/llms-skills --skill vllm`.
- `sglang`: alternative server (cache flush path differs). Install: `npx skills add ScaleDockHQ/llms-skills --skill sglang`.
- `dcgm-exporter`: GPU telemetry source for `--gpu-telemetry`. Install: `npx skills add ScaleDockHQ/llms-skills --skill dcgm-exporter`.
- `nvidia-dynamo`: Dynamo serving, which AIPerf is part of. Install: `npx skills add ScaleDockHQ/llms-skills --skill nvidia-dynamo`.
- `self-hosted-llms`: shared `bench.sh` smoke benchmark and sizing. Install: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`.
- `lm-evaluation-harness`: answer quality for the same endpoint. Install: `npx skills add ScaleDockHQ/llms-skills --skill lm-evaluation-harness`.
