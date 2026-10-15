---
name: anythingllm
description: AnythingLLM, all-in-one chat and RAG app with workspaces, agents and MCP (Desktop or Docker). Use to point it at vLLM, llama.cpp, Ollama, LiteLLM or llama-swap with the Generic OpenAI, Ollama or LiteLLM provider, keep keys in the server .env, set context window and max tokens, make @agent call tools, or fix fetch failed, empty model list, localhost in Docker.
license: MIT
compatibility: Commands assume bash, curl, jq and Docker. Desktop builds exist for macOS, Windows and Linux. Installs, restarts, exposure and storage changes need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# AnythingLLM

A working AnythingLLM (`Mintplex-Labs/anything-llm`, MIT) whose workspaces and `@agent` talk to your own model servers through the right provider, with the context window declared, keys kept out of output, and tool calls proven.

**Scope:** this one product: Docker install, LLM provider setup for OpenAI-compatible servers, Ollama and gateways, agents and MCP basics, update, troubleshoot. Embedding and vector database choices are touched only where they break LLM setup. Gateway choice belongs to `llm-gateway`; other chat UIs are `open-webui`, `lobehub`, `librechat`, `sillytavern`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | grep -i anythingllm || true
ls -l "${STORAGE_LOCATION:-$HOME/anythingllm}"/.env 2>/dev/null                                  # server env file (do not cat it)
grep -E '^(LLM_PROVIDER|GENERIC_OPEN_AI_BASE_PATH|OLLAMA_BASE_PATH|LITE_LLM_BASE_PATH|[A-Z_]*MODEL_PREF)=' "${STORAGE_LOCATION:-$HOME/anythingllm}/.env" 2>/dev/null   # non-secret settings only
curl -fsS -m 5 http://localhost:3001/api/ping                                                    # liveness
docker logs anythingllm 2>&1 | tail -20
gh api repos/Mintplex-Labs/anything-llm/releases/latest --jq .tag_name                            # newest release
BASE=http://localhost:4000 scripts/check-endpoint.sh                                              # probe the model server first
```

Ask only what discovery cannot show: Desktop or Docker, which server or gateway, whether it needs a key, whether `@agent` tools matter, and who will reach the UI.

## Decision flow

1. **No instance:** Docker with a persistent storage mount and `.env`. -> `references/install.md`
2. **Any OpenAI-compatible server (vLLM, llama.cpp, llama-swap, LiteLLM, Ollama `/v1`):** provider **Generic OpenAI** with a `/v1` base URL. -> `references/llm-providers.md`
3. **Ollama only:** provider **Ollama** (native API, no `/v1`), or Generic OpenAI against `/v1`. -> `references/llm-providers.md`
4. **A gateway that fronts Anthropic-style models:** AnythingLLM's Anthropic provider has no base-URL setting, so reach non-Anthropic or self-hosted backends through an OpenAI-compatible route (Generic OpenAI or LiteLLM provider). -> `references/llm-providers.md`
5. **`@agent` ignores tools, MCP, flows:** -> `references/agents-and-mcp.md`
6. **Model missing, fetch failed, truncation, 401, slow first reply:** -> `references/troubleshooting.md`
7. **New release:** -> `references/install.md` (Updating)

## Rules

- **Ask before changing the system.** Installs, `.env` edits, container recreation, exposure and storage changes need approval and an undo path (copy the env file, keep the storage mount).
- **Secrets never touch output.** Keys go in the mounted server `.env` (`0600`) or the UI fields, which write to it. Never `cat` the file; read non-secret keys with the targeted `grep` above. Use `LLM_API_KEY_FILE` with `scripts/check-endpoint.sh`.
- **Persist storage.** Run with `-v ${STORAGE_LOCATION}:/app/server/storage` and the `.env` mount, or settings, documents and vectors vanish with the container.
- **Inside Docker, `localhost` is the container.** Use `host.docker.internal` (macOS, Windows) or `172.17.0.1` (Linux default bridge), or a shared network name.
- **Declare the context window.** The default model token limit is 4096; set the real value (`*_MODEL_TOKEN_LIMIT` or the UI field) or prompts get trimmed early.
- **Generic OpenAI wants `/v1`** in the base URL; the model name is typed, not discovered.
- **Set `AUTH_TOKEN` (instance password) before exposing the UI**; terminate TLS in front. AnythingLLM runs as UID/GID 1000: `chown`, never `chmod 777` the storage.
- **Verify upstream.** Variables come from upstream `server/.env.example` and docs.anythingllm.com at use time.

## Workflows

### Connect a model server

- [ ] Probe the server first: `scripts/check-endpoint.sh` (same base, key and model id).
- [ ] Set the provider in the UI (Settings, LLM Preference) or in `.env` from `assets/anythingllm.env.example`; recreate the container if you edited `.env`.
- [ ] Create a workspace, chat once; open Workspace settings, Chat Settings to override the model per workspace if needed.

### Make `@agent` work

- [ ] Prove tool calls with `scripts/check-endpoint.sh` (`tool_call:` line) -> `references/agents-and-mcp.md`.
- [ ] Settings, Agent Skills: enable only the skills you need; run `@agent` and look for the "thought" lines proving a real tool call.

### Update

- [ ] Back up the storage directory, pin the image tag, `docker pull`, recreate with the same mounts -> `references/install.md`.

## Reference index

| File                            | Read when                                                                                                                                       |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `references/install.md`         | Docker run and Compose, storage and permissions, `.env` file, auth, AVX2, updating, Desktop notes                                               |
| `references/llm-providers.md`   | Generic OpenAI, Ollama, LiteLLM, LocalAI providers; env names, key and header handling, model names, context and max tokens, per-engine recipes |
| `references/agents-and-mcp.md`  | `@agent`, native vs prompt-based tools, intelligent tool selection, MCP servers, flows                                                          |
| `references/troubleshooting.md` | Symptom to cause to fix                                                                                                                         |

Templates: `assets/anythingllm.env.example`. Script: `scripts/check-endpoint.sh` (read-only probe of models, chat, tools, streaming).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `llm-clients`: choosing and troubleshooting clients of every kind.
- `litellm`, `llama-swap`: gateways to point AnythingLLM at.
- `vllm`, `llama-cpp`, `ollama`: the engines behind the endpoint, including tool-parser flags.
- `tool-calling-parsers`: when agents never call tools.
- `open-webui`, `librechat`: other multi-user chat UIs.
