# Chat UIs: Open WebUI, LobeHub

> Verified against Open WebUI v0.12.0 docs and LobeHub v2.2.19 docs (formerly LobeChat), 2026-10-11

Self-hosted chat UIs call the endpoint from their own server process, usually a container. Both speak OpenAI Chat Completions to custom endpoints and read `/v1/models` to list models. Neither learns context window, vision or tool support from a standard `/v1/models` response, so capabilities are set in the UI.

## Open WebUI

### What it is and when to choose it

Feature-rich multi-user chat UI with RAG, tools, model presets and per-user permissions. Choose it for a team chat front end in front of a gateway.

### Config location

- Admin UI: **Settings > Admin > Connections** (OpenAI API connections), **Workspace > Models** or **Settings > Admin > Models** (per-model capabilities and params).
- Env vars at first start. With `ENABLE_PERSISTENT_CONFIG=True` (default) values saved in the UI live in the database and win over env vars after first boot.

### Minimal config

UI: Settings > Admin > Connections > add an OpenAI connection with URL `http://host.docker.internal:4000/v1` (gateway on the Docker host) or `https://llm.example.com/v1`, the virtual key, then **Verify Connection**. Use the **Model IDs** allowlist to show only chosen aliases.

Env (first boot or `ENABLE_PERSISTENT_CONFIG=False`):

```bash
ENABLE_OPENAI_API=True
OPENAI_API_BASE_URLS=http://host.docker.internal:4000/v1
OPENAI_API_KEYS=<your-virtual-key>
```

`OPENAI_API_BASE_URLS` and `OPENAI_API_KEYS` are semicolon-separated and paired by position. On Linux, run the container with `--add-host=host.docker.internal:host-gateway`.

Template: `assets/open-webui.env.example`.

### Capability flags

- Per model, **Capabilities**: Vision, Web Search, Code Interpreter, File Upload, File Context, Builtin Tools, Usage (requests `stream_options.include_usage` so token counts show up), Citations.
- **Advanced Params**: temperature, max tokens, stop sequences, and **Function Calling**: Native (default since v0.10.0, uses the model's real tool calling) or Legacy (prompt-based, for models without tool calling). Switch weak local models to Legacy per model rather than globally.
- Global baselines: `DEFAULT_MODEL_METADATA` (JSON, for example `{"capabilities":{"vision":true}}`) and `DEFAULT_MODEL_PARAMS` (JSON, for example `{"temperature":0.7}`). In Native mode, model-attached knowledge bases are not auto-injected; the model must call the retrieval tool.

### Pitfalls

- `localhost` inside the container is the container. Use `host.docker.internal` or the service name on a shared Docker network.
- Changing env vars has no effect after first boot while persistent config is on; edit in the UI or set `ENABLE_PERSISTENT_CONFIG=False`.
- New gateway models do not appear: with `ENABLE_BASE_MODELS_CACHE=True` the list refreshes only on restart or when Connections are saved; `MODELS_CACHE_TTL` caches list responses briefly.
- Token usage shows nothing until the **Usage** capability is on.
- Give Open WebUI a least-privilege virtual key, not the gateway master key.

## LobeHub

### What it is and when to choose it

Polished chat UI (renamed from LobeChat) with agents, plugins and a client-side or server database mode. Choose it for a personal or small-team UI with strong multimodal support.

### Config location

- UI: **App Settings → AI Providers**, select OpenAI (or another OpenAI-compatible provider), set API key and **Proxy URL**, **Check**, then enable, fetch or add models.
- Server env vars per provider, for example `ENABLED_OPENAI`, `OPENAI_API_KEY`, `OPENAI_PROXY_URL`, `OPENAI_MODEL_LIST`.

### Minimal config

```bash
OPENAI_API_KEY=<your-virtual-key>
OPENAI_PROXY_URL=https://llm.example.com/v1
OPENAI_MODEL_LIST=-all,+coder=Coder<131072:fc>,+vision=Vision<32768:vision:fc>
```

### Capability flags

`OPENAI_MODEL_LIST` syntax: `id->deploymentName=displayName<maxToken:vision:reasoning:search:fc:file:imageOutput>`, comma-separated. `+` adds, `-` hides, `-all` hides all built-ins first. First value in angle brackets is the context size; then capabilities `fc` (function calling), `vision`, `reasoning`, `search`, `file`, `imageOutput`, `video`.

### Pitfalls

- Whether `OPENAI_PROXY_URL` needs `/v1` depends on the endpoint; empty replies usually mean the suffix is wrong. LiteLLM and most engines want `/v1`.
- A dedicated "custom provider" flow (separate from editing the built-in OpenAI provider) exists in recent releases, but its exact menu path is not described in the docs consulted. (unverified)
- Field lesson: model lists fetched from `/v1/models` carry no capabilities, and gateways return placeholder metadata (LiteLLM reports a fixed `created` timestamp and `owned_by: openai`), so fetched models can be shown with wrong dates or default capabilities. Declare models explicitly with the list syntax above. (unverified: exact LobeHub behaviour)

## Official links

- Open WebUI OpenAI-compatible connections: https://docs.openwebui.com/getting-started/quick-start/connect-a-provider/starting-with-openai-compatible
- Open WebUI env configuration: https://docs.openwebui.com/reference/env-configuration
- Open WebUI models workspace: https://docs.openwebui.com/features/workspace/models
- Open WebUI releases: https://github.com/open-webui/open-webui/releases
- LobeHub AI providers: https://lobehub.com/docs/usage/providers
- LobeHub model provider env vars: https://lobehub.com/docs/self-hosting/environment-variables/model-provider
- LobeHub model list syntax: https://lobehub.com/docs/self-hosting/advanced/model-list
- LobeHub releases: https://github.com/lobehub/lobehub/releases
