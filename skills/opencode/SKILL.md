---
name: opencode
description: OpenCode, the open-source terminal coding agent (anomalyco/opencode, formerly sst), pointed at self-hosted or gateway models through custom OpenAI-compatible or Anthropic-compatible providers. Use to install or upgrade `opencode`, write opencode.json provider blocks (baseURL, apiKey {env:}, models limit, tool_call) for vLLM, llama.cpp, Ollama, LiteLLM or llama-swap, handle keys, v1 vs v2 config, fix tool calls, context, image paste. Not Claude Code, Codex, Aider.
license: MIT
compatibility: Needs bash, curl and jq for the check script, and an endpoint serving OpenAI chat completions, Responses or Anthropic messages. Installs, upgrades, config edits and exposing a gateway need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# OpenCode

Run `opencode` against your own endpoint (vLLM, llama.cpp, Ollama, a LiteLLM or llama-swap gateway) with a declared provider, safe key handling, correct model limits and capability flags, and a verified endpoint.

**Scope:** the OpenCode CLI/TUI and its config. Two config generations exist: OpenCode 1 (latest GitHub release v1.19.0 at write time; `provider` key, `npm` package names) and OpenCode 2 (`providers` key, `package` names, local auto-discovery). Detect which is installed before editing.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print keys.

```bash
command -v opencode && opencode --version
ls -l ~/.config/opencode/opencode.json* opencode.json* 2>/dev/null
jq -r '(.provider // .providers // {}) | keys | join(", ")' ~/.config/opencode/opencode.json 2>/dev/null
opencode auth list                      # provider names only, from ~/.local/share/opencode/auth.json
env | grep -E '^(OPENCODE|OPENAI|ANTHROPIC|LITELLM)_' | sed -E 's/=.*/=<set>/'
```

A top-level `provider` object means v1 config; `providers` means v2.

## Decision flow

1. **OpenAI-compatible endpoint (chat completions)** (vLLM, llama.cpp, Ollama, llama-swap, LiteLLM): v1 `@ai-sdk/openai-compatible` provider. -> `references/custom-providers.md`
2. **Endpoint serves Responses, or Anthropic Messages:** `@ai-sdk/openai` or `@ai-sdk/anthropic`. -> `references/custom-providers.md`
3. **OpenCode 2 installed:** -> `references/opencode-2.md`
4. **Limits, capability flags, small model, reasoning, images:** -> `references/models-and-limits.md`
5. **Tool calls, streaming, timeouts misbehave:** -> `references/compatibility.md`
6. **Install, upgrade, storage, logs:** -> `references/install-and-update.md`
7. **Error text:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, editing `opencode.json`, shell profile exports and exposing a gateway need approval and an undo path (copy the file first).
- **Secrets never touch output or git.** Use `"apiKey": "{env:NAME}"` or `"{file:~/.secrets/key}"`, or `/connect` (stores in `~/.local/share/opencode/auth.json`). Never paste a key into a committed `opencode.json`. Check by name with `opencode auth list` or `[ -n "${NAME:-}" ]`.
- **Pick the package by wire format.** `@ai-sdk/openai-compatible` = `/v1/chat/completions`; `@ai-sdk/openai` = `/v1/responses`; `@ai-sdk/anthropic` = `/v1/messages`. Model IDs must equal what `GET /v1/models` returns.
- **Declare limits and capabilities.** Custom models need `limit.context` and `limit.output` (both required by the schema); set `tool_call`, `reasoning`, `attachment`, `modalities` truthfully.
- **Provider ID consistency.** The ID used with `/connect` must equal the key in `opencode.json`.
- **Test the endpoint first.** `scripts/check-endpoint.sh` before blaming OpenCode.
- **Verify upstream.** Fields and defaults come from opencode.ai docs and the JSON schema read on the writing date.

## Workflows

### Connect to a self-hosted endpoint

- [ ] Run discovery; back up the config file.
- [ ] `OPENCODE_BASE_URL=http://HOST:PORT/v1 OPENCODE_MODEL=<served-name> scripts/check-endpoint.sh` returns ok for models, plain, stream and tools.
- [ ] Put the key in `0600` file or env var; add the provider block from `templates/opencode.json`.
- [ ] `opencode models` lists `<provider>/<model>`; `opencode run -m <provider>/<model> "say ok"`; then one real edit in the TUI.

### Tools or context misbehave

- [ ] Tool calls not executing: engine parser/template first, then `tool_call: true`. -> `references/compatibility.md`
- [ ] Window mismatch or compaction late: fix `limit.context` and the server's window. -> `references/models-and-limits.md`

## Reference index

| File                                   | Read when                                                     |
| -------------------------------------- | ------------------------------------------------------------- |
| `references/custom-providers.md`       | v1 provider blocks, keys, headers, timeouts, per-engine setup |
| `references/models-and-limits.md`      | Limits, capability flags, variants, small_model, compaction   |
| `references/compatibility.md`          | Tools, streaming, reasoning fields, engine caveats            |
| `references/opencode-2.md`             | OpenCode 2 `providers` config and local discovery             |
| `references/install-and-update.md`     | Install paths, upgrade, v1/v2 conflict, storage, logs         |
| `references/troubleshooting.md`        | Symptom to cause to fix                                       |
| `references/combos/litellm-gateway.md` | LiteLLM in front of local engines                             |

Templates: `templates/opencode.json` (v1), `templates/opencode-v2.jsonc`. Script: `scripts/check-endpoint.sh` (probes a chat-completions endpoint, prints status codes only).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `litellm`, `llm-gateway`: gateway to bridge and manage endpoints.
- `vllm`, `llama-cpp`, `ollama`, `llama-swap`: the endpoints OpenCode talks to.
- `tool-calling-parsers`: make tool calls parse on the engine side.
- `llm-clients`: other clients (IDEs, chat UIs, SDKs).
