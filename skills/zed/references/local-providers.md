# Zed: built-in Ollama, llama.cpp and LM Studio providers

> Verified against Zed v1.23.2 (docs: ai/use-a-local-model), 2026-10-11

Use these when the engine runs on this machine or on a host you control and Zed's built-in provider fits. They auto-discover models, unlike generic `openai_compatible`.

## Ollama

```jsonc
{
  "language_models": {
    "ollama": {
      "api_url": "http://localhost:11434",
      "context_window": 32768,
      "auto_discover": true,
    },
  },
}
```

- Zed lists pulled models automatically. Set `auto_discover: false` and list `available_models` (`name`, `display_name`, `max_tokens`, `supports_tools`, `supports_thinking`, `supports_images`) to control the list.
- Context: Zed sends `num_ctx`; the default is 4096. Raise it with `context_window` for all models or `max_tokens` per model, or agent threads truncate quickly.
- Remote or authenticated Ollama (including Ollama's hosted service): set `api_url` to that endpoint and the key in the UI or `OLLAMA_API_KEY`.
- For a LAN host, Ollama must listen beyond loopback (`OLLAMA_HOST=0.0.0.0:11434`), which is unauthenticated; put a VPN or an authenticating proxy in front (`ollama` skill).

## llama.cpp (`llama-server`)

```jsonc
{
  "language_models": {
    "llama.cpp": {
      "api_url": "http://localhost:8080",
      "auto_discover": true,
      "context_window": 65536,
    },
  },
}
```

- Zed discovers models and reads context length and tool/vision capability from the server (`/props`); in router mode it refines them once a model loads via `/models/sse`, which needs a recent build. Set `auto_discover: false` with `available_models` to pin the list.
- `context_window` overrides the context for all models; per-model `max_tokens` overrides one.
- Server started with `--api-key`: enter the key in the UI or set `LLAMACPP_API_KEY`.
- Tools need `--jinja` and a chat template with tool support, set on the server (`llama-cpp` skill). Docs name the llama.cpp router mode as the way to serve several models.

## LM Studio

- Start the server (`lms server start`, default port 1234), load or `lms get` a model, then select it in Zed's dropdown. Key, if enabled in LM Studio: UI or `LMSTUDIO_API_KEY`.
- LM Studio also works through `openai_compatible` at `http://localhost:1234/v1` when you want explicit capabilities.

## vLLM, LiteLLM, llama-swap and others

Zed has no built-in provider for them. Use `openai_compatible` or `anthropic_compatible` (`references/custom-endpoints.md`).

## Remote machines

LLM providers run in the local Zed app. In SSH and dev-container projects, `localhost` in `api_url` is the machine running Zed, not the remote host; reach the remote engine through its LAN or tailnet address or an SSH port-forward on the local side.

## Official links

- Use a Local Model: https://zed.dev/docs/ai/use-a-local-model
- llama.cpp server README: https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
