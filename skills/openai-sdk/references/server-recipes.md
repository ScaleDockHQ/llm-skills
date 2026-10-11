# OpenAI SDK recipes per self-hosted server

> Verified against openai-python v3.28.0, openai-node v7.32.0, vLLM docs, llama.cpp server README, Ollama OpenAI-compatibility docs, llama-swap README, LiteLLM docs, 2026-10-11

Ports below are defaults of each tool; yours may differ. Replace hosts with yours. `LLM_API_KEY` comes from a `0600` file, never inline.

| Server                   | `base_url`                     | Key                                           | Model string                                    |
| ------------------------ | ------------------------------ | --------------------------------------------- | ----------------------------------------------- |
| vLLM                     | `http://host:8000/v1`          | `--api-key` value (Bearer) or none            | `--served-model-name`, else the repo id or path |
| llama.cpp `llama-server` | `http://host:8080/v1`          | `--api-key` / `--api-key-file` value, or none | `--alias`; by default the model file path       |
| Ollama                   | `http://host:11434/v1/`        | any string (`ollama` in the docs), ignored    | the tag, for example `qwen3:8b`                 |
| LiteLLM proxy            | `http://host:4000` or `.../v1` | virtual key or master key (Bearer)            | the `model_name` alias in its config            |
| llama-swap               | `http://host:8080/v1`          | optional, per its config                      | the model id (or alias) from its config         |

Discover ids: `curl -fsS -H "Authorization: Bearer $LLM_API_KEY" http://host:PORT/v1/models | jq -r '.data[].id'` (omit the header on keyless servers). `scripts/check-endpoint.sh` does this and probes chat, tools and streaming.

## vLLM

```bash
vllm serve <model> --served-model-name coder --api-key "$(cat ~/.config/llm/key)" \
  --enable-auto-tool-choice --tool-call-parser <parser>      # parser per model family
```

Note the `--api-key` value is visible in the process list; prefer the `VLLM_API_KEY` environment variable (an env var vLLM reads). vLLM checks `Authorization: Bearer` for OpenAI routes, which is what this SDK sends. Add `--reasoning-parser <name>` for reasoning models. Supports Chat Completions, Responses, embeddings.

## llama.cpp

```bash
llama-server -m model.gguf --alias coder --api-key-file ~/.config/llm/keys --port 8080
```

Tool calling uses `--jinja`, enabled by default in current builds. The model `id` defaults to the model path, so set `--alias` or read `/v1/models`. Supports `/v1/chat/completions`, `/v1/responses` and `/v1/messages`.

## Ollama

Keep `localhost:11434` on loopback or behind a gateway: it has no key check of its own. Pass a placeholder key. Supported: chat, completions, embeddings, models, tools, `stream_options`, vision; `tool_choice` is not supported. The Ollama cloud endpoint (`https://ollama.com/v1`) takes a real key in `OLLAMA_API_KEY`.

## LiteLLM proxy

Use a virtual key per app so spend and model access are limited and revocable. Models are exposed under the config `model_name`, which also hides backend renames. LiteLLM serves `/v1/chat/completions` and `/v1/embeddings`, and bridges Responses and Messages routes (probe `/v1/responses` to confirm for your version). Errors from backends surface with the backend's message; check the proxy log for the real cause.

## llama-swap

Requests load the model named in the body, swapping engines on demand, so the first call after a swap is slow: raise the SDK timeout or warm the model. Use `/v1/models` to get valid ids.

## Behind a reverse proxy

- Keep path prefixes in `base_url`: `https://llm.example.com/openai/v1`.
- Disable response buffering for SSE; raise idle timeouts above model load time.
- With basic auth or SSO in front, the SDK's Bearer header may collide: pass the front-door credentials as an extra header and keep the app key in `Authorization`, or terminate the front door in the gateway.

## Official links

- vLLM OpenAI-compatible server: https://docs.vllm.ai/en/latest/serving/openai_compatible_server.html
- llama.cpp server: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- Ollama OpenAI compatibility: https://docs.ollama.com/api/openai-compatibility
- LiteLLM proxy: https://docs.litellm.ai/docs/simple_proxy
- llama-swap: https://github.com/mostlygeek/llama-swap
