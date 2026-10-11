# IDE extensions: Cursor, Continue, Cline, Roo Code, Kilo Code

> Verified against Cursor help docs (bring your own API key), Continue v2.0.0-vscode docs, Cline v4.1.23 docs, Roo Code v3.54.0 docs, Kilo Code v7.8.8 docs, 2026-10-11

The first question for any editor integration: **does the request leave from the user's machine or from the vendor's cloud?** That decides whether `localhost` works.

| Extension | Request origin | API sent | Where models and capabilities are set |
|---|---|---|---|
| Cursor | Cursor's servers | OpenAI-style (custom keys, chat models only) | Cursor Settings > Models |
| Continue | User's machine | Chat Completions (`provider: openai`); Responses for some OpenAI model names | `~/.continue/config.yaml` |
| Cline | User's machine | Chat Completions ("OpenAI Compatible") | Provider settings > Model Configuration |
| Roo Code | User's machine | Chat Completions ("OpenAI Compatible") | Provider settings > Model Configuration |
| Kilo Code | User's machine | Chat Completions, Responses or Anthropic Messages (selectable) | Providers tab, or `kilo.json` |

## Cursor

### What it is and when to choose it

VS Code-based editor with built-in models. Bring-your-own keys exist for OpenAI, Anthropic, Google, Azure OpenAI and AWS Bedrock. Choose it for a self-hosted model only if the endpoint can be public.

### Config location

Cursor Settings > Models: provider API keys, and the OpenAI base URL override with a custom model name added to the model list.

### Minimal config

1. Expose the gateway on public HTTPS with a virtual key (for example `https://llm.example.com/v1`), or a tunnel to it.
2. Cursor Settings > Models > OpenAI API key: paste the virtual key, enable the base URL override and set it to the public URL.
3. Add the gateway alias (for example `coder`) as a custom model and select it in chat.

### Capability flags

None exposed for custom models. Cursor decides tool use and context handling itself.

### Pitfalls

- Official docs: all requests are routed through Cursor's servers for final prompt building, and the key is sent with every request. So `localhost`, `127.0.0.1`, LAN and VPN-only addresses cannot work.
- Custom keys only apply to chat models; Tab completion keeps using Cursor's own models.
- Zero Data Retention does not apply to requests made with your own keys.
- The base URL override applies to all OpenAI-family models at once; built-in OpenAI model names will also be sent to your endpoint. (from Cursor staff answers on the community forum; not in the official docs, unverified)
- The override field label and behaviour change between Cursor releases; re-check after updates. (unverified)
- Give the public endpoint its own virtual key with a budget and model allowlist; never expose the gateway master key.

## Continue

### What it is and when to choose it

Open-source extension for VS Code and JetBrains (plus the `cn` CLI). Calls go out from the editor, so local endpoints work. Strong choice when you want chat, edit and autocomplete roles on different models.

### Config location

`~/.continue/config.yaml` (YAML, `schema: v1`). `config.json` is deprecated.

### Minimal config

```yaml
name: Local gateway
version: 1.0.0
schema: v1
models:
  - name: Coder (gateway)
    provider: openai
    model: coder
    apiBase: https://llm.example.com/v1
    apiKey: ${{ secrets.LITELLM_API_KEY }}
    roles: [chat, edit, apply]
    capabilities: [tool_use]
    defaultCompletionOptions:
      contextLength: 131072
      maxTokens: 8192
```

Template: `templates/continue-config.yaml`.

### Capability flags

- `capabilities`: `tool_use`, `image_input`. You can only add capabilities; Continue's autodetection by provider and model name still applies on top.
- `defaultCompletionOptions`: `contextLength`, `maxTokens`, `temperature`, `reasoning`, `reasoningBudgetTokens`.
- `requestOptions`: `timeout`, `headers`, `extraBodyProperties`, `verifySsl`, `caBundlePath`.
- `useResponsesApi: false` forces `/chat/completions` for model names Continue would otherwise send to `/responses`.

### Pitfalls

- `${{ secrets.NAME }}` is resolved from workspace `.env`, workspace `.continue/.env`, `~/.continue/.env`, then process env. The IDE extensions cannot read shell exports; put the key in `~/.continue/.env` (never in a committed workspace `.env`).
- A gateway alias that looks like an OpenAI reasoning model name can trigger the Responses API; rename the alias or set `useResponsesApi: false`.
- Tools never offered in agent mode: add `tool_use` to `capabilities`.

## Cline

### What it is and when to choose it

Autonomous coding agent extension for VS Code. Requests leave from the editor.

### Config location

Extension settings panel: API Provider "OpenAI Compatible".

### Minimal config

Base URL `https://llm.example.com/v1` (or `http://127.0.0.1:4000/v1`), API Key: a per-tool virtual key, Model ID: the gateway alias.

### Capability flags

Model Configuration: Max Output Tokens, Context Window size, Image Support, Computer Use (for models with tool/function calling), plus optional prices.

### Pitfalls

- Set Context Window and Max Output Tokens explicitly for every non-catalog model; otherwise Cline works from defaults that rarely match a local model.
## Roo Code

### What it is and when to choose it

Cline fork with modes. The GitHub repository was archived in May 2026; it still works but receives no fixes. Prefer Kilo Code or Cline for new setups.

### Config location

Extension settings: API Provider "OpenAI Compatible".

### Minimal config

Same fields as Cline: Base URL, API Key, Model ID.

### Capability flags

Model Configuration: Max Output Tokens, Context Window, Image Support, Computer Use.

### Pitfalls

- Archived project: new API features (for example new reasoning fields) will not be added.

## Kilo Code

### What it is and when to choose it

Agent extension for VS Code plus a CLI, sharing one config format. The only extension here that lets you pick the wire API per provider.

### Config location

UI: Providers tab > Custom provider. CLI and advanced settings: `~/.config/kilo/kilo.json` or project `kilo.json`, same `provider` shape as OpenCode.

### Minimal config

Custom provider dialog: Provider ID (`gateway`), Display name, Provider API (OpenAI Compatible, OpenAI Responses or Anthropic Messages), Base URL, API key, Models (auto-fetched from `/v1/models` or added manually), optional Headers.

```json
{
  "provider": {
    "gateway": {
      "npm": "@ai-sdk/openai-compatible",
      "env": ["LITELLM_API_KEY"],
      "options": { "baseURL": "https://llm.example.com/v1" },
      "models": { "coder": { "name": "Coder", "limit": { "context": 131072, "output": 16384 } } }
    }
  }
}
```

### Capability flags

Per model in `kilo.json`: `limit.context`, `limit.output`, tool calling and variants (see the Custom Models guide). Omitted limits default to `0`, which limits context management.

### Pitfalls

- Auto-fetch lists every model the key can see; trim to the aliases you want.
- `npm` defaults to `@ai-sdk/openai-compatible`; use `@ai-sdk/anthropic` for an Anthropic Messages endpoint.

## Verify any extension

Ask the agent to create a file with specific content. That forces a tool call through the same path the extension uses. Watch the gateway log for the request path (`/v1/chat/completions`, `/v1/responses`, `/v1/messages`) and the model name it actually sent.

## Official links

- Cursor bring your own API key: https://cursor.com/help/models-and-usage/api-keys
- Continue config.yaml reference: https://docs.continue.dev/reference
- Continue model capabilities: https://docs.continue.dev/customize/deep-dives/model-capabilities
- Continue FAQ (secrets and .env lookup): https://docs.continue.dev/faqs
- Continue OpenAI provider: https://docs.continue.dev/customize/model-providers/top-level/openai
- Cline OpenAI Compatible: https://docs.cline.bot/provider-config/openai-compatible
- Roo Code OpenAI Compatible: https://roocodeinc.github.io/Roo-Code/providers/openai-compatible
- Kilo Code OpenAI Compatible: https://kilo.ai/docs/ai-providers/openai-compatible
- Release pages: https://github.com/continuedev/continue/releases, https://github.com/cline/cline/releases, https://github.com/RooCodeInc/Roo-Code/releases, https://github.com/Kilo-Org/kilocode/releases
