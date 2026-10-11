---
name: cline
description: Configure Cline (VS Code, JetBrains, CLI, desktop) for self-hosted LLMs with the OpenAI Compatible, Anthropic custom base URL, Ollama or LiteLLM providers (base URL, key handling, model ID, context window and output limits, compact prompt, proxies). Use for vLLM, llama.cpp, Ollama, LiteLLM, llama-swap behind Cline, cline auth, providers.json, "Model Not Found" or tool-call failures.
license: MIT
compatibility: Cline extension for VS Code or JetBrains, or the cline CLI (npm i -g cline). Probe script needs bash, curl and jq. Changing provider settings or files under ~/.cline needs the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Cline

Point Cline at your own endpoint with the right provider, a key that is not echoed anywhere, and context and output limits that match the served model.

**Scope:** Cline only: provider settings for custom OpenAI-compatible and Anthropic-compatible base URLs, local runtimes, `~/.cline` config, CLI auth, proxies, tool-calling and streaming caveats, troubleshooting. Serving belongs to `vllm`, `llama-cpp`, `ollama`, `llama-swap`; the gateway to `litellm`. Other clients: `continue`, `kilo-code`, `cursor`, `llm-clients`. (Roo Code, a Cline fork, is archived and has no skill.)

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
code --list-extensions --show-versions 2>/dev/null | grep -i saoudrizwan.claude-dev
command -v cline && cline version
ls -l ~/.cline/data/settings/ 2>/dev/null                    # providers.json holds keys: should be owner-only
jq -r 'keys[]?' ~/.cline/data/settings/providers.json 2>/dev/null || true   # provider ids only, never values
env | cut -d= -f1 | grep -E '^(CLINE|OPENAI|ANTHROPIC|LLM|https?_proxy|no_proxy|NODE_EXTRA_CA_CERTS)' || true   # names only
gh api repos/cline/cline/releases --jq '[.[]|select(.tag_name|test("^v"))][0].tag_name'
LLM_API_KEY_FILE=~/.config/llm/cline.key scripts/probe.sh http://127.0.0.1:4000/v1 coder
```

Ask only what discovery cannot show: IDE extension or CLI, gateway or engine, whether the endpoint is on the same machine, and whether a corporate proxy or private CA is involved.

## Decision flow

1. **Endpoint speaks OpenAI Chat Completions** (vLLM, llama.cpp, LiteLLM, llama-swap): provider "OpenAI Compatible". -> `references/providers-endpoints.md`
2. **Endpoint speaks Anthropic Messages:** provider "Anthropic" with "Use custom base URL". -> `references/providers-endpoints.md`
3. **Ollama or LM Studio on the same host:** their dedicated providers, plus Use Compact Prompt. -> `references/providers-endpoints.md`
4. **Per-engine values:** -> `references/combos/self-hosted-endpoints.md`
5. **CLI, headless, `~/.cline` files, proxies, CA:** -> `references/install.md`
6. **Model Not Found, truncated context, no tool use, hangs:** -> `references/troubleshooting.md`
7. **New release or version drift:** -> `references/updating.md`

## Rules

- **Ask before changing the system.** Provider settings, `~/.cline` files and proxy variables are changes; state the undo (re-select the previous provider, restore the backup).
- **Secrets never touch output.** `~/.cline/data/settings/providers.json` holds API keys; keep it owner-only, never print or commit it, list provider ids only. Prefer the interactive `cline auth` over `-k <key>` because command-line keys land in shell history and process lists.
- **Set Context Window and Max Output explicitly** for every non-catalog model; defaults rarely match a local model. Keep them at or below what the engine serves.
- **Local models: Use Compact Prompt.** Cline's local-model guidance enables it (Settings > Features) and recommends short, focused tasks.
- **Neutral aliases.** Use the gateway alias as Model ID; it is sent verbatim.
- **Proxies differ by surface.** The VS Code extension follows VS Code proxy settings; the CLI uses `http_proxy`, `https_proxy`, `no_proxy`, `NODE_EXTRA_CA_CERTS` and supports HTTP proxies only.
- **Verify upstream.** Cline moved fast (SDK, CLI v3, desktop); docs.cline.bot and the releases page are the source of truth at use time.

## Workflows

### Connect a self-hosted model in the IDE

- [ ] Probe the endpoint with `scripts/probe.sh`; note `tool_calls`.
- [ ] Settings (gear) > API Provider "OpenAI Compatible": Base URL `http://host:port/v1`, API Key (paste from a `0600` file, do not share), Model ID = alias.
- [ ] Model Configuration: Context Window, Max Output Tokens, Image Support (only if the model has vision).
- [ ] Click Verify if shown; run a small task that edits a file; check the gateway log for path and model name.

### Connect from the CLI

- [ ] `cline auth` (interactive) and choose the provider, base URL, key and model. Scripted form: `cline auth -p <provider> -b <baseurl> -m <model>` with the key entered interactively.
- [ ] `cline "create hello.txt with the word hi"`; `cline doctor log` opens the log on failure.

## Reference index

| File                                         | Read when                                                              |
| -------------------------------------------- | ---------------------------------------------------------------------- |
| `references/install.md`                      | IDE, CLI, desktop install; `~/.cline` layout; env vars; proxies and CA |
| `references/providers-endpoints.md`          | OpenAI Compatible, Anthropic base URL, Ollama, LiteLLM, model config   |
| `references/combos/self-hosted-endpoints.md` | Exact values per vLLM, llama.cpp, Ollama, LiteLLM, llama-swap          |
| `references/troubleshooting.md`              | Symptom to cause to fix                                                |
| `references/updating.md`                     | Updating IDE and CLI, version drift                                    |

Script: `scripts/probe.sh` (read-only; key from `LLM_API_KEY` or `LLM_API_KEY_FILE`).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llms-skills --skill <name>`.

- `litellm`: gateway with scoped virtual keys for Cline.
- `llm-gateway`: whether to use a gateway at all.
- `llm-clients`: other coding agents and IDE extensions.
- `kilo-code`, `continue`, `cursor`: other editor clients.
- `vllm`, `llama-cpp`, `ollama`, `llama-swap`: serving the model Cline talks to.
