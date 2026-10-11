# Benchmarking a local model

> Verified against scripts/bench.sh interface (shared with self-hosted-llms), llama.cpp b11555 (`llama-bench`), mlx-lm 0.32.0 (`mlx_lm.benchmark`), 2026-10-11

Measure before and after every change: a new runtime, quant, context size, flag, or driver. Laptop numbers swing a lot with thermals and power state, so a fixed protocol matters more than any single run.

## The tool: `scripts/bench.sh`

```
scripts/bench.sh --base-url URL --model NAME [--runs N] [--warmup N] [--max-tokens N]
                 [--prompt-tokens N] [--concurrency N] [--key-file PATH] [--timeout SECONDS]
```

- Environment fallbacks: `LLM_BASE_URL`, `LLM_MODEL`, `LLM_API_KEY`.
- Requires `curl` and `jq`. Bash 3.2-compatible, so it runs on stock macOS.
- Reports per run and the median of: **TTFB** (time to first response byte, which approximates time to first token), **decode tok/s** (completion tokens / (total - TTFB)), **prefill tok/s** (only with `--prompt-tokens`; a cold run with a unique prefix and a warm run with an identical prompt), and **aggregate tok/s** (only with `--concurrency N` above 1). Defaults: `--runs 5`, `--warmup 1`, `--max-tokens 256`, `--timeout 600`; `--help` lists everything.
- Talks to any OpenAI-compatible `/v1/chat/completions`, so the same command works for every runtime.

Base URLs:

| Runtime | `--base-url` | `--model` |
| --- | --- | --- |
| Ollama | `http://127.0.0.1:11434/v1` | the tag, e.g. `qwen3:8b` |
| LM Studio | `http://127.0.0.1:1234/v1` | the model key or the `--identifier` you loaded it with |
| llama-server | `http://127.0.0.1:9931/v1` | the `-a` alias (or the name from `/v1/models`) |
| mlx_lm.server | `http://127.0.0.1:8080/v1` | the HF repo / path you started it with |

Use `--key-file ~/.config/llama-server/keys` (or `LLM_API_KEY`) for servers with auth. Never pass a key inline on the command line.

## Fixed protocol

1. **Same machine state:** on AC power, normal (not low-power) mode, lid open, other heavy apps closed. On a Mac, check `pmset -g therm`. On NVIDIA, check `nvidia-smi` for other processes.
2. **One server at a time.** Stop the other runtimes so they don't hold GPU memory (`ollama ps`, `lms ps`).
3. **Load the model first and confirm it's fully on the GPU** (`ollama ps` → `100% GPU`; llama-server log shows all layers offloaded; LM Studio estimate fits).
4. **Warm up:** `--warmup 2` (first-request compilation, page faults, prompt-cache population).
5. **Fixed shape:** the same `--prompt-tokens` and `--max-tokens` for every configuration you compare. Suggested set:
   - Chat: `--prompt-tokens 512 --max-tokens 256`
   - Agent/RAG: `--prompt-tokens 8192 --max-tokens 256` (this is where prefill matters)
6. **Enough runs:** `--runs 5` or more, and report the median.
7. **Concurrency:** start at `--concurrency 1`. Test 2–4 only if you serve several clients, and set the server's parallel slots to match (`-np`, `OLLAMA_NUM_PARALLEL`).
8. **Cool down** between configurations on fanless laptops (wait until the chip is back at idle temperature), or alternate A/B/A/B.
9. **Record everything:** runtime and version, model file and quant, context size, flags, OS and driver version, power state, date.

Example:

```bash
scripts/bench.sh --base-url http://127.0.0.1:9931/v1 --model local-model \
  --warmup 2 --runs 5 --prompt-tokens 512 --max-tokens 256
```

## Fair comparisons

- Compare the **same model at the same quant** across runtimes. GGUF Q4_K_M and MLX 4bit are not identical in size or quality, so say so when comparing them.
- Use the same context setting. A server with a 128k context reserves more KV cache and may offload layers that a 4k server keeps on the GPU.
- Sampling doesn't change speed much, but keep `temperature` fixed and make sure each run generates the full `--max-tokens` (models that stop early inflate tok/s). The script requests a fixed length; check that the reported token counts match.
- Engine-only tools measure something different from HTTP end to end: `llama-bench -m model.gguf -p 512 -n 128` and `mlx_lm.benchmark --model <repo> -p 2048 -g 128`. Use them to isolate the engine, and `bench.sh` for what clients will actually experience.

## Reading results

- **Decode tok/s** is bound by memory bandwidth. It drops with larger quants, longer context, and any CPU offload.
- **Prefill tok/s** is bound by compute. It matters for agents that send long prompts.
- **TTFB** ≈ queueing + prefill + first token. A high TTFB at a short prompt means the model is still loading (Ollama keep-alive expired, LM Studio JIT load, or llama-server `--sleep-idle-seconds` woke it).
- A big gap between runs means thermal throttling or a background process. Rerun after a cool-down.

## Official links

- llama-bench: https://github.com/ggml-org/llama.cpp/tree/master/tools/llama-bench
- mlx-lm benchmarks: https://github.com/ml-explore/mlx-lm/blob/main/mlx_lm/BENCHMARKS.md
- Ollama `ollama ps`: https://docs.ollama.com/faq
