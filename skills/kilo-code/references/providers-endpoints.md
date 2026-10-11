# Kilo Code: custom providers and kilo.jsonc

> Verified against Kilo Code v7.8.8 (kilo.ai/docs custom provider, custom models, Ollama, LM Studio pages; repository README), 2026-10-11

## What it is and when to choose it

Kilo Code is an agent for VS Code, JetBrains and a CLI that share one config format. Requests leave from your machine (extension host or CLI), so local, LAN, VPN and Tailscale endpoints work. It is the one editor client here that lets you choose the wire API per provider.

## Install

See `install.md`. Config files: global `~/.config/kilo/kilo.jsonc` (or `kilo.json`) and project `./kilo.jsonc` (or `kilo.json`). The VS Code extension stores UI changes in the same `kilo.json`.

## Minimal working config

### In the extension

Settings (gear) > Providers > scroll to the bottom > Custom provider:

| Field        | Value                                                                                                                                                            |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Provider ID  | Lowercase letters, digits, hyphens, underscores (for example `gateway`); becomes `provider_id` in `provider_id/model_id`                                         |
| Display name | Label in the UI                                                                                                                                                  |
| Provider API | OpenAI Compatible (Chat Completions, default), OpenAI Responses (OpenAI and xAI models), Anthropic Messages (Anthropic and MiniMax models)                       |
| Base URL     | `https://llm.example.com/v1`; Kilo auto-fetches models from `/v1/models` when the URL is valid. A full endpoint URL (`.../v1/chat/completions`) is also accepted |
| API key      | Optional; leave empty if authentication is handled by headers                                                                                                    |
| Models       | Pick from the auto-fetched list (fuzzy search), add by id and name, or press Fetch models to retry                                                               |
| Headers      | Optional custom HTTP headers (key-value)                                                                                                                         |

Submit, then edit the config file for limits and tool calling (the dialog does not expose them).

### In kilo.jsonc

```jsonc
{
  "model": "gateway/coder",
  "provider": {
    "gateway": {
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "https://llm.example.com/v1",
        "apiKey": "{env:LLM_API_KEY}",
      },
      "models": {
        "coder": {
          "name": "Coder",
          "tool_call": true,
          "limit": { "context": 65536, "output": 8192 },
        },
      },
    },
  },
}
```

Full template with Anthropic and Ollama blocks: `assets/kilo.jsonc`. At least one model must be defined for a custom provider.

## Wire API and `npm`

| Endpoint speaks         | `npm`                       | Notes                                                                    |
| ----------------------- | --------------------------- | ------------------------------------------------------------------------ |
| OpenAI Chat Completions | `@ai-sdk/openai-compatible` | Default when omitted; vLLM, llama.cpp, LiteLLM, llama-swap, Ollama `/v1` |
| OpenAI Responses        | `@ai-sdk/openai`            | Only if the endpoint implements `/v1/responses`                          |
| Anthropic Messages      | `@ai-sdk/anthropic`         | For an Anthropic-style gateway route                                     |

For the Anthropic style, `baseURL` form (with or without `/v1`) is not spelled out in the pages read; the AI SDK Anthropic provider normally takes a URL ending in `/v1`. Test with the probe and the gateway log.

## Key handling

- `options.apiKey` may be a literal, `{env:VAR}` or `{file:path}`; or list variables in `"env": ["MY_KEY"]` on the provider.
- `{env:VAR}` and `{file:...}` resolve only in trusted config: global config (`~/.config/kilo`), `KILO_CONFIG` / `KILO_CONFIG_CONTENT`, or managed config. In a repository's `kilo.json` `{env:}` is ignored (a warning is logged) so the provider will not authenticate; `{file:...}` works there only for files inside the project root. Keep provider credentials in global config.
- If the endpoint needs no key, any non-empty string (for example `"none"`) works.
- `kilo auth login --provider <id>` and `/connect` in the TUI store credentials for built-in providers; `kilo auth logout` removes them.

## Model-name mapping

The key under `models` is what you reference (`provider_id/model_id`); `id` is the API-facing name sent to the endpoint and defaults to the key. Example: key `my-llama`, `id: "meta-llama-3.1-8b-instruct"`. If a model's key equals an entry in the built-in catalog (models.dev snapshot, refreshed hourly), your fields merge over the catalog defaults.

## Model fields

`name`, `id`, `tool_call`, `reasoning`, `temperature`, `attachment`, `modalities {input, output}` (`text`, `image`, `audio`, `video`, `pdf`; omit means text only for unknown models), `limit {context, output, input?}`, `cost`, `options`, `headers`, `provider {npm?, api?}`, `variants`.

Limits resolve in order: your config, then the catalog, then `0`. With `0`:

- compaction is disabled and conversations grow until the provider rejects them;
- output falls back to 32,000 tokens (`KILO_EXPERIMENTAL_OUTPUT_TOKEN_MAX`);
- context usage tracking is skipped.

Output is capped at 32,000 by default. If a response stops at `limit.output`, Kilo shows a warning; for reasoning models that spend the whole budget on reasoning, disable reasoning or raise `limit.output`.

## Provider options

`apiKey`, `baseURL`, `timeout` (ms, default 300000, covers waiting for headers and the first body byte, `false` disables), `chunkTimeout` (ms between streamed chunks; 15000 to 30000 recommended for flaky streams). Filter models with `whitelist` and `blacklist`; hide built-in providers with `disabled_providers`.

## Ollama and LM Studio

Built-in providers, no key needed:

```jsonc
{ "provider": { "ollama": { "baseURL": "http://localhost:11434/v1" } }, "model": "ollama/qwen3-coder:30b" }
{ "provider": { "lmstudio": { "options": { "baseURL": "http://localhost:1234/v1" } } }, "model": "lmstudio/my-model" }
```

Docs write the Ollama `baseURL` at the provider level and the LM Studio one under `options`; use the shape shown for each. Local Ollama models use `ollama/<model_name>`; `ollama-cloud/...` is a hosted provider and does not connect to localhost. Set the Ollama "Context Window Size (num_ctx)" in the provider settings; Ollama truncates prompts by default and 32k is the documented minimum for decent results. The API request timeout setting (default 10 minutes in the Ollama guide) can be raised for slow local models.

## Tool calling and streaming caveats

- `tool_call: true` per model; without it agent tool use is not enabled for that model.
- Engines must return OpenAI-format `tool_calls`: vLLM `--enable-auto-tool-choice --tool-call-parser <name>`; llama.cpp `--jinja` with a tool-capable template; Ollama a tool-capable model. Kilo's Ollama guide warns local models "are much more likely to get stuck in loops, fail to use tools properly or produce syntax errors"; its own advice: keep conversations short and disable MCP tools for speed.
- Set `chunkTimeout` if a proxy drops SSE silently; otherwise the request hangs until `timeout`.
- Anthropic Messages providers also accept per-model `options` and `variants` (for example thinking budgets) for real Claude models; a gateway may ignore them.

## How it plugs into the stack

```text
Kilo (extension host or CLI) --> gateway or engine
```

## Operating

- `kilo models` lists models; `kilo debug config` prints the resolved configuration; `kilo debug paths` prints config, data, cache and state directories; `kilo serve --port 4096` starts a headless server.
- Model precedence: `--model/-m` flag, then config `model`, then last used, then the first available.

## Known pitfalls

- Limits unset: no compaction (see above).
- Project `kilo.json` with `{env:KEY}`: ignored; no auth. Move the provider to global config.
- Auto-fetch lists every model the key can see; trim with `whitelist`.
- `ollama/` vs `ollama-cloud/` prefix confusion.
- Azure GPT-5 on a custom provider fails with `max_tokens`; use the native `azure` provider and map the deployment name with `id`.

## Official links

- OpenAI compatible provider: https://kilo.ai/docs/ai-providers/openai-compatible
- Custom models: https://kilo.ai/docs/code-with-ai/agents/custom-models
- Ollama: https://kilo.ai/docs/ai-providers/ollama
- LM Studio: https://kilo.ai/docs/ai-providers/lmstudio
- Docs index for agents: https://kilo.ai/docs/llms.txt
- Repository: https://github.com/Kilo-Org/kilocode
