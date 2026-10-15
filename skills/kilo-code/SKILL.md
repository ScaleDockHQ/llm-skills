---
name: kilo-code
description: "Configure Kilo Code (VS Code, JetBrains, kilo CLI) for self-hosted LLMs through Custom provider or kilo.jsonc, picking OpenAI Compatible, OpenAI Responses or Anthropic Messages per endpoint, with baseURL, keys, model id mapping and context limits for vLLM, llama.cpp, Ollama, LiteLLM and llama-swap. Use for kilo.json, limit.context, tool_call, auto-fetch models, or compaction not working."
license: MIT
compatibility: Kilo Code extension for VS Code or JetBrains, or the kilo CLI (@kilocode/cli). Probe script needs bash, curl and jq. Editing kilo.jsonc or provider credentials needs the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Kilo Code

Connect Kilo Code to your own endpoint with the right wire API, credentials that never land in a repo, and `limit.context` and `limit.output` set so context management works.

**Scope:** Kilo Code only: custom providers in the extension and in `kilo.jsonc`, key handling, model mapping, tool-calling and streaming caveats, troubleshooting. Serving belongs to `vllm`, `llama-cpp`, `ollama`, `llama-swap`; the gateway to `litellm`. Other clients: `cline`, `continue`, `cursor`, `llm-clients`. Roo Code, an ancestor of Kilo, is archived and has no skill.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
code --list-extensions --show-versions 2>/dev/null | grep -i kilocode
command -v kilo && kilo --version
kilo debug paths 2>/dev/null                                   # where config, data, cache live
ls -l ~/.config/kilo/ ./kilo.json ./kilo.jsonc 2>/dev/null     # config files and modes
jq -r '.provider // {} | to_entries[] | "\(.key) \(.value.npm // "default") \(.value.options.baseURL // "-")"' ~/.config/kilo/kilo.json 2>/dev/null   # ids and URLs, no keys
kilo models 2>/dev/null | head -20                             # models Kilo can use now
env | cut -d= -f1 | grep -E '^(KILO|LLM|LITELLM)_' || true     # names only
gh api repos/Kilo-Org/kilocode/releases --jq '[.[]|select(.tag_name|test("^v[0-9]"))][0].tag_name'
LLM_API_KEY_FILE=~/.config/llm/kilo.key scripts/probe.sh http://127.0.0.1:4000/v1 coder
```

`kilo.jsonc` allows comments; `jq` only reads a strict-JSON `kilo.json`. Ask only what discovery cannot show: which wire API the endpoint speaks, gateway or engine, extension or CLI, global or project config.

## Decision flow

1. **Endpoint serves OpenAI Chat Completions** (vLLM, llama.cpp, LiteLLM, llama-swap, Ollama `/v1`): Provider API "OpenAI Compatible" (`@ai-sdk/openai-compatible`, the default). -> `references/providers-endpoints.md`
2. **Endpoint serves the OpenAI Responses API:** "OpenAI Responses" (`@ai-sdk/openai`). -> `references/providers-endpoints.md`
3. **Endpoint serves Anthropic Messages** (LiteLLM `/v1/messages`, a bridge): "Anthropic Messages" (`@ai-sdk/anthropic`). -> `references/providers-endpoints.md`
4. **Ollama or LM Studio on the same host:** their built-in providers. -> `references/providers-endpoints.md`
5. **Per-engine values:** -> `references/combos/self-hosted-endpoints.md`
6. **Context never compacts, tools missing, models not listed:** -> `references/troubleshooting.md`
7. **Install, CLI, version drift:** -> `references/install.md`, `references/updating.md`

## Rules

- **Ask before changing the system.** Show the `kilo.jsonc` diff first; keep a backup copy and name the restore step.
- **Secrets never touch output.** Reference keys as `{env:NAME}` or `{file:/path}` and keep them in your global config (`~/.config/kilo`) and `0600` files. A project-level `kilo.json` cannot resolve `{env:}` (by design) and must never hold a literal `apiKey`. Never print config files that may contain keys.
- **Set `limit.context` and `limit.output`** for every custom or local model. Unset limits resolve to `0`: compaction is disabled, output falls back to 32,000 tokens, usage tracking is skipped.
- **Set `tool_call: true`** for models that must edit files or run commands.
- **Trim auto-fetched model lists.** The picker lists everything the key can see; keep the aliases you want.
- **Azure GPT-5 is not custom-provider territory.** Use the native `azure` provider; generic providers send `max_tokens`.
- **Verify upstream.** Kilo ships quickly; kilo.ai/docs and the releases page are the source of truth at use time.

## Workflows

### Add a self-hosted model (extension)

- [ ] Probe: `scripts/probe.sh <base>/v1 <model>`; note `tool_calls`.
- [ ] Settings > Providers > Custom provider: Provider ID, Display name, Provider API, Base URL, API key, Models (or Fetch models), Headers if needed; Submit.
- [ ] Open the config and add `limit`, `tool_call` and `modalities` per model (see `assets/kilo.jsonc`).
- [ ] Select `provider_id/model_id`; ask the agent to create a file; confirm path and model in the gateway log.

### Add a self-hosted model (CLI or advanced)

- [ ] Copy the relevant block from `assets/kilo.jsonc` into `~/.config/kilo/kilo.jsonc`.
- [ ] Keep the key in `{env:LLM_API_KEY}` (exported in the shell that starts `kilo`) or `{file:/home/you/.config/llm/kilo.key}`.
- [ ] `kilo models` lists it; `kilo debug config` shows the resolved config; run `kilo -m provider_id/model_id`.

## Reference index

| File                                         | Read when                                                          |
| -------------------------------------------- | ------------------------------------------------------------------ |
| `references/install.md`                      | Extension, JetBrains, CLI install; config locations; versions      |
| `references/providers-endpoints.md`          | Custom provider fields, kilo.jsonc schema, wire APIs, keys, limits |
| `references/combos/self-hosted-endpoints.md` | Exact entries per vLLM, llama.cpp, Ollama, LiteLLM, llama-swap     |
| `references/troubleshooting.md`              | Symptom to cause to fix                                            |
| `references/updating.md`                     | Updating, version lines, re-verification                           |

Template: `assets/kilo.jsonc`. Script: `scripts/probe.sh` (read-only; key from `LLM_API_KEY` or `LLM_API_KEY_FILE`).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `litellm`: gateway with scoped virtual keys and aliases for Kilo.
- `llm-gateway`: whether to use a gateway at all.
- `llm-clients`: other coding agents and IDE extensions.
- `cline`, `continue`, `cursor`: other editor clients.
- `vllm`, `llama-cpp`, `ollama`, `llama-swap`: serving the model Kilo talks to.
