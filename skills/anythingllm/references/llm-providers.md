# AnythingLLM: LLM providers for self-hosted servers

> Verified against AnythingLLM v1.17.0 (docs: setup/llm-configuration overview, openai-generic, ollama; source server/utils/AiProviders genericOpenAi, liteLLM, ollama, localAi, anthropic; server/.env.example), vLLM v0.31.0, llama.cpp server README, llama-swap v263, LiteLLM v1.105.0, 2026-10-11

AnythingLLM has three LLM levels: the **System LLM** (default, Settings, LLM Preference), a **Workspace LLM** (per workspace, overrides the system one), and an **Agent LLM** (used for `@agent` in that workspace; defaults to the system LLM). Providers are selected with `LLM_PROVIDER` in `.env` or in the UI, which writes the same variables. AnythingLLM's server makes the requests, so URLs must resolve from the container.

## Which provider for which server

| Server                                                                   | Provider                                                     | Base URL                                                                                                                                                                           | Notes                                                                                                                                                                                                             |
| ------------------------------------------------------------------------ | ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| vLLM, llama.cpp `llama-server`, llama-swap, any OpenAI-compatible server | `generic-openai` (UI: OpenAI (generic), "developer-focused") | `http://host:port/v1`                                                                                                                                                              | Model id typed by hand. Upstream warns it is configurable and fails silently on wrong input.                                                                                                                      |
| LiteLLM proxy                                                            | `litellm` (or `generic-openai`)                              | `http://host:4000` for the LiteLLM provider, which passes the URL straight to the OpenAI client; LiteLLM serves `/chat/completions` with or without `/v1`. Use `/v1` with generic. | Virtual key in `LITE_LLM_API_KEY`.                                                                                                                                                                                |
| Ollama                                                                   | `ollama` (native API)                                        | `http://host:11434` (no `/v1`)                                                                                                                                                     | Reads model list and capabilities from Ollama, so tool support is detected per model. Or Generic OpenAI against `http://host:11434/v1`.                                                                           |
| LM Studio, LocalAI, KoboldCpp                                            | `lmstudio`, `localai`, `koboldcpp`                           | LocalAI: `/v1`; KoboldCpp: `.../v1`                                                                                                                                                | Same OpenAI-compatible shape.                                                                                                                                                                                     |
| Anthropic API                                                            | `anthropic`                                                  | none: no base-URL variable                                                                                                                                                         | Only `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL_PREF`, `ANTHROPIC_CACHE_CONTROL`. It cannot point at a gateway's `/v1/messages`. For self-hosted or gateway-served Claude-style models use an OpenAI-compatible route. |

AnythingLLM has no "Anthropic-compatible custom URL" option: if your backend only exposes `/v1/messages` put LiteLLM or llama-swap in front and use the OpenAI route.

## Generic OpenAI (recommended default)

UI: Settings, LLM Preference, provider **OpenAI (Generic)**: fields **Base URL**, **API Key**, **Chat Model Name**, **Token context window**, **Max Tokens**. Env equivalents (see `assets/anythingllm.env.example`):

| Variable                              | Meaning                                                                                                                       |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `GENERIC_OPEN_AI_BASE_PATH`           | Base URL, with `/v1`. Required.                                                                                               |
| `GENERIC_OPEN_AI_MODEL_PREF`          | Model id exactly as the server expects (the name in `GET /v1/models`, `--served-model-name`, or gateway alias).               |
| `GENERIC_OPEN_AI_MODEL_TOKEN_LIMIT`   | Context window AnythingLLM budgets prompts against. Default 4096.                                                             |
| `GENERIC_OPEN_AI_API_KEY`             | Bearer key. Sent as `Authorization: Bearer`. Servers without auth need any non-empty placeholder.                             |
| `GENERIC_OPEN_AI_CUSTOM_HEADERS`      | Comma-separated `Name:value` pairs added to every request (proxy auth such as `X-Api-Key:...`). Values cannot contain commas. |
| `GENERIC_OPEN_AI_MAX_TOKENS`          | Max tokens per request (UI "Max Tokens").                                                                                     |
| `GENERIC_OPEN_AI_MODEL_MAX_TOKEN_KEY` | Request field that carries it; default `max_tokens`, set `max_completion_tokens` for servers that want that.                  |
| `GENERIC_OPEN_AI_REPORT_USAGE`        | `true` adds `stream_options: {include_usage: true}`; off by default because some servers reject the option.                   |
| `GENERIC_OPENAI_STREAMING_DISABLED`   | `true` turns streaming off (also for agents) when a server mangles SSE.                                                       |

Auth that is not a Bearer key: leave `GENERIC_OPEN_AI_API_KEY` as a placeholder and put the real credential in `GENERIC_OPEN_AI_CUSTOM_HEADERS`, or run the gateway so it accepts Bearer keys.

### Model-name mapping

AnythingLLM sends `GENERIC_OPEN_AI_MODEL_PREF` verbatim as `model`. Workspaces can pick a different string via the workspace Chat Settings. Alias friendly names in the gateway (LiteLLM `model_name`, llama-swap model ids) and type the alias here. Generic OpenAI does not list models for you, so a typo shows up only as a server-side 404 "model not found".

## Per-server recipes

Docker on the same host; replace `host.docker.internal` with `172.17.0.1` on a default Linux bridge or with a service name.

### vLLM

```bash
LLM_PROVIDER='generic-openai'
GENERIC_OPEN_AI_BASE_PATH='http://host.docker.internal:8000/v1'
GENERIC_OPEN_AI_MODEL_PREF='Qwen/Qwen3-8B'          # as vllm serve exposes it
GENERIC_OPEN_AI_MODEL_TOKEN_LIMIT=32768             # at most --max-model-len
GENERIC_OPEN_AI_API_KEY='<vllm --api-key value>'
```

`--api-key` is a Bearer check on `/v1`. Tool calls need `--enable-auto-tool-choice --tool-call-parser <name>`; see `references/agents-and-mcp.md`.

### llama.cpp (`llama-server`)

```bash
GENERIC_OPEN_AI_BASE_PATH='http://host.docker.internal:8080/v1'
GENERIC_OPEN_AI_MODEL_PREF='local-model'
GENERIC_OPEN_AI_MODEL_TOKEN_LIMIT=<value of -c / --ctx-size>
GENERIC_OPEN_AI_API_KEY='<llama-server --api-key value or placeholder>'
```

Tool use needs `--jinja` with a tool-capable template. Context per slot may be `-c` divided by `--parallel`; set the token limit to what one request really gets.

### llama-swap

Same as above with `http://host.docker.internal:8080/v1` (llama-swap's port from its config) and the model id from `models:` (or an alias). If `apiKeys` is set in llama-swap, use one of those keys. The first request to a model that is not loaded waits for the swap; raise timeouts at any proxy in front and avoid changing models per request.

### LiteLLM

Provider `litellm`: `LITE_LLM_BASE_PATH='http://host.docker.internal:4000'`, `LITE_LLM_MODEL_PREF='coder'`, `LITE_LLM_MODEL_TOKEN_LIMIT=32768`, `LITE_LLM_API_KEY='<virtual key>'`. Use a least-privilege virtual key, never the master key.

### Ollama

Native provider: `OLLAMA_BASE_PATH='http://host.docker.internal:11434'`, `OLLAMA_MODEL_PREF='qwen3:8b'`, `OLLAMA_MODEL_TOKEN_LIMIT=8192`. Optional `OLLAMA_AUTH_TOKEN` (Bearer, for Ollama behind auth) and `OLLAMA_RESPONSE_TIMEOUT` (ms; default 5 minutes). AnythingLLM auto-detects `http://127.0.0.1:11434`, `http://host.docker.internal:11434` and `http://172.17.0.1:11434`; anything else must be typed. Ollama must listen beyond loopback for a container to reach it: `OLLAMA_HOST` set to an address the Docker bridge reaches. Binding `0.0.0.0` exposes an unauthenticated API on every interface, so firewall port 11434.

## Choosing the context window honestly

`/v1/models` does not report context length to AnythingLLM. Set the token limit to the engine's real per-request window; larger than the server allows gives server-side 400s, smaller wastes capacity and trims history. Also set Max Tokens: servers that default to a small `max_tokens` cut replies short.

## Key handling

- UI fields write into the server `.env`; treat the file as a secret (`0600`, no backups to shared places).
- `docker exec anythingllm printenv` prints secrets: do not run it in shared logs.
- Keep the instance behind `AUTH_TOKEN` or multi-user mode so the settings pages are not open to everyone.
- Rotate by editing the `.env` value and restarting the container.

## Official links

- LLM setup overview: https://docs.anythingllm.com/setup/llm-configuration/overview
- OpenAI (generic): https://docs.anythingllm.com/setup/llm-configuration/cloud/openai-generic
- Ollama connection troubleshooting: https://docs.anythingllm.com/ollama-connection-troubleshooting
- Connecting to localhost from Docker: https://docs.anythingllm.com/installation-docker/localhost
- Env template: https://github.com/Mintplex-Labs/anything-llm/blob/master/server/.env.example
