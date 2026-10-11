# LibreChat: custom endpoints for self-hosted LLM servers

> Verified against LibreChat v0.8.8 / config v1.3.17 (docs: librechat_yaml/object_structure/custom_endpoint, default_params, ai_endpoints/ollama|vllm|litellm), vLLM v0.31.0, llama.cpp server README, Ollama v0.40.3 docs, llama-swap v263, LiteLLM v1.105.0, 2026-10-11

A custom endpoint is an entry under `endpoints.custom` in `librechat.yaml`. LibreChat's server calls it (not the browser), so URLs must resolve from the `api` container. Start from `assets/librechat.yaml`.

## Field cheat sheet

| Field                                                                                         | What it does and the traps                                                                                                                                                                                                                                                                                                                                                       |
| --------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`                                                                                        | Unique label in the endpoint picker. Do not reuse built-in names (`openAI`, `anthropic`, `google`, `agents`, `bedrock`, ...). Names matching known providers (`ollama`, `groq`, `Mistral`, ...) pick up their icon; a name starting with `ollama` (any case) makes LibreChat list models through Ollama's native `/api/tags`.                                                    |
| `apiKey`                                                                                      | Required, non-empty. `'${ENV_VAR}'` (recommended), a literal, or `user_provided` (each user enters a key). Sent as `Authorization: Bearer <key>` unless `headers` already sets `Authorization`.                                                                                                                                                                                  |
| `baseURL`                                                                                     | Required. `'${ENV_VAR}'`, literal or `user_provided`. OpenAI path: LibreChat appends `/chat/completions` (or `/completion`), so end with `/v1`. `directEndpoint: true` treats the URL as the complete completions URL.                                                                                                                                                           |
| `provider`                                                                                    | Omit for OpenAI-compatible. `anthropic` uses the native Messages client against `baseURL` root; supports `headers`, `addParams`, `dropParams`, `customParams.paramDefinitions`.                                                                                                                                                                                                  |
| `models.default`                                                                              | Array of model ids; the fallback when fetching fails and the explicit list when `fetch: false`.                                                                                                                                                                                                                                                                                  |
| `models.fetch`                                                                                | `true` lists `/v1/models` (not used for `provider: anthropic`). Slow or failing servers delay first load.                                                                                                                                                                                                                                                                        |
| `models.userIdQuery`                                                                          | Adds the LibreChat user id as a query parameter on the model-list request.                                                                                                                                                                                                                                                                                                       |
| `titleConvo`, `titleModel`, `titleMethod`, `titleMessageRole`, `titleTiming`, `titleEndpoint` | Title generation. `titleModel` defaults to `gpt-3.5-turbo`, which your server does not have: set a real id or `current_model`. `titleMessageRole: user` avoids "system role not supported" on strict templates. `titleMethod: completion` (default) works with most servers; `structured` needs provider support. `titleEndpoint` can route titles to a cheaper custom endpoint. |
| `addParams`                                                                                   | Extra request fields, overriding defaults: `max_tokens`, `stop`, vendor options (`chat_template_kwargs`, `top_k`, ...). Values may be nested.                                                                                                                                                                                                                                    |
| `dropParams`                                                                                  | Remove default fields the server rejects: e.g. `['stop', 'user', 'frequency_penalty', 'presence_penalty']`. Defaults sent: `model`, `user`, `stream`, `messages`; `max_tokens` is **not** sent by default.                                                                                                                                                                       |
| `headers`                                                                                     | Extra headers, strings only. Supports `${ENV_VAR}` and `{{LIBRECHAT_USER_ID}}`, `{{LIBRECHAT_USER_EMAIL}}`, `{{LIBRECHAT_BODY_CONVERSATIONID}}` and more. Also forwarded on the model-list request when `fetch: true`. An `Authorization` entry replaces the Bearer fallback. Not forwarded when `baseURL: user_provided`.                                                       |
| `tokenConfig`                                                                                 | Per model `prompt`, `completion`, `context` (all required), optional `cacheRead`, `cacheWrite`; rates are per million tokens, used for context meters, cost views and balance. Key must equal the model id sent.                                                                                                                                                                 |
| `customParams`                                                                                | `defaultParamsEndpoint`, `reasoningFormat` (`reasoning_effort`, `reasoning_object`, `disabled`), `reasoningKey`, `includeReasoningContent`, `includeReasoningHistory`, `paramDefinitions`. See `references/agents-and-tools.md`.                                                                                                                                                 |
| `tenantId`                                                                                    | Scope an endpoint to one tenant; upgrade every replica first.                                                                                                                                                                                                                                                                                                                    |

## Secrets and model names

- Keep keys in `.env` and reference them: `apiKey: '${GATEWAY_API_KEY}'`. For admin-API-written endpoints a literal key is encrypted at rest and only a preview is returned, but for file-based config always use the reference.
- Auth that is not a Bearer key (`X-API-Key`, Cloudflare Access service tokens): put it in `headers` with an `${ENV_VAR}`; keep `apiKey` as a placeholder.
- **Model-name mapping**: LibreChat sends the string from `models.default` / the fetched list verbatim as `model`. So the names in the picker are exactly your server's ids. To present friendly names or a stable alias, define the alias in the gateway (`litellm` `model_name`, `llama-swap` model ids and `aliases`) rather than in LibreChat. Use `modelSpecs` only if you need presets or labels; they reference the same ids.
- A model id containing `claude` on an OpenAI-compatible custom endpoint switches document-upload rules to Claude's (PDFs and text accepted, other binaries skipped). Avoid `claude` in aliases for non-Claude backends if you rely on file upload.

## Per-server recipes (OpenAI-compatible)

All base URLs below assume LibreChat in Docker and the server on the host; replace `host.docker.internal` with a service name when both are in Compose.

### LiteLLM proxy

```yaml
- name: "LiteLLM"
  apiKey: "${LITELLM_KEY}" # a virtual key, not the master key
  baseURL: "http://litellm:4000/v1" # LiteLLM's own default port is 4000
  models: { default: ["coder"], fetch: true }
  titleConvo: true
  titleModel: "current_model"
```

With `fetch: true` you get every model the key may call; `default` is only the initial pick. Cap spend per key in LiteLLM, not in LibreChat.

### llama-swap

```yaml
- name: "llama-swap"
  apiKey: "${LLAMA_SWAP_KEY}" # placeholder if apiKeys is not set in llama-swap
  baseURL: "http://host.docker.internal:8080/v1"
  models: { default: ["qwen3-coder"], fetch: true }
  titleModel: "current_model" # a second model would trigger a swap
```

llama-swap loads models on demand, so the first message after a swap is slow; raise client timeouts at any proxy in front. It accepts `Authorization: Bearer`, `x-api-key` or Basic when `apiKeys` is configured. Pick `titleModel: current_model` or a model in the same group, otherwise every new chat swaps models just to write a title.

### vLLM

```yaml
- name: "vLLM"
  apiKey: "${VLLM_API_KEY}"
  baseURL: "http://host.docker.internal:8000/v1"
  models: { default: ["Qwen/Qwen3-8B"], fetch: true }
  titleModel: "current_model"
  titleMessageRole: "user" # upstream's vLLM example does this for templates that reject system
```

`--api-key` (or `VLLM_API_KEY`) only guards `/v1`-style routes and is a plain Bearer check; upstream warns it is not a full security boundary. The id must match `--served-model-name` or the repo id. Tool calls need `--enable-auto-tool-choice --tool-call-parser <name>`.

### llama.cpp (`llama-server`)

```yaml
- name: "llama.cpp"
  apiKey: "${LLAMACPP_API_KEY}" # server flag --api-key / --api-key-file; any value if unset
  baseURL: "http://host.docker.internal:8080/v1"
  models: { default: ["local-model"], fetch: true }
  titleModel: "current_model"
  addParams: { max_tokens: 4096 }
```

Tool calls require `--jinja` (default enabled in current builds, verify with `llama-server --help`) and a template that supports tools; `--chat-template-file` is the override. llama-server accepts the key in `Authorization` or `X-Api-Key`.

### Ollama

```yaml
- name: "Ollama"
  apiKey: "ollama"
  baseURL: "http://host.docker.internal:11434/v1/"
  models: { default: ["qwen3:8b"], fetch: true }
  titleModel: "current_model" # keeps one model loaded per conversation
```

Ollama binds `127.0.0.1` by default; a container cannot reach it. Binding `OLLAMA_HOST=0.0.0.0` exposes an unauthenticated API on every interface, so prefer the Docker bridge gateway address plus a firewall rule. Behind an authenticating proxy put the credential in `headers` (the `Authorization` entry replaces `apiKey`).

## Anthropic Messages (`provider: anthropic`)

Use when the server serves `/v1/messages`: LiteLLM, llama-swap (`v1/messages`, `v1/messages/count_tokens`), vLLM (Anthropic router with `/v1/messages`), llama.cpp (`POST /v1/messages`, tools need `--jinja`), Ollama (subset of the Messages API; tool-choice controls, deferred tools and hosted web search not fully supported).

```yaml
- name: "Gateway-Anthropic"
  provider: "anthropic"
  apiKey: "${GATEWAY_API_KEY}"
  baseURL: "http://litellm:4000" # root; LibreChat calls <root>/v1/messages
  headers:
    anthropic-version: "2023-06-01"
  models: { default: ["claude-main"], fetch: false } # fetch is not used here
  titleConvo: true
  titleModel: "claude-main"
```

- **Auth header differs per server.** LibreChat's native Anthropic client normally sends `x-api-key`. llama.cpp and LiteLLM accept `x-api-key`; vLLM's `--api-key` middleware checks only `Authorization: Bearer`, so it returns 401 for a key sent as `x-api-key`. For vLLM put `Authorization: 'Bearer ${VLLM_API_KEY}'` in `headers`, or use the OpenAI path. Run `scripts/check-endpoint.sh` to see which header the server honours before editing YAML.
- Model names are listed manually; give the gateway aliases the same names.
- For thinking models that return `reasoning_content` on the OpenAI path, you can instead stay on the OpenAI path and set `customParams` (see agents reference), or use `customParams.defaultParamsEndpoint: anthropic` without `provider` to keep the OpenAI request path but get Anthropic-style parameters.

## Verify after editing

```bash
docker compose config -q && echo compose-ok
docker compose down && docker compose up -d
docker logs LibreChat 2>&1 | tail -30        # config schema errors appear here
BASE=http://litellm:4000 MODEL=coder LLM_API_KEY_FILE=$HOME/.config/llm/key scripts/check-endpoint.sh   # from the host
```

Then in the UI: pick the endpoint, send "ping", send a tool-requiring prompt through an Agent, open the parameters panel and confirm temperature, max tokens and stop sequences apply.

## Official links

- Custom endpoint object: https://www.librechat.ai/docs/configuration/librechat_yaml/object_structure/custom_endpoint
- Default parameters, addParams and dropParams: https://www.librechat.ai/docs/configuration/librechat_yaml/object_structure/default_params
- Ollama, vLLM, LiteLLM examples: https://www.librechat.ai/docs/configuration/librechat_yaml/ai_endpoints
- Docker override: https://www.librechat.ai/docs/configuration/docker_override
- Releases: https://github.com/LibreChat-AI/LibreChat/releases
