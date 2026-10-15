---
name: aider
description: Aider, the terminal AI pair-programming tool (aider-chat, `aider`), pointed at self-hosted or gateway models through LiteLLM-style model names. Use to install or upgrade aider, set OPENAI_API_BASE with the `openai/` prefix, `ollama_chat/` or ANTHROPIC_API_BASE for vLLM, llama.cpp, Ollama, LiteLLM or llama-swap, keep keys in .env, fix edit formats, context limits, unknown-model warnings. Not Claude Code, Codex, OpenCode.
license: MIT
compatibility: Needs bash, curl and jq for the check script, Python tooling for aider, and an endpoint serving OpenAI chat completions (or Anthropic or Ollama APIs). Installs, upgrades, config edits and exposing a gateway need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Aider

Run `aider` against your own endpoint (vLLM, llama.cpp, Ollama, a LiteLLM or llama-swap gateway) with the right model prefix, safe key handling, a suitable edit format and a verified endpoint.

**Scope:** the Aider CLI, its YAML, `.env` and model settings files. Gateways and engines belong to their own skills. Aider talks to models through the LiteLLM client library, so a model name is `<provider>/<name>`; for any OpenAI-compatible server the provider is `openai`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Never print keys.

```bash
command -v aider && aider --version
ls -l ~/.aider.conf.yml .aider.conf.yml .env ~/.env .aider.model.settings.yml .aider.model.metadata.json 2>/dev/null
env | grep -E '^(OPENAI|ANTHROPIC|OLLAMA|AIDER|LITELLM)_' | sed -E 's/=.*/=<set>/'
```

## Decision flow

1. **OpenAI-compatible endpoint** (vLLM, llama.cpp, llama-swap, LiteLLM, many others): `OPENAI_API_BASE` plus `--model openai/<served-name>`. -> `references/custom-endpoints.md`
2. **Ollama:** `OLLAMA_API_BASE` plus `--model ollama_chat/<model>`, and fix the context window. -> `references/custom-endpoints.md`
3. **Anthropic-format endpoint:** `anthropic/<name>` with `ANTHROPIC_API_BASE` (LiteLLM behavior, not documented by aider). -> `references/custom-endpoints.md`
4. **Context window, costs, edit format, weak and editor models, reasoning:** -> `references/models-and-limits.md`
5. **Edits fail or garble, streaming, tools, reasoning tags:** -> `references/compatibility.md`
6. **Install or update:** -> `references/install-and-update.md`
7. **Error text:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, editing config files, shell profile exports and exposing a gateway need approval and an undo path (copy the file first).
- **Secrets never touch output or git.** Keys go in a `0600` `.env` or the environment; `.env` stays in `.gitignore`. Do not use `--api-key` on the command line (it lands in shell history and `ps`). Check presence with `[ -n "${VAR:-}" ]`, never `echo`.
- **Prefix the model.** `openai/<served-name>` for OpenAI-compatible endpoints, `ollama_chat/` (not `ollama/`) for Ollama. A bare name selects a built-in provider.
- **Only OpenAI and Anthropic keys go in the YAML.** Other provider keys belong in `.env` or the environment.
- **Aider never enforces token limits.** The "unknown context window" warning is usually harmless; real limits are enforced by the server, and Ollama's small default window silently truncates.
- **Match the edit format to the model.** Small local models often need `whole`; set it per model in `.aider.model.settings.yml`.
- **Test the endpoint first.** `scripts/check-endpoint.sh` before blaming Aider.
- **Verify upstream.** Flags and defaults come from the aider docs and PyPI release read on the writing date.

## Workflows

### Connect to a self-hosted endpoint

- [ ] Run discovery; back up existing config files.
- [ ] Put the key in a `0600` file and export it: `export OPENAI_API_KEY="$(cat ~/.config/llm/key)"` (any non-empty value for keyless servers).
- [ ] `CHECK_BASE_URL=http://HOST:PORT/v1 CHECK_MODEL=<served-name> scripts/check-endpoint.sh` returns ok.
- [ ] Copy `templates/aider.conf.yml` and `templates/env.example` (as `.env`); add model settings and metadata from `templates/` for the served model.
- [ ] `aider --model openai/<served-name>`, ask for a one-file edit, check `/tokens`.

### Fix a broken local setup

- [ ] Auth, 404 or model errors: `references/troubleshooting.md`.
- [ ] Bad or empty edits: `references/compatibility.md` (edit formats), then `references/models-and-limits.md` (context).

## Reference index

| File                                   | Read when                                                           |
| -------------------------------------- | ------------------------------------------------------------------- |
| `references/custom-endpoints.md`       | Base URLs, prefixes, keys, headers, per-engine setup                |
| `references/models-and-limits.md`      | Model metadata, model settings, weak and editor models, reasoning   |
| `references/compatibility.md`          | Edit formats, streaming, tool calls, reasoning tags, engine caveats |
| `references/install-and-update.md`     | Install paths, upgrading, config file locations                     |
| `references/troubleshooting.md`        | Symptom to cause to fix                                             |
| `references/combos/litellm-gateway.md` | LiteLLM in front of local engines                                   |

Templates: `templates/aider.conf.yml`, `templates/env.example`, `templates/aider.model.settings.yml`, `templates/aider.model.metadata.json`. Script: `scripts/check-endpoint.sh` (probes a chat completions endpoint, prints status codes only).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `litellm`: one gateway for several engines.
- `llm-gateway`: whether to use a gateway and which one.
- `vllm`, `llama-cpp`, `ollama`, `llama-swap`: the endpoints Aider talks to.
- `llm-clients`: other clients (IDEs, chat UIs, SDKs).
