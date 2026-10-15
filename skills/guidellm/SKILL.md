---
name: guidellm
description: Benchmark LLM servers with GuideLLM (guidellm run) for SLO-aware latency and throughput using sweep, concurrent, constant and Poisson profiles, TTFT/ITL, goodput and trace replay against vLLM or any OpenAI-compatible endpoint. Use for guidellm install, synthetic or Hugging Face data, benchmarks.json and CSV reports, knee detection, 0.6 to 0.8 CLI migration, worker crash errors. Not for answer quality (lm-evaluation-harness) or NVIDIA AIPerf (nvidia-aiperf).
license: MIT
compatibility: Python 3.10-3.13 (pip, venv) on Linux or macOS, curl and jq; container image available. Needs a reachable OpenAI-compatible endpoint and a tokenizer (Hugging Face Hub or local). Installs, load against shared or paid endpoints, and trust_remote_code tokenizers need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# GuideLLM

Run SLO-aware load tests against an LLM server: pick a traffic profile, a data source and stop conditions, and get TTFT, ITL, throughput and goodput reports (`benchmarks.json`, CSV, HTML).

**Scope:** this one product: install, point at an endpoint, choose profile and data, set SLOs, read the report, update, troubleshoot. Engine and hardware choice belongs to `choosing-inference-engine` and `choosing-hardware`; a second benchmark tool with a different design is `nvidia-aiperf`. Answer quality belongs to `lm-evaluation-harness` and `promptfoo`.

Work through the steps in order. Load a reference only when a step names it. Verified against GuideLLM 0.8.1 (2026-10-11). The CLI changed in 0.7 and again in 0.8: confirm with `guidellm run --help`.

## Discover first

Read-only; nothing here prints secrets.

```bash
python3 --version                        # 3.10-3.13
command -v guidellm && guidellm --help | head -20
pip index versions guidellm 2>/dev/null | head -1
guidellm env 2>/dev/null | head -20      # GUIDELLM__* settings in effect (0.7+)
ls benchmarks.* results/ 2>/dev/null

URL="${LLM_BASE_URL:-http://localhost:8000}"
[ -n "${LLM_API_KEY:-}" ] && echo "LLM_API_KEY set" || echo "LLM_API_KEY not set"
curl -fsS ${LLM_API_KEY:+-H "Authorization: Bearer $LLM_API_KEY"} "$URL/v1/models" | jq -r '.data[].id'
```

## Decision flow

1. No guidellm, or an old one (the old `guidellm benchmark run` form): `references/install.md`, then `references/updating.md`.
2. First run: the sweep in Workflow 1 (flags in `references/run-and-profiles.md`).
3. Need a capacity number under a latency target: `--metrics` SLOs plus the `goodput` profile (`references/metrics-and-slo.md`).
4. Need a specific shape (fixed concurrency, fixed rate, bursty, production trace): `references/run-and-profiles.md`.
5. Own prompts, a Hugging Face dataset, multimodal, multi-turn: `references/data-and-backends.md`.
6. Gated API or a key: `references/data-and-backends.md` (key handling).
7. Errors, crashes, empty or odd numbers: `references/troubleshooting.md`.
8. Comparing two servers or configs: same data, seed and profile; `references/combos/vllm-sweep-and-slo.md`.

## Rules

- **Pin the version.** `pip install "guidellm[recommended]==0.8.1"` in a venv, or an immutable image tag (`vX.Y.Z`), never `latest` for decisions. The CLI has changed between minor versions.
- **Say what you ran.** A result needs profile, constraints, data (prompt and output tokens), backend `target`/`model` and the version. The report stores them; keep the file.
- **Fixed lengths by default.** For a requested output length GuideLLM sets `ignore_eos` so outputs reach the requested size; models that must stop on their own end token (for example Harmony/gpt-oss) need `extras.body.ignore_eos=false`, and then output lengths shrink.
- **Warm up and stop explicitly.** Use profile `warmup`/`cooldown` and a `max_duration` or `max_requests` constraint per strategy; add `over_saturation` so overloaded points do not waste time.
- **Same everything but one thing** when comparing: data, seed, profile, constraints, client host.
- **Keys never inline.** `api_key` lives in the backend config: put it in a `0600` file or environment variable, not in shell history or logs (`references/data-and-backends.md`).
- **`trust_remote_code` only for trusted tokenizers.** It executes repository code.
- **Prompts in reports.** `benchmarks.json` keeps request and response text by default: limit with `--metrics` `sample_size` and keep the file private.

## Workflows

### 1. First benchmark (sweep)

- [ ] Install in a venv. -> `references/install.md`
- [ ] Check the server: `/v1/models` lists the model; GuideLLM auto-detects the model when `model=` is omitted.
- [ ] Run: `guidellm run --backend kind=openai_http,target=$URL --profile kind=sweep --constraint kind=max_duration,seconds=60 --data kind=synthetic_text,prompt_tokens=256,output_tokens=128`. -> `references/run-and-profiles.md`
- [ ] Verify: results include a synchronous point, a throughput point and interpolated points; error counts are 0; `benchmarks.json` and `.csv` exist.

### 2. Capacity under an SLO

- [ ] Declare objectives: `--metrics '{"kind":"generative","slo":{"ttft_ms":200,"tpot_ms":50}}'`. -> `references/metrics-and-slo.md`
- [ ] Search: `--profile kind=goodput,target_attainment=0.99`, or `kind=knee` for the throughput knee.
- [ ] Verify: the `conclusions` section lists the highest passing and lowest failing concurrency; no "interval straddles the target" warning.

### 3. Specific traffic shape

- [ ] `concurrent` (`streams=`), `constant` or `poisson` (`rate=`), `throughput`, or `replay` for traces. -> `references/run-and-profiles.md`
- [ ] Verify: achieved rate or concurrency matches the target; dispatch delay stays near zero (otherwise the client is the bottleneck).

### 4. Own data and other APIs

- [ ] `json_file`, `csv_file`, `huggingface`, multimodal, `request_format` for chat, completions, embeddings, audio. -> `references/data-and-backends.md`
- [ ] Verify: reported prompt and output token means match your data.

### 5. Compare two configurations

- [ ] Same seed, data, profile; repeat runs. -> `references/combos/vllm-sweep-and-slo.md`
- [ ] Verify: differences exceed run-to-run variation, else report no measurable difference.

## Reference index

- `references/install.md`: requirements, pip, container, status, first check.
- `references/run-and-profiles.md`: CLI format, profiles, constraints, scenarios, seed, warmup, replay.
- `references/data-and-backends.md`: data kinds, synthetic options, tokenizer, backend options, key handling, vLLM in-process backend.
- `references/metrics-and-slo.md`: metrics, SLO attainment and goodput, knee and goodput profiles, outputs and file size.
- `references/combos/vllm-sweep-and-slo.md`: vLLM server, sweep, SLO search, comparison.
- `references/troubleshooting.md`: symptoms and fixes.
- `references/updating.md`: upgrade procedure and CLI migration from 0.6.

## Companion skills

- `vllm`: the usual server under test. Install: `npx skills add ScaleDockHQ/llm-skills --skill vllm`.
- `nvidia-aiperf`: alternative benchmark tool; do not mix numbers between tools. Install: `npx skills add ScaleDockHQ/llm-skills --skill nvidia-aiperf`.
- `self-hosted-llms`: shared `bench.sh` smoke benchmark and sizing. Install: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`.
- `lm-evaluation-harness`: answer quality for the same endpoint. Install: `npx skills add ScaleDockHQ/llm-skills --skill lm-evaluation-harness`.
