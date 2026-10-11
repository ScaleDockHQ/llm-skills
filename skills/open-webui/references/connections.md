# Open WebUI: connections to OpenAI-compatible endpoints and Ollama

> Verified against Open WebUI v0.12.0 (docs: connect-a-provider/*, reference/env-configuration, troubleshooting/connection-error), 2026-10-11

Open WebUI speaks protocols, mainly OpenAI Chat Completions, plus experimental Open Responses support. It does not implement provider-specific APIs; for others use a gateway such as LiteLLM or a pipe function. There is no separate Anthropic Messages custom-endpoint setting: Anthropic's own `api.anthropic.com/v1` is recognised (model discovery), and a self-hosted Anthropic-shaped gateway should be added as an OpenAI-compatible connection through the gateway's `/v1` route.

## Add a connection (UI)

Settings, Admin, Connections, Manage OpenAI API Connections, Add Connection:

1. **URL** ending at the API root, including `/v1` for most servers.
2. **Auth**: None for keyless servers; Bearer with the key otherwise (Bearer with an empty key sends an empty token, which some servers reject).
3. **Model IDs** allowlist (optional): add ids with the plus icon when `/models` is missing or you want a curated list.
4. **Verify Connection** calls `/models`. Saving does not test. Verify can fail on providers without `/models` while chat still works; add model ids manually then.
5. Advanced: **Provider** (see below), prefix id (disambiguates equal model names across connections), Forward cookies (off by default; only for trusted internal servers), enable toggle.

Direct Connections (experimental) let the browser call an endpoint itself; the endpoint needs CORS for your Open WebUI origin, and keys sit in browser storage. Prefer admin connections for teams.

## Env vars (first boot, or with persistent config off)

```bash
ENABLE_OPENAI_API=True
OPENAI_API_BASE_URLS=http://host.docker.internal:4000/v1;http://host.docker.internal:8000/v1
OPENAI_API_KEYS=<key-for-first>;<key-for-second>          # same order; semicolon separated; empty slot for keyless
OPENAI_API_CONFIGS={"0":{"enable":true,"prefix_id":"gw","model_ids":["coder","fast"]}}
AIOHTTP_CLIENT_TIMEOUT_MODEL_LIST=10                      # seconds; unreachable endpoints delay the model list
```

Keep keys in a `0600` env file (`assets/open-webui.env.example`). Use least-privilege keys; never a gateway master key.

## URL per engine

| Engine / gateway         | URL from inside Docker                  | Auth                                        |
| ------------------------ | --------------------------------------- | ------------------------------------------- |
| vLLM                     | `http://host.docker.internal:8000/v1`   | None, or Bearer if started with `--api-key` |
| llama.cpp `llama-server` | `http://host.docker.internal:8080/v1`   | None, or Bearer with `--api-key`            |
| LM Studio                | `http://host.docker.internal:1234/v1`   | Blank or a placeholder                      |
| LiteLLM                  | `http://host.docker.internal:4000/v1`   | Bearer virtual key                          |
| llama-swap               | `http://host.docker.internal:<port>/v1` | Per its config                              |
| LocalAI                  | `http://host.docker.internal:8080/v1`   | None                                        |

Ports are defaults; use what your engine listens on. A service on a shared Compose network uses its service name instead (`http://litellm:4000/v1`).

## The Provider setting (Advanced)

A hint about the server behind an OpenAI connection; Default is always safe.

- **llama.cpp** and **LM Studio**: unlock the model management panel (list, download, load, unload; delete for llama.cpp), loaded markers and the admin Eject button (llama.cpp only). For llama.cpp, stored reasoning is replayed as `reasoning_content`.
- **LiteLLM**: requests arriving at Open WebUI's own Anthropic Messages endpoint are forwarded to LiteLLM as-is instead of being converted.
- **Azure OpenAI**: deployment-style URLs and `api-version`.

## Ollama

A separate connection type (`OLLAMA_BASE_URL`, `ENABLE_OLLAMA_API`). Ollama must listen beyond loopback for a container to reach it (`OLLAMA_HOST=0.0.0.0`, unauthenticated, so firewall it), or use `--network=host`. Prefer Ollama's `/v1` as an OpenAI connection only if you need uniform handling with other engines.

## Model list behavior

- Model ids come from `/models` or the allowlist. Capabilities do not come from either.
- `ENABLE_BASE_MODELS_CACHE=True` caches the list until restart or until you save Connections; `MODELS_CACHE_TTL` (default 1 second) caches responses briefly. New gateway models not appearing: save the connection or restart.
- Several connections with one unreachable URL slow the whole selector by the timeout; remove or fix it.

## Required endpoints

`/v1/chat/completions` (required, streaming), `/v1/models` (recommended), `/v1/embeddings` (RAG), `/v1/audio/speech` and `/v1/audio/transcriptions` (voice), `/v1/images/generations` (images).

## Official links

- OpenAI-compatible connections: https://docs.openwebui.com/getting-started/quick-start/connect-a-provider/starting-with-openai-compatible
- vLLM: https://docs.openwebui.com/getting-started/quick-start/connect-a-provider/starting-with-vllm
- llama.cpp: https://docs.openwebui.com/getting-started/quick-start/connect-a-provider/starting-with-llama-cpp
- Environment configuration: https://docs.openwebui.com/reference/env-configuration
- Direct Connections: https://docs.openwebui.com/features/chat-conversations/direct-connections
