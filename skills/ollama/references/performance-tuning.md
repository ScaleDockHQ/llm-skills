# Ollama: performance tuning

> Verified against Ollama v0.40.3, 2026-10-11

Docs: faq, context-length, gpu; envconfig/config.go; /api/ps schema

Order of work: fit in GPU memory first, then speed, then concurrency.

## 1. Check placement

```bash
ollama ps
```

`PROCESSOR` shows `100% GPU`, `100% CPU` or a split such as `48%/52% CPU/GPU`. `CONTEXT` shows the allocated context. Any CPU share means the model plus context (plus parallel slots) does not fit; speed drops sharply. The same data is at `GET /api/ps` (`size`, `size_vram`, `context_length`, `expires_at`).

```bash
curl -s http://127.0.0.1:11434/api/ps | jq '.models[] | {name, size_gb: (.size/1e9), vram_pct: (100*.size_vram/.size), context_length}'
```

## 2. Context length

- Server default: `OLLAMA_CONTEXT_LENGTH`; if unset it depends on VRAM: under 24 GiB 4k, 24 to 48 GiB 32k, 48 GiB and up 256k. The FAQ still says 4096 in places; trust `ollama ps` for what is actually allocated.
- Coding tools, agents and web search need at least 64000 tokens.
- Per request (native API only): `"options":{"num_ctx":32768}`. REPL: `/set parameter num_ctx 32768`. Per model: Modelfile `PARAMETER num_ctx 32768` then `ollama create`.
- The OpenAI-compatible `/v1` API cannot set the context. Use the env var or a derived model.
- A larger context costs memory linearly; with `OLLAMA_NUM_PARALLEL` > 1 it is multiplied. On unified-memory machines (Apple, DGX Spark) the VRAM heuristic can pick a surprising default, so set it explicitly.
- Truncated or "forgetful" answers on a small default context are the commonly reported symptom (unverified mechanism: upstream docs only say tasks needing large context should use 64000 or more). Check `ollama ps` CONTEXT and raise the value.

## 3. Flash attention and KV cache quantization

- Flash attention is used automatically when backend and devices support it. Force with `OLLAMA_FLASH_ATTENTION=1`, disable with `0`.
- `OLLAMA_KV_CACHE_TYPE`: `f16` (default), `q8_0` (about half the KV memory, usually no noticeable quality impact, upstream's recommendation if not f16), `q4_0` (about a quarter, noticeable at long context). Requires flash attention; global for all models. Models with a high GQA count (for example Qwen2) can suffer more.
- Measure quality on your own prompts before moving to `q4_0`.

## 4. Keep-alive and loading

- Default idle unload is 5 minutes (`OLLAMA_KEEP_ALIVE`). Loading a large model takes seconds to minutes, so keep hot models loaded (`-1`) when memory allows and preload after start (`ollama run <m> ""`).
- `OLLAMA_LOAD_TIMEOUT` (5m) aborts stalled loads (slow disk, network share).
- Store models on a fast local disk; `OLLAMA_MODELS` points elsewhere.

## 5. Concurrency

- `OLLAMA_NUM_PARALLEL` raises throughput for several users but multiplies KV memory. Start at 1 to 2, test with `scripts/bench.sh`-style load from the `self-hosted-llms` skill, watch `ollama ps`.
- `OLLAMA_MAX_LOADED_MODELS=1` on a shared box stops a second model from taking memory another tool planned to use.
- `OLLAMA_MAX_QUEUE` caps waiting requests; clients get 503 beyond it.

## 6. Offload and backend

- Prefer one GPU for a model that fits (default). `OLLAMA_SCHED_SPREAD=1` only when needed.
- Reserve VRAM for the desktop or other apps: `OLLAMA_GPU_OVERHEAD` in bytes.
- Pick a smaller quantization or model before accepting CPU offload.
- CPU backend problems: `OLLAMA_LLM_LIBRARY=cpu_avx2` (fastest generic) or `cpu_avx`, `cpu` (experimental override).
- Vulkan on Linux needs `sudo setcap cap_perfmon+ep /usr/local/bin/ollama` (or root) for Ollama to read free VRAM; without it Ollama schedules with approximate model sizes.

## 7. Measure

`ollama run <model> --verbose "..."` prints load time, prompt eval rate and eval rate (tokens/s). For API calls, the final `/api/chat` and `/api/generate` response includes duration and eval counts (`eval_count`, `eval_duration`, `prompt_eval_count`, `total_duration`, `load_duration`); tokens/s = `eval_count / eval_duration x 1e9`.

```bash
curl -s http://127.0.0.1:11434/api/generate -d '{"model":"qwen3:8b","prompt":"Write 200 words about GPUs.","stream":false}' \
  | jq '{load_s:(.load_duration/1e9), prompt_tps:(.prompt_eval_count/(.prompt_eval_duration/1e9)), gen_tps:(.eval_count/(.eval_duration/1e9))}'
```

The `self-hosted-llms` skill ships a shared `bench.sh` for repeatable load tests against any OpenAI-compatible endpoint (point it at `http://127.0.0.1:11434/v1`).
