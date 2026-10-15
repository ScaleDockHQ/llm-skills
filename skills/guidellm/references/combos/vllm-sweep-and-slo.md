# GuideLLM against vLLM: sweep, SLO search, comparison

> Verified against GuideLLM 0.8.1 (README, docs `getting-started/benchmark.md`, `guides/service_level_objectives.md`) and vLLM `vllm serve` as used there, 2026-10-11

Server setup lives in the `vllm` skill (`npx skills add ScaleDockHQ/llm-skills --skill vllm`).

## 1. Server and check

```bash
vllm serve "<model>" --port 8000        # your production flags, pinned vLLM version
curl -fsS localhost:8000/v1/models | jq -r '.data[].id'
```

## 2. Discovery sweep

```bash
guidellm run \
  --backend kind=openai_http,target=http://localhost:8000 \
  --profile kind=sweep,sweep_size=10 \
  --data kind=synthetic_text,prompt_tokens=1024,output_tokens=256 \
  --constraint kind=max_duration,seconds=60 --constraint kind=over_saturation \
  --output kind=json,path=results/sweep.json --output kind=html,path=results/sweep.html \
  --disable-console-interactive
```

The first two points (synchronous, throughput) bound the range; the interpolated rates show how latency grows.

## 3. SLO capacity

```bash
guidellm run \
  --backend kind=openai_http,target=http://localhost:8000 \
  --profile kind=goodput,target_attainment=0.99 \
  --data kind=synthetic_text,prompt_tokens=1024,output_tokens=256 \
  --metrics '{"kind":"generative","slo":{"ttft_ms":500,"tpot_ms":40}}' \
  --constraint kind=max_duration,seconds=120 \
  --output kind=json,path=results/goodput.json
```

Take SLO numbers from the product requirement. Read `conclusions` for the highest passing concurrency.

## 4. Comparing two configurations (quant, flag, engine)

1. Same data, `--seed kind=static,value=42`, profile, constraints and client host.
2. Run the baseline and the candidate at the same fixed `concurrent` ladder, for example `--profile kind=concurrent --override profile.streams 1,4,16,64`.
3. Repeat each at least three times (separate runs; GuideLLM has no built-in multi-run statistics) and compare medians with the spread.
4. Report attainment and goodput at the SLO, not only peak throughput.

If vLLM runs in the same machine as the client, remember the client uses CPU too: check dispatch delay stays near zero. Use the vLLM Python backend (`data-and-backends.md`) only when you want to exclude HTTP overhead.
