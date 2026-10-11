---
name: librechat
description: LibreChat, self-hosted multi-user chat UI with agents, MCP and RAG. Use to point it at vLLM, llama.cpp, Ollama, LiteLLM or llama-swap through librechat.yaml custom endpoints (OpenAI or Anthropic Messages), map model names, keep keys in .env, enable tool calls and agents, or fix an endpoint missing from the picker, empty model list, 401, host.docker.internal. Not for Open WebUI (open-webui).
license: MIT
compatibility: Commands assume bash, curl, jq and Docker Compose. LibreChat needs MongoDB (bundled in its compose). Installs, exposure, registration settings, upgrades and restarts need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# LibreChat

A working LibreChat (`danny-avila/LibreChat`, now under `LibreChat-AI/LibreChat`; MIT) whose model picker shows your self-hosted models through `librechat.yaml` custom endpoints, with working streaming, titles, tool calls and agents, and keys that never appear in files or output.

**Scope:** this one product: install, custom endpoints against OpenAI-compatible and Anthropic-compatible servers, agents and MCP basics, update, troubleshoot. Choosing a gateway belongs to `llm-gateway`; running the servers belongs to `vllm`, `llama-cpp`, `ollama`, `litellm` and `llama-swap`. Other chat UIs: `open-webui`, `lobehub`, `anythingllm`, `sillytavern`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -Ei 'librechat|mongo|meili|rag_api' || true
find ~ -maxdepth 4 -name 'librechat.yaml' 2>/dev/null | head
env | cut -d= -f1 | grep -E '^(OPENAI|ANTHROPIC|LITELLM|GATEWAY|LLM)_' || true     # names only
curl -fsS -m 5 http://localhost:3080/api/config | jq 'keys' 2>/dev/null                     # public config, no secrets
docker logs LibreChat 2>&1 | grep -iE 'custom config|librechat.yaml|error' | tail -5    # container is named LibreChat in upstream compose
gh api repos/LibreChat-AI/LibreChat/releases/latest --jq .tag_name 2>/dev/null           # newest release
BASE=http://localhost:4000 scripts/check-endpoint.sh    # probes models, chat, tools, stream, /v1/messages
```

Ask only what discovery cannot show: which server or gateway (name, host, port), whether it enforces a key, whether the model must call tools (agents), whether LibreChat runs in Docker, and who may register.

## Decision flow

1. **No LibreChat yet:** Docker Compose from upstream, `.env` and `librechat.yaml`. -> `references/install.md`
2. **One gateway (LiteLLM, llama-swap) or several engines:** one custom endpoint per base URL; prefer one gateway so users see one list. -> `references/custom-endpoints.md`
3. **Server speaks only Chat Completions (vLLM, llama.cpp, Ollama):** a plain custom endpoint with a `/v1` baseURL. -> `references/custom-endpoints.md`
4. **Server serves `/v1/messages` and the model is Claude-style or you want native tool/thinking blocks:** `provider: anthropic` with a root baseURL. -> `references/custom-endpoints.md`
5. **Tools, agents, MCP:** the model and engine must emit real tool calls. -> `references/agents-and-tools.md`
6. **Model missing, 401, 404, empty replies, container cannot reach host:** -> `references/troubleshooting.md`
7. **New release:** -> `references/install.md` (Updating)

## Rules

- **Ask before changing the system.** Installs, `.env` and `librechat.yaml` edits, restarts, open registration and exposure need approval and an undo path (copy the file first).
- **Secrets never touch output.** Keys live in LibreChat's `.env` (`0600`) and are referenced as `'${GATEWAY_API_KEY}'` in `librechat.yaml`; check presence by name only. Use `LLM_API_KEY_FILE` with `scripts/check-endpoint.sh`.
- **`apiKey` is mandatory per custom endpoint**, even for servers without auth; a non-empty placeholder such as `ollama` or `vllm` is fine. An endpoint without one is dropped at config load.
- **`baseURL` shape depends on the API.** OpenAI-compatible endpoints end with `/v1`; `provider: anthropic` takes the server root and LibreChat appends `/v1/messages`.
- **Inside Docker, `localhost` is the container.** Use `host.docker.internal` (the upstream compose adds the host-gateway mapping), a service name on a shared network, or a LAN address.
- **Pin the image.** Use a release tag, not the floating `latest` or `-dev` images the stock compose may reference, and record the digest before upgrades.
- **Register your own admin first, then close sign-up** (`ALLOW_REGISTRATION=false`) before exposing the UI; put TLS in front and keep MongoDB, Meilisearch and the RAG API private.
- **Verify upstream.** Fields and defaults come from librechat.ai docs and the release notes at use time, not memory.

## Workflows

### Add a self-hosted model

- [ ] Probe the server first: `scripts/check-endpoint.sh` (same base, key and model name the UI will use).
- [ ] Copy the matching block from `assets/librechat.yaml`; put keys and URLs in `.env` as `GATEWAY_API_KEY`, `GATEWAY_BASE_URL`.
- [ ] Mount the file (`assets/docker-compose.override.yml`), `docker compose down && docker compose up -d`.
- [ ] Check `docker logs LibreChat` for config errors; open the endpoint picker, send one message, then one tool-calling message.

### Make tools and agents work

- [ ] Engine side: tool parser flags (`vllm` `--enable-auto-tool-choice --tool-call-parser`, llama.cpp `--jinja`) -> `references/agents-and-tools.md`.
- [ ] Create an Agent on the custom endpoint, attach one tool, confirm a tool call appears in the transcript.

### Update

- [ ] Back up `.env`, `librechat.yaml` and the MongoDB volume; bump the pinned tag; `docker compose pull && docker compose up -d`; re-run the smoke test -> `references/install.md`.

## Reference index

| File                             | Read when                                                                                                                                            |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `references/install.md`          | Docker Compose install, `.env` essentials, mounting config, registration, pinning, updating                                                          |
| `references/custom-endpoints.md` | Every custom-endpoint field, per-server recipes (vLLM, llama.cpp, Ollama, LiteLLM, llama-swap), Anthropic provider, model-name mapping, auth headers |
| `references/agents-and-tools.md` | Tool calling, agents on custom endpoints, reasoning replay, MCP servers, context and cost config                                                     |
| `references/troubleshooting.md`  | Symptom to cause to fix                                                                                                                              |

Templates: `assets/librechat.yaml`, `assets/docker-compose.override.yml`. Script: `scripts/check-endpoint.sh` (read-only probe of models, chat, tools, streaming and `/v1/messages`).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `llm-clients`: choosing and troubleshooting clients of every kind, incl. capability flags.
- `litellm`: the gateway most LibreChat setups point at; virtual keys, model aliases.
- `llama-swap`: hot-swapping local models behind one OpenAI and Anthropic endpoint.
- `vllm`, `llama-cpp`, `ollama`: the engines behind the endpoint, including tool-parser flags.
- `tool-calling-parsers`: choosing the right parser when agents never call tools.
- `open-webui`, `lobehub`: alternative multi-user chat UIs.
