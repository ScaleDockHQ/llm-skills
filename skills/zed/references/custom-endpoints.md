# Zed: custom OpenAI- and Anthropic-compatible endpoints

> Verified against Zed v1.23.2 (docs: ai/use-api-access, ai/use-a-gateway, ai/llm-providers), 2026-10-11

Use these providers for any server that is not one of Zed's built-in providers: vLLM, llama.cpp `llama-server`, LiteLLM, llama-swap, a corporate gateway. For plain local Ollama, llama.cpp and LM Studio use `references/local-providers.md`.

## OpenAI Chat Completions: `openai_compatible`

Add in the UI (Agent Settings, LLM Providers, Add Provider, OpenAI) with provider name, API URL, model id and context window, or in `settings.json`:

```jsonc
{
  "language_models": {
    "openai_compatible": {
      "my-gateway": {
        "api_url": "http://localhost:4000/v1",
        "available_models": [
          {
            "name": "coder",
            "display_name": "Coder",
            "max_tokens": 131072,
            "max_output_tokens": 8192,
          },
        ],
      },
    },
  },
}
```

- `api_url`: the API root that serves `/chat/completions` and `/models`. For vLLM, LiteLLM, llama-swap and llama.cpp that is `http://HOST:PORT/v1`.
- `name`: sent as `model`. `display_name`: label only. `max_tokens`: context window. `max_output_tokens`: output cap.
- Provider id (`my-gateway`) becomes the env var `MY_GATEWAY_API_KEY` (upper snake case plus `_API_KEY`).
- Capabilities inherited by default: `tools` true, `images` false, `parallel_tool_calls` false, `prompt_cache_key` false, `chat_completions` true, `interleaved_reasoning` false, `max_tokens_parameter` false. Override per model under `capabilities`.
- Responses-only model: `capabilities.chat_completions: false` makes Zed call the Responses endpoint.
- Reasoning: `reasoning_effort` accepts `none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`; Zed sends it as OpenAI-style `reasoning_effort` on chat completions. Set `capabilities.interleaved_reasoning: true` when the endpoint expects prior thinking returned as `reasoning_content`.
- Output limit field: set `capabilities.max_tokens_parameter: true` if the server wants `max_tokens` instead of `max_completion_tokens` (older vLLM and llama.cpp builds behave this way; check by test).

## Anthropic Messages: `anthropic_compatible`

```jsonc
{
  "language_models": {
    "anthropic_compatible": {
      "My Anthropic Gateway": {
        "api_url": "http://localhost:4000",
        "custom_headers": { "X-Team": "platform" },
        "available_models": [
          {
            "name": "coder",
            "display_name": "Coder",
            "max_tokens": 131072,
            "max_output_tokens": 8192,
            "capabilities": {
              "tools": true,
              "images": false,
              "prompt_caching": false,
            },
          },
        ],
      },
    },
  },
}
```

- Use when the endpoint implements `/v1/messages` (LiteLLM, llama-swap, vLLM, llama.cpp). Zed sends `X-Api-Key` and `Anthropic-Version` itself; those cannot be overridden.
- The documented example `api_url` has no `/v1`; Zed adds the path. Confirm in the server log that requests hit `/v1/messages`, and adjust if you see `/v1/v1/messages` or 404.
- `prompt_caching: true` adds explicit `cache_control` breakpoints; leave it off if the server rejects them. Optional model fields: `default_temperature`, `extra_beta_headers`, `mode` (thinking budget), `tool_override`.
- Env var: provider name upper snake case plus `_API_KEY` (`My Anthropic Gateway` becomes `MY_ANTHROPIC_GATEWAY_API_KEY`).

## Which shape to pick

| Endpoint                            | Prefer                     | Why                                                                 |
| ----------------------------------- | -------------------------- | ------------------------------------------------------------------- |
| vLLM, llama.cpp, LM Studio, LocalAI | `openai_compatible`        | Native shape, widest parser support                                 |
| LiteLLM, llama-swap                 | either                     | Both shapes are served; pick by feature (thinking blocks: Messages) |
| Gateway that only proxies Anthropic | `anthropic_compatible`     | Keeps thinking and caching semantics                                |
| Ollama                              | built-in `ollama` provider | Zed discovers models and sets `num_ctx`                             |

## Auth and headers

- Keys: Agent Settings stores them in the system keychain. Env var overrides when non-empty.
- Servers started with `--api-key` (vLLM, llama.cpp) expect `Authorization: Bearer`; the key you enter is sent that way for OpenAI-compatible providers.
- Extra headers (gateway tenant ids, tracing tags): `language_models.<provider>.custom_headers`, supported on OpenAI-compatible, Anthropic-compatible and most built-in providers. Zed-managed headers (`Authorization`, `Content-Type`, `Accept`, provider auth headers) are ignored with a warning if overridden. For OpenAI-compatible providers the headers go under that provider's entry as shown in the docs for `openai`; confirm placement with a request log.
- Do not put keys in `settings.json` or `.zed/settings.json`.

## Test before blaming Zed

```bash
B=http://localhost:4000/v1
curl -fsS "$B/models" -H "Authorization: Bearer $KEY" | jq -r '.data[].id'
curl -fsS "$B/chat/completions" -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  -d '{"model":"coder","messages":[{"role":"user","content":"ping"}],"stream":true}' | head -5
# Messages shape
curl -fsS "${B%/v1}/v1/messages" -H "x-api-key: $KEY" -H 'anthropic-version: 2023-06-01' -H 'Content-Type: application/json' \
  -d '{"model":"coder","max_tokens":32,"messages":[{"role":"user","content":"ping"}]}' | jq .type
```

`$KEY` comes from the environment; never paste it into commands that are logged.

## Official links

- Use API Access (compatible endpoints, keys, headers): https://zed.dev/docs/ai/use-api-access
- Use a Gateway: https://zed.dev/docs/ai/use-a-gateway
- LLM Providers overview: https://zed.dev/docs/ai/llm-providers
