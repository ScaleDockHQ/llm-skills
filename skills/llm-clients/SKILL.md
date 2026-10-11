---
name: llm-clients
description: Connect coding agents, IDE extensions, chat UIs and SDK apps to any OpenAI- or Anthropic-compatible LLM endpoint (local engine, self-hosted server, gateway such as LiteLLM, or cloud API). Use when configuring Claude Code (ANTHROPIC_BASE_URL, ANTHROPIC_AUTH_TOKEN, model env vars), Codex CLI (config.toml model_providers), OpenCode (opencode.json custom provider), Aider, Cursor custom OpenAI base URL, Continue config.yaml, Cline, Roo Code or Kilo Code OpenAI-compatible providers, Open WebUI connections, LobeHub custom providers, the OpenAI SDK base_url, Anthropic SDK base_url, or Vercel AI SDK createOpenAICompatible; when a client cannot reach a local endpoint, picks the wrong API (chat completions vs Responses vs Anthropic Messages), shows no models, wrong context window, missing tool calling, vision or reasoning; or when keys must stay out of shared config.
license: MIT
compatibility: Commands assume bash, curl and jq; ruby for YAML checks. Works with any endpoint speaking OpenAI Chat Completions, OpenAI Responses or Anthropic Messages. Pairs with the llm-gateway skill for server-side fixes.
metadata:
  author: ScaleDockHQ
  version: "1.1.0"
---

# LLM Clients

Point the tools people actually use at the endpoint you run or rent: coding agents, IDE extensions, chat UIs and SDK code. This skill owns per-client configuration, capability declaration and client-side troubleshooting.

Out of scope, handled by companion skills: running the endpoint (`local-llms`, `self-hosted-llms`, `cloud-llms`), gateway config and API bridging on the server (`llm-gateway`), tracing (`llm-observability`).

## Discover first

Read-only. Prints names, paths and non-secret fields only.

```bash
# Installed CLIs
for c in claude codex opencode aider kilo; do command -v "$c" >/dev/null && echo "$c: $(command -v "$c")"; done

# Editor extensions (VS Code and Cursor)
for e in code cursor; do command -v "$e" >/dev/null && "$e" --list-extensions 2>/dev/null | grep -Ei 'continue|cline|roo|kilo|claude|openai' | sed "s/^/$e: /"; done

# Config files that exist (paths only)
ls -1 ~/.claude/settings.json .claude/settings.json ~/.codex/config.toml ~/.config/opencode/opencode.json* \
  opencode.json* ~/.continue/config.yaml .aider.conf.yml ~/.aider.conf.yml ~/.config/kilo/kilo.json* 2>/dev/null

# Non-secret fields
jq '{env_keys: ((.env // {}) | keys), model, apiKeyHelper: (.apiKeyHelper != null)}' ~/.claude/settings.json 2>/dev/null
grep -E '^\s*(model|model_provider|openai_base_url|base_url|env_key|wire_api|model_context_window)\s*=|^\[model_providers' ~/.codex/config.toml 2>/dev/null
jq '.provider // {} | map_values({npm, baseURL: .options.baseURL, models: ((.models // {}) | keys)})' ~/.config/opencode/opencode.json 2>/dev/null
ruby -ryaml -e 'c=YAML.load_file(ARGV[0]); (c["models"]||[]).each{|m| puts [m["name"], m["provider"], m["model"], m["apiBase"], (m["capabilities"]||[]).join(",")].join("\t")}' ~/.continue/config.yaml 2>/dev/null

# Env var NAMES only
env | cut -d= -f1 | grep -E '^(ANTHROPIC_|OPENAI_|CLAUDE_CODE_|OPENROUTER_|LITELLM_|OPENCODE_)' || true

# Chat UIs running in Docker
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null | grep -Ei 'open-webui|lobe' || true

# The endpoint itself: which APIs answer (key from env, never echoed)
B=http://127.0.0.1:4000
curl -fsS "$B/v1/models" -H "Authorization: Bearer $LLM_API_KEY" | jq -r '.data[].id'
```

Ask the user only for what can't be discovered: the endpoint URL they want clients to use, whether it is reachable from the internet, and which consumer key belongs to which tool.

## Decision flow

1. **Which API does the client speak?** OpenAI Chat Completions (most IDE extensions, chat UIs, Aider), OpenAI Responses (Codex CLI only speaks Responses; Vercel AI SDK `openai()` default), Anthropic Messages (Claude Code, Anthropic SDKs). If the endpoint does not serve that API, put a gateway in front (`llm-gateway`). -> `references/coding-agents.md`, `references/sdks.md`
2. **Where does the request originate?** From the user's machine (CLIs, Continue, Cline, Kilo, SDKs): `localhost` and LAN work. From the vendor's cloud (Cursor routes custom-model requests through its servers): the endpoint must be public HTTPS with auth. -> `references/ide-extensions.md`
3. **How does the client learn capabilities?** From its own model database, its config, or `/v1/models` (which carries no context or tool flags in the OpenAI shape). Plan to declare context window, tool calling, vision and reasoning in the client. -> `references/capabilities.md`
4. **Where does the key live?** Env var, OS keychain, client secret store, or a key helper command; never in a committed config file.

## Rules

- **Know which API the client speaks.** Match Chat Completions, Responses or Anthropic Messages to what the endpoint serves before debugging anything else.
- **Expose capabilities explicitly.** Declare context window, max output, tool calling, vision and reasoning in the client for every non-catalog model.
- **Use stable model names.** Configure gateway aliases (`coder`, `claude-main`), not provider or file names that change.
- **Keys in env vars or keychains, never in shared config.** Reference them (`{env:NAME}`, `${{ secrets.NAME }}`, `env_key`), keep per-tool virtual keys.
- **Test with a real tool call, not just chat.** A model that chats fine can still fail tool calls, streaming or images.

## Workflows

### Connect a coding agent (Claude Code, Codex CLI, OpenCode, Aider)

- [ ] Confirm the endpoint serves the agent's API: Messages for Claude Code, Responses for Codex, Chat Completions for OpenCode and Aider -> `references/coding-agents.md`.
- [ ] Copy the matching template (`assets/claude-code.env.example`, `codex-config.toml`, `opencode.json`, `aider.conf.yml`) and fill placeholders.
- [ ] Put the key in an env var or key helper; set model names to gateway aliases.
- [ ] Declare context window and capabilities where the agent needs them.
- [ ] Run one task that edits a file (forces tool calls) and check the agent's debug output.

### Connect an IDE extension (Cursor, Continue, Cline, Roo Code, Kilo Code)

- [ ] Check whether the extension calls from the machine or from a vendor cloud -> `references/ide-extensions.md`.
- [ ] Cursor: public HTTPS endpoint only; set the OpenAI key and base URL override, add the model name.
- [ ] Continue: `assets/continue-config.yaml` with `capabilities` and `defaultCompletionOptions.contextLength`; key via `${{ secrets.NAME }}`.
- [ ] Cline, Roo Code, Kilo Code: OpenAI Compatible provider with base URL, key, model ID, then set context window and image or tool support in model configuration.
- [ ] Run an agent-mode task that calls a tool.

### Connect a chat UI (Open WebUI, LobeHub)

- [ ] Add the endpoint as an OpenAI connection; from Docker use `host.docker.internal` for host services -> `references/chat-uis.md`.
- [ ] Restrict the model list to the aliases you want users to see.
- [ ] Set per-model capabilities (vision, tools, context) in the UI or env-based model list.
- [ ] Test image upload and a tool or web-search call on capable models.

### Connect an SDK app

- [ ] Pick the SDK client matching the endpoint's API; set base URL and key from env -> `references/sdks.md`.
- [ ] For chat-only endpoints in the Vercel AI SDK, use `createOpenAICompatible` or `openai.chat()`, not the Responses default.
- [ ] Add a tool-call integration test to CI against a staging endpoint.

### Fix model detection and capabilities

- [ ] Compare what the endpoint advertises (`/v1/models`, gateway `/v1/model/info`) with what the client shows -> `references/capabilities.md`.
- [ ] Declare missing fields client-side; fix server-side metadata via `llm-gateway` where the client reads it.
- [ ] Re-test tools, images and long prompts.

### Troubleshoot

- [ ] Reproduce with `curl` against the same base URL, key and model name the client uses.
- [ ] Match the symptom -> `references/troubleshooting.md`.
- [ ] If the server is at fault (unsupported route, rejected params), switch to the `llm-gateway` skill.

## References

| File                            | Read when                                                                         |
| ------------------------------- | --------------------------------------------------------------------------------- |
| `references/coding-agents.md`   | Stack notes: Claude Code, Codex CLI, OpenCode, Aider; depth in product skills     |
| `references/ide-extensions.md`  | Stack notes: Cursor, Continue, Cline, Kilo Code; depth in product skills          |
| `references/chat-uis.md`        | Stack notes: Open WebUI, LobeHub, LibreChat, AnythingLLM, SillyTavern             |
| `references/sdks.md`            | Stack notes: OpenAI, Anthropic, Vercel AI SDK, LangChain, LlamaIndex, Pydantic AI |
| `references/capabilities.md`    | Context window, tools, vision, reasoning detection and fixes                      |
| `references/troubleshooting.md` | Symptom to cause to fix                                                           |

Templates: `assets/claude-code.env.example`, `assets/claude-code-settings.json`, `assets/codex-config.toml`, `assets/opencode.json`, `assets/continue-config.yaml`, `assets/aider.conf.yml`, `assets/aider.model.metadata.json`, `assets/open-webui.env.example`.

## Companion skills

Install any of them with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- Per-client depth (config, capability flags, troubleshooting): `claude-code`, `codex-cli`, `opencode`, `aider`, `cursor`, `continue`, `cline`, `kilo-code`, `zed`, `goose`, `open-webui`, `lobehub`, `librechat`, `anythingllm`, `sillytavern`, `openai-sdk`, `anthropic-sdk`, `vercel-ai-sdk`, `langchain`, `llamaindex`, `pydantic-ai`.
- `llm-gateway`: one endpoint, aliases, keys, API bridging; fix server-side causes here.
- `local-llms`: endpoints on laptops and desktops.
- `self-hosted-llms`: endpoints on servers.
- `cloud-llms`: hosted APIs and their keys.
- `choosing-llm-hosting`: where models should run.
- `llm-observability`: see what clients actually send.
- `llm-evals`: compare models behind a client.
