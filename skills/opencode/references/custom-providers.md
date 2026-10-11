# OpenCode: custom providers (OpenCode 1 config)

> Verified against OpenCode v1.19.0 (docs: providers, config, models, network, cli; JSON schema opencode.ai/config.json), 2026-10-11

OpenCode builds providers from AI SDK packages. For self-hosted endpoints you declare a provider under `provider.<id>` in `opencode.json`, naming the package that speaks the endpoint's wire format. Config files merge (later wins on conflicting keys): remote `.well-known`, global `~/.config/opencode/opencode.json`, `OPENCODE_CONFIG`, project `opencode.json`, `.opencode/` dirs, `OPENCODE_CONFIG_CONTENT`, managed files.

## Pick the package

| Endpoint serves         | `npm` package               | Wire path                              |
| ----------------------- | --------------------------- | -------------------------------------- |
| OpenAI chat completions | `@ai-sdk/openai-compatible` | `/v1/chat/completions`                 |
| OpenAI Responses        | `@ai-sdk/openai`            | `/v1/responses`                        |
| Anthropic Messages      | `@ai-sdk/anthropic`         | `/v1/messages` (baseURL ends in `/v1`) |

A model on a provider can override the package with its own `provider.npm` (mixed endpoints under one provider). For chat-completions engines, which is nearly all of them, use `@ai-sdk/openai-compatible`.

## Minimal provider

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "local": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local engine",
      "options": {
        "baseURL": "http://HOST:PORT/v1",
        "apiKey": "{env:LOCAL_LLM_API_KEY}"
      },
      "models": {
        "qwen3-coder": {
          "name": "Qwen3 Coder",
          "limit": { "context": 131072, "output": 16384 },
          "tool_call": true
        }
      }
    }
  },
  "model": "local/qwen3-coder",
  "small_model": "local/qwen3-coder"
}
```

- The provider ID (`local`) is any string you choose; model refs are `<provider>/<model>`. A `/connect` credential must use the same provider ID.
- Each model key must equal the `id` returned by `GET /v1/models` (llama.cpp, Ollama tags, vLLM `--served-model-name`, llama-swap IDs). Use `id` inside the model entry to send a different string than the key.
- `limit.context` and `limit.output` are required in the schema (`input` optional). They are how OpenCode knows when to compact.
- Provider `options`: `baseURL`, `apiKey`, `headers` (static, string values), `timeout` (ms, whole request, or `false`), `chunkTimeout` (ms between SSE chunks, default 300000), `setCacheKey` (prompt cache key, default false).

## Key handling without printing secrets

| Method                                     | Where the key lives                 | Notes                                                                                           |
| ------------------------------------------ | ----------------------------------- | ----------------------------------------------------------------------------------------------- |
| `"apiKey": "{env:NAME}"`                   | Process environment                 | Export from a shell profile or launcher reading a `0600` file.                                  |
| `"apiKey": "{file:~/.secrets/llm-key}"`    | A file (`chmod 600`)                | Substitution reads the file contents at load time.                                              |
| `/connect` then Other                      | `~/.local/share/opencode/auth.json` | Stores the key only; you still write the provider block. `opencode auth list` shows names only. |
| `headers: {"Authorization": "Bearer ..."}` | The config file                     | Avoid for secrets; use `{env:...}` inside the string if the header is needed.                   |

Do not commit keys. A project `opencode.json` is meant to be committed; keep only `{env:...}` references in it. For keyless local engines omit `apiKey` entirely.

## Responses and Anthropic variants

```json
{
  "provider": {
    "gateway-responses": {
      "npm": "@ai-sdk/openai",
      "options": {
        "baseURL": "http://HOST:PORT/v1",
        "apiKey": "{env:GATEWAY_KEY}"
      },
      "models": {
        "coder": {
          "limit": { "context": 131072, "output": 16384 },
          "tool_call": true
        }
      }
    },
    "gateway-anthropic": {
      "npm": "@ai-sdk/anthropic",
      "options": {
        "baseURL": "http://HOST:PORT/v1",
        "apiKey": "{env:GATEWAY_KEY}"
      },
      "models": {
        "claude-local-coder": {
          "limit": { "context": 131072, "output": 16384 },
          "tool_call": true
        }
      }
    }
  }
}
```

The docs show `options.baseURL` overriding a built-in Anthropic provider as `https://api.anthropic.com/v1`, so Anthropic-format baseURLs include `/v1`. Whether `@ai-sdk/anthropic` against a local engine sends `x-api-key` (the AI SDK default) rather than a bearer token was not tested; if the endpoint needs Bearer, use `headers`.

## Per engine

Engine flags and versions belong to the engine skills; this is what OpenCode needs.

| Endpoint   | `baseURL`                   | Key                | Notes                                                                                                                                                                      |
| ---------- | --------------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| vLLM       | `http://HOST:PORT/v1`       | `--api-key` value  | `--enable-auto-tool-choice --tool-call-parser <name>` for tools; `--served-model-name` for the key; `--max-model-len` = `limit.context`.                                   |
| llama.cpp  | `http://HOST:PORT/v1`       | `--api-key` if set | Official docs example uses provider `llama.cpp` with limits context 128000 / output 65536. `--jinja` for tools; `-c` = `limit.context`.                                    |
| Ollama     | `http://localhost:11434/v1` | none locally       | Docs tip: if tool calls fail, raise `num_ctx` (start 16k-32k); better `OLLAMA_CONTEXT_LENGTH` of 64k+. Ollama can also configure itself for OpenCode (see skill `ollama`). |
| llama-swap | `http://HOST:PORT/v1`       | `apiKeys` entry    | Model keys = llama-swap IDs; cold swap needs a longer `chunkTimeout`/`timeout`.                                                                                            |
| LiteLLM    | `http://HOST:4000/v1`       | virtual key        | Model keys = `model_name` aliases. See `combos/litellm-gateway.md`.                                                                                                        |

## Verify

```bash
OPENCODE_BASE_URL=http://HOST:PORT/v1 OPENCODE_MODEL=qwen3-coder OPENCODE_KEY_ENV=LOCAL_LLM_API_KEY scripts/check-endpoint.sh
opencode models local          # lists local/<model> entries as OpenCode sees them
opencode run -m local/qwen3-coder "say ok"
```

Templates: `templates/opencode.json`.

## Proxies and certificates

OpenCode honors `HTTPS_PROXY` and `HTTP_PROXY`; set `NO_PROXY=localhost,127.0.0.1` because the TUI talks to a local HTTP server (without it you get routing loops). Private CA: `NODE_EXTRA_CA_CERTS=/path/ca.pem`. Do not hardcode proxy passwords; use environment variables.
