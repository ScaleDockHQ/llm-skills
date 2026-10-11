# Ollama behind llama-swap

> Verified against Ollama v0.40.3 and llama-swap v263, 2026-10-11

Config keys were checked against the llama-swap `config-schema.json`. The operating pattern is carried from this repo's earlier engine notes on a DGX Spark and was not re-run here.

Both Ollama and llama-swap schedule models (keep-alive timers, max loaded models, queueing versus swap groups, `ttl`). Two schedulers over one memory pool fight. Pick one pattern.

## Pattern 1: one Ollama instance per llama-swap model ID (recommended)

llama-swap starts a dedicated Ollama for the model with `OLLAMA_MAX_LOADED_MODELS=1` and `OLLAMA_KEEP_ALIVE=-1`; llama-swap's groups, `ttl` and swaps decide lifetime. Several IDs can share one store if every instance sets `OLLAMA_NOPRUNE=1`.

Start script (adapt to your wrapper; shown as a shell function body):

```bash
docker run -d --name "$MODEL_ID" --gpus=all -p "127.0.0.1:${PORT}:11434" -v /srv/ollama:/root/.ollama \
  -e OLLAMA_MAX_LOADED_MODELS=1 -e OLLAMA_KEEP_ALIVE=-1 -e OLLAMA_NOPRUNE=1 \
  -e OLLAMA_CONTEXT_LENGTH=32768 -e OLLAMA_NUM_PARALLEL=2 \
  ollama/ollama:0.40.3
```

llama-swap entry (keys `cmd`, `cmdStop`, `proxy`, `checkEndpoint`, `useModelName`, `ttl` exist in the llama-swap schema):

```yaml
models:
  ollama-qwen3:
    cmd: /opt/llm-stack/start-model.sh run ollama-qwen3 ${PORT}
    cmdStop: /opt/llm-stack/start-model.sh stop ollama-qwen3
    proxy: http://127.0.0.1:${PORT}
    checkEndpoint: /api/version
    useModelName: qwen3:8b # the name Ollama knows the model by
    ttl: 600
```

- `/api/version` answers as soon as the server is up and loads nothing, so the first real request pays the model load. Warm it after start: `curl -s http://127.0.0.1:$PORT/api/generate -d '{"model":"qwen3:8b"}'`.
- Use the Ollama model name in `useModelName`; OpenAI requests carry that name.

## Pattern 2: one persistent Ollama with a fixed memory slice

Run it as its own service outside llama-swap and size it so its worst case fits beside your llama-swap groups: `OLLAMA_MAX_LOADED_MODELS`, `OLLAMA_CONTEXT_LENGTH`, `OLLAMA_NUM_PARALLEL`, `OLLAMA_KEEP_ALIVE`. Point the gateway straight at it (`api_base: http://127.0.0.1:11434/v1`, `model: openai/qwen3:8b` in LiteLLM). Never let llama-swap swap exclusive models into memory Ollama believes it owns.

## Pitfalls

- Default Ollama keeps up to three models for five minutes each; on a shared unified-memory box that silently eats what llama-swap planned for an exclusive model.
- When memory is short Ollama queues instead of failing; behind a short proxy timeout (125 s in the earlier setup) that looks like a hang.
- The OpenAI API cannot set the context; put `OLLAMA_CONTEXT_LENGTH` in the start script or use a Modelfile-derived model.
- Chain: client -> LiteLLM -> llama-swap -> Ollama. Keep keys in LiteLLM only; Ollama has none.

Companion skills: `llama-swap`, `litellm`, `nvidia-dgx-spark` (`npx skills add ScaleDockHQ/llms-skills --skill llama-swap`).
