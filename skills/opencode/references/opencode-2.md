# OpenCode 2: custom providers and local discovery

> Verified against OpenCode 2 docs (v2.opencode.ai: providers, models, intro; GitHub latest release is still v1.19.0), 2026-10-11

OpenCode 2 is a separate generation that shares the `opencode` command with OpenCode 1; the two cannot be installed side by side under the default command, and the v1 install script can replace a v2 install. Its config differs from v1. Check which you have (`opencode --version`; discovery in `SKILL.md`) before editing. I could not read the "Migrate from V1" page (it returned no text), so migration details are not documented here; follow upstream.

## Install (v2)

| Method   | Command                                                                |
| -------- | ---------------------------------------------------------------------- |
| Script   | `curl -fsSL https://opencode.ai/v2/install \| bash`                    |
| Homebrew | `brew install anomalyco/tap/opencode-v2`                               |
| npm      | `npm install -g @opencode/cli` (postinstall selects the native binary) |
| Docker   | `ghcr.io/anomalyco/opencode:<version>` versioned tags                  |

Windows package managers are not supported for v2 CLI; web UI via `opencode pair`.

## Config differences (v2 vs v1)

| Concept            | v1                                      | v2                                                                   |
| ------------------ | --------------------------------------- | -------------------------------------------------------------------- |
| Providers key      | `provider`                              | `providers`                                                          |
| Package field      | `npm: "@ai-sdk/openai-compatible"`      | `package: "@opencode/ai/providers/openai-compatible"`                |
| Endpoint and key   | `options.baseURL`, `options.apiKey`     | `settings.baseURL`, `settings.apiKey` (`{env:NAME}`)                 |
| Credential env     | `{env:NAME}` in `apiKey`                | also `env: ["NAME", ...]` ordered credential variables               |
| Model ID sent      | `id`                                    | `modelID` (key is the catalog ID)                                    |
| Capabilities       | `tool_call`, `attachment`, `modalities` | `capabilities: { tools, input, output }`                             |
| Reasoning field    | `interleaved.field`                     | `compatibility.reasoningField`                                       |
| Extra request data | `options`, `headers`                    | `headers`, `body` (merged into request bodies), per model or variant |
| Variants           | object keyed by name                    | array of `{ id, ... }`; selected with `provider/model#variant`       |

Native packages include `@opencode/ai/providers/openai`, `openai/chat`, `openai/responses`, `openai-compatible`, `openai-compatible/responses`, `anthropic`, `anthropic-compatible`, `google`, `azure`, `amazon-bedrock`, `openrouter`, `xai`. Use `anthropic-compatible` for an Anthropic-format self-hosted endpoint and `openai-compatible` for chat completions.

## Custom OpenAI-compatible provider (v2)

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "model": "local/coder",
  "providers": {
    "local": {
      "name": "Local server",
      "package": "@opencode/ai/providers/openai-compatible",
      "settings": {
        "baseURL": "http://HOST:PORT/v1",
        "apiKey": "{env:LOCAL_LLM_API_KEY}",
      },
      "models": {
        "coder": {
          "modelID": "model-name-on-server",
          "capabilities": {
            "tools": true,
            "input": ["text"],
            "output": ["text"],
          },
          "limit": { "context": 131072, "output": 16384 },
        },
      },
    },
  },
}
```

For a model not in the catalog, v2 assumes tools, text and image input, text output, a 200,000-token context and a 32,000-token output limit. These are fallbacks, not detections: set real `capabilities` and `limit`. Omit `apiKey` for keyless endpoints. Do not commit secrets.

## Local auto-discovery

v2 discovers models at default local addresses and reads capabilities from them:

| Engine    | Default address          | Provider ID | What discovery reads                                                                                                                                                   |
| --------- | ------------------------ | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ollama    | `http://127.0.0.1:11434` | `ollama`    | Context, vision and tool-use capabilities from the native Ollama API; embedding models excluded.                                                                       |
| LM Studio | `http://127.0.0.1:1234`  | `lmstudio`  | Context, vision and tool-use capabilities; embedding models excluded.                                                                                                  |
| vLLM      | `http://127.0.0.1:8000`  | `vllm`      | `/health`, `/v1/models`, `max_model_len` as the context limit. Does not report tools or vision: tool flags on the server are not visible, so set capabilities by hand. |

Other host or port: `providers.<id>.settings.baseURL` (OpenAI-compatible URL, ending `/v1`) plus `apiKey` with `{env:...}` when authenticated. Disable discovery with `"plugins": ["-opencode.provider.ollama"]` (or `lmstudio`, `vllm`). Path-prefixed proxies work (`https://host/vllm/v1` checks `/vllm/health`). Selecting: `"model": "ollama/gemma3:4b"`, `"model": "vllm/<model id>"`.

## Timeouts

Defaults: five minutes for response headers and five minutes between streamed chunks. Per provider `settings.headerTimeout`, `settings.chunkTimeout`, `settings.timeout` (ms, or `false` to disable the first two; `timeout` has no default). A timed-out request is retried up to three times.

## Model references

`provider/model` with optional `#variant`; provider ends at the first `/`, model may contain more `/`. Case-sensitive. Root, agent and command `model` fields accept this string or `{ "providerID": "...", "model": "..." }`.

## Overriding an existing provider's endpoint

```jsonc
{
  "providers": {
    "anthropic": {
      "settings": { "baseURL": "https://llm-proxy.example.com/anthropic" },
    },
  },
}
```

keeps the provider's package and models and sends traffic through your proxy; `headers` and `body` add tenant headers or JSON fields.
