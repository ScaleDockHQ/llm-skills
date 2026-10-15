# AIPerf against vLLM: concurrency sweep with cache reset

> Verified against AIPerf 0.13.0 (docs `tutorial.md`, `tutorials/control-hooks-by-server.md`, `tutorials/goodput.md`) and the vLLM server flags documented there, 2026-10-11

Server setup is not covered here: use the `vllm` skill (`npx skills add ScaleDockHQ/llm-skills --skill vllm`). AIPerf only needs an OpenAI-compatible origin.

## 1. Server

Upstream's tutorial server (small model, for a smoke test):

```bash
docker run --gpus all -p 8000:8000 -e HF_TOKEN vllm/vllm-openai:latest \
  --model Qwen/Qwen3-0.6B --reasoning-parser qwen3 --host 0.0.0.0 --port 8000
```

For real runs use your production flags and a pinned image tag, never `latest`. `HF_TOKEN` comes from the environment, never inline.

Readiness (from the tutorial):

```bash
timeout 900 bash -c 'until curl -fsS localhost:8000/v1/models >/dev/null; do sleep 2; done'
```

or let AIPerf wait: `--wait-for-model-timeout 900`.

## 2. Optional: KV-cache reset and server profiler

AIPerf can POST `/reset_prefix_cache` once before the run (`--reset-kv-cache`) and `/start_profile` and `/stop_profile` around the profiling phase (`--server-profiler`). On vLLM both routes are only mounted when enabled on the server: the reset route needs the environment variable `VLLM_SERVER_DEV_MODE=1`, the profiler routes need a profiler configured (flag depends on the vLLM version; check `vllm serve --help`). Dev mode exposes admin routes: bind to localhost or a private network only. A reset returns HTTP 200 even if it failed (blocks still held), so make sure the engine is idle first. For SGLang the reset path is `/flush_cache` (`--reset-kv-cache-path /flush_cache`). TensorRT-LLM has no HTTP flush on `main` at the time of writing: leave the hooks off.

## 3. Sweep

```bash
aiperf profile --model Qwen/Qwen3-0.6B --url http://localhost:8000 \
  --endpoint-type chat --streaming \
  --isl 1024 --osl 256 --concurrency 1,2,4,8,16,32,64 --request-count 256 \
  --warmup-request-count 32 --random-seed 42 --parameter-sweep-same-seed \
  --goodput "time_to_first_token:500 inter_token_latency:30" \
  --reset-kv-cache --ui simple --output-artifact-dir artifacts/vllm-sweep
```

Drop `--reset-kv-cache` if the server does not expose the route (the run would otherwise fail its control request; check `references/troubleshooting.md`). With synthetic random prompts the prefix cache rarely hits: for cache effects use shared-prefix flags (`workloads-and-metrics.md`).

## 4. Read it

Find the concurrency where goodput peaks and p99 TTFT starts to climb; that is the capacity under the SLO. Compare server-side metrics in `*_server_metrics.json` (queue depth, KV usage) to see whether the limit was compute, KV memory or the client. Compare the result with the shared `bench.sh` smoke benchmark in the `self-hosted-llms` skill only as a sanity check: tools define latency differently.
