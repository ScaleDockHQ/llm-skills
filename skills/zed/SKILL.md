---
name: zed
description: Zed, the Rust code editor with a built-in Agent Panel, Inline Assistant and edit prediction. Use to point Zed at self-hosted or gateway endpoints (vLLM, llama.cpp, Ollama, LM Studio, LiteLLM, llama-swap) through openai_compatible or anthropic_compatible providers, map model names and context sizes, handle API keys, tool calling and reasoning, set edit prediction, update, or fix 401, 404, no tools, empty models. Not for choosing a client (llm-clients).
license: MIT
compatibility: Zed stable on macOS, Linux or Windows. Commands assume bash, curl and jq; settings.json is JSONC, so jq cannot read it. Editing settings and secrets, and restarting Zed, need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Zed

Zed (`zed-industries/zed`, binary `zed`) talking to your own model endpoint: the Agent Panel, Inline Assistant, commit-message generation, thread summaries and edit prediction all use models you configure in `settings.json`, with keys kept in the system keychain or environment.

**Scope:** Zed's own AI features and their provider settings. External Agents (Claude, Codex, OpenCode and others over ACP) and Terminal Threads own their model config; use the matching client skill for those. Choosing among clients, and capability tables across clients, belong to `llm-clients`. Running the endpoint belongs to the engine, `litellm` or `llama-swap` skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
command -v zed && zed --version 2>/dev/null                                        # installed build
ls -la ~/.config/zed/settings.json .zed/settings.json 2>/dev/null                    # user and project settings (Windows: %APPDATA%\Zed)
rg -n 'language_models|openai_compatible|anthropic_compatible|default_model|edit_predictions' ~/.config/zed/settings.json .zed/settings.json 2>/dev/null
env | cut -d= -f1 | grep -E '_API_KEY$' | sort                                      # key variable NAMES only
B="${LLM_BASE_URL:-http://localhost:4000/v1}"
curl -fsS -m 5 "$B/models" -H "Authorization: Bearer ${LLM_API_KEY:-none}" | jq -r '.data[].id' | head -20
gh api repos/zed-industries/zed/releases/latest --jq .tag_name                       # newest stable
```

Ask only what discovery cannot show: which endpoint and API shape (OpenAI Chat Completions, OpenAI Responses, Anthropic Messages), the model id and real context window, whether the model supports tools and images, and whether Zed starts from a shell or from the Dock.

## Decision flow

1. **Endpoint speaks OpenAI `/v1/chat/completions`** (vLLM, llama.cpp, LiteLLM, llama-swap, LM Studio): `language_models.openai_compatible`. -> `references/custom-endpoints.md`
2. **Endpoint speaks Anthropic `/v1/messages`** (LiteLLM, llama-swap, vLLM, llama.cpp, a Claude-shaped gateway): `language_models.anthropic_compatible`. -> `references/custom-endpoints.md`
3. **Plain local Ollama, llama.cpp or LM Studio on this machine:** use the built-in providers with auto-discovery. -> `references/local-providers.md`
4. **Model works in curl but the agent has no tools, shows no thinking, or answers truncated:** capabilities and context. -> `references/models-and-features.md`
5. **Tab completion from a self-hosted model:** a separate `edit_predictions` provider. -> `references/edit-prediction.md`
6. **Install, channels, settings locations, update:** -> `references/install.md`
7. **Error or odd behavior:** -> `references/troubleshooting.md`
8. **Gateway in front of local engines:** -> `references/combos/litellm-llama-swap.md`

## Rules

- **Ask before changing the system.** Editing `settings.json`, exporting keys, restarting Zed and changing how it is launched need approval; copy `settings.json` to a dated backup first.
- **Secrets never touch output or `settings.json`.** Enter the key in Agent Settings (system keychain) or export `<PROVIDER>_API_KEY` for the Zed process; check presence by variable name only. Non-empty env vars win over the keychain.
- **Name is the wire id.** Each model's `name` is sent as the `model` field; `display_name` is cosmetic. Use the exact alias the endpoint lists in `/v1/models`.
- **Declare capabilities.** Zed does not learn tools, images or context from a standard `/v1/models` reply for generic providers; set `max_tokens`, `max_output_tokens` and `capabilities` per model.
- **Context is a ceiling you set.** `max_tokens` is the context window, so keep it at or below what the engine was started with.
- **Mind the base URL.** OpenAI-compatible `api_url` ends at the API root (usually `.../v1`); the documented Anthropic-compatible example has no `/v1`. Verify with the request log, not by guessing.
- **Keys and endpoints are local to the Zed app.** SSH and dev-container projects read keys from the local keychain and local process environment.
- **Verify upstream.** Setting names, defaults and provider ids come from zed.dev/docs (AI section) and releases at use time, not memory.

## Workflows

### Connect one self-hosted endpoint

- [ ] Run Discover; `curl` `/models` and one chat completion with the intended key.
- [ ] Add a provider block from `assets/settings.openai-compatible.jsonc` (or the Anthropic variant) with exact model names, context and capabilities -> `references/custom-endpoints.md`.
- [ ] Put the key in Agent Settings or export `<PROVIDER_ID>_API_KEY`; restart Zed if it came from the environment.
- [ ] Pick the model in the Agent Panel; send "list files in this project" to prove tools work -> `references/models-and-features.md`.
- [ ] Optionally set `agent.default_model` and the feature models (commit message, summaries).

### Use a gateway for many models

- [ ] One provider block per gateway, one `available_models` entry per alias -> `references/combos/litellm-llama-swap.md`.
- [ ] Give Zed a least-privilege virtual key, not the master key.

### Tab completion from a self-hosted model

- [ ] Choose a FIM-capable base model and a prompt format; point `edit_predictions` at `/v1/completions` -> `references/edit-prediction.md`.

### Update

- [ ] `brew upgrade --cask zed`, or let Zed auto-update, or re-run the installer; read the release notes for AI changes -> `references/install.md`.
- [ ] Re-check provider ids and capability keys after a major bump.

## Reference index

| File                                      | Read when                                                                                |
| ----------------------------------------- | ---------------------------------------------------------------------------------------- |
| `references/install.md`                   | Install, channels, settings locations, project settings, update                          |
| `references/custom-endpoints.md`          | `openai_compatible` and `anthropic_compatible` fields, keys, headers                     |
| `references/models-and-features.md`       | Capabilities, tool calling, reasoning, streaming, default and feature models, compaction |
| `references/local-providers.md`           | Built-in Ollama, llama.cpp and LM Studio providers, remote hosts                         |
| `references/edit-prediction.md`           | Self-hosted tab completion, prompt formats                                               |
| `references/troubleshooting.md`           | Symptom to cause to fix                                                                  |
| `references/combos/litellm-llama-swap.md` | Gateway and swap proxy in front of engines                                               |

Template: `assets/settings.openai-compatible.jsonc`, `assets/settings.anthropic-compatible.jsonc`.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `llm-clients`: choosing a client, shared capability and troubleshooting notes.
- `litellm`: the gateway that gives Zed one endpoint, virtual keys and `/v1/messages`.
- `llama-swap`: hot-swapping local models behind one URL.
- `vllm`, `llama-cpp`, `ollama`, `lm-studio`: the engines Zed connects to; their skills own tool-parser and context flags.
