---
name: codex-cli
description: OpenAI Codex CLI, the terminal coding agent, pointed at self-hosted or gateway models through custom model providers over the Responses API. Use to install or update `codex`, write ~/.codex/config.toml model_providers (base_url, env_key, wire_api responses) for vLLM, llama.cpp, Ollama, LiteLLM or llama-swap, set profiles, context limits, fix 404 /v1/responses, MCP tools unsupported, compaction, auth. Not for Claude Code, OpenCode, Aider.
license: MIT
compatibility: Needs bash, curl and jq for the check script, and an endpoint that serves POST /v1/responses. Installs, updates, config edits and exposing a gateway need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Codex CLI

Run `codex` against your own endpoint (vLLM, llama.cpp, Ollama, a LiteLLM or llama-swap gateway) with a custom model provider, a safe key setup, correct limits and a verified Responses endpoint.

**Scope:** the Codex CLI and its `config.toml`. Gateways and engines belong to their own skills. Codex custom providers speak only the Responses API; there is no Chat Completions mode.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print keys.

```bash
command -v codex && codex --version
ls -l "${CODEX_HOME:-$HOME/.codex}"/*.toml 2>/dev/null
grep -nE '^(model|model_provider|oss_provider|openai_base_url|model_context_window)\b|^\[model_providers\.' "${CODEX_HOME:-$HOME/.codex}/config.toml" 2>/dev/null
env | grep -E '^(OPENAI|CODEX|LITELLM)_' | sed -E 's/=.*/=<set>/'
```

## Decision flow

1. **Endpoint serves `/v1/responses`** (vLLM, llama.cpp, Ollama, llama-swap, LiteLLM): define a provider with its base URL. -> `references/custom-providers.md`
2. **Chat-only endpoint:** put LiteLLM in front; it bridges Responses to chat completions. Use the `litellm` skill, then `references/combos/litellm-responses-bridge.md`.
3. **Ollama or LM Studio on the same machine, quick trial:** `codex --oss`. -> `references/custom-providers.md`
4. **Model names, context window, reasoning flags:** -> `references/models-and-limits.md`
5. **Tools, MCP, streaming, compaction misbehave:** -> `references/compatibility.md`
6. **Install or update:** -> `references/install-and-update.md`
7. **Error text:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, editing `~/.codex/config.toml`, shell profile exports and exposing a gateway need approval and an undo path (copy the file first).
- **Secrets never touch output or git.** Use `env_key` (the variable name) or `[model_providers.<id>.auth]` with a command. Avoid `experimental_bearer_token`, which writes the key into the file. Check presence with `[ -n "${VAR:-}" ]`, never `echo`.
- **Providers live in the user config.** Project `.codex/config.toml` ignores `model_provider`, `model_providers`, `openai_base_url` and `profile`. Switch per project with `codex --profile <name>`.
- **Reserved IDs.** Do not name a provider `openai`, `ollama` or `lmstudio`. To repoint built-in OpenAI use `openai_base_url`.
- **Responses only.** `wire_api = "responses"` is the only supported value. Older guides showing `"chat"` are obsolete.
- **Declare limits.** Set `model_context_window` and `model_auto_compact_token_limit` for models Codex does not know.
- **Test the endpoint first.** `scripts/check-endpoint.sh` before blaming Codex.
- **Verify upstream.** Keys, defaults and versions come from the Codex config reference and GitHub releases read on the writing date.

## Workflows

### Connect to a self-hosted endpoint

- [ ] Run discovery; back up `~/.codex/config.toml`.
- [ ] Put the key in a `0600` file and export it from the shell profile or launcher: `export LOCAL_LLM_API_KEY="$(cat ~/.config/llm/key)"`.
- [ ] `CODEX_BASE_URL=http://HOST:PORT/v1 CODEX_MODEL=<served-name> scripts/check-endpoint.sh` returns ok for models, plain, stream and tool probes.
- [ ] Add the provider and profile from `templates/` (`config.toml`, `local.config.toml`).
- [ ] `codex --profile local "list the files here"`, then a one-file edit.

### Fix a broken local setup

- [ ] 404, 400 or "unsupported": `references/troubleshooting.md`.
- [ ] Tool or MCP failures with llama.cpp, vLLM or Ollama: `references/compatibility.md` (known open issues, flags).

## Reference index

| File                                            | Read when                                                          |
| ----------------------------------------------- | ------------------------------------------------------------------ |
| `references/custom-providers.md`                | Provider keys, auth, headers, profiles, `--oss`, per-engine setup  |
| `references/models-and-limits.md`               | Context window, compaction, reasoning, model catalog               |
| `references/compatibility.md`                   | Responses features, tools, MCP, streaming, compaction, open issues |
| `references/install-and-update.md`              | Install paths, updating, pinning, state directory                  |
| `references/troubleshooting.md`                 | Symptom to cause to fix                                            |
| `references/combos/litellm-responses-bridge.md` | LiteLLM in front of chat-only engines                              |

Templates: `templates/config.toml`, `templates/local.config.toml`. Script: `scripts/check-endpoint.sh` (probes a Responses endpoint, prints status codes only).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `litellm`: bridges `/v1/responses` onto chat-only engines.
- `llm-gateway`: whether to use a gateway and which one.
- `vllm`, `llama-cpp`, `ollama`, `llama-swap`: the endpoints Codex talks to.
- `tool-calling-parsers`: make tool calls parse on the engine side.
- `llm-clients`: other clients (IDEs, chat UIs, SDKs).
