---
name: continue
description: Configure Continue (VS Code, JetBrains, cn CLI) for self-hosted LLMs via ~/.continue/config.yaml, with apiBase, secrets in ~/.continue/.env, roles, capabilities and model-name mapping for vLLM, llama.cpp, Ollama, LiteLLM and llama-swap, OpenAI- or Anthropic-style. Use for Continue config.yaml, apiBase, tool_use, Agent mode greyed out, useResponsesApi, autocomplete or fetch failed errors.
license: MIT
compatibility: VS Code or JetBrains with the Continue extension, or the cn CLI (Node 20+ for the npm install). Probe script needs bash, curl and jq. Edits to ~/.continue need the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Continue

Wire Continue's chat, edit, apply and autocomplete roles to your own endpoint with a valid `config.yaml`, keys kept out of the file, and capabilities declared so Agent mode works.

**Scope:** Continue only: config.yaml models for custom OpenAI-compatible and Anthropic-compatible base URLs, secrets, roles, capabilities, tool-calling and streaming caveats, troubleshooting. Serving belongs to `vllm`, `llama-cpp`, `ollama`, `llama-swap`; the gateway to `litellm`. Other clients: `cursor`, `cline`, `kilo-code`, `llm-clients`.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
ls -l ~/.continue/config.yaml ~/.continue/.env                                   # present, and file modes
stat -f '%Sp %N' ~/.continue/.env 2>/dev/null || stat -c '%A %n' ~/.continue/.env    # should be -rw-------
grep -nE '^\s*(- name|provider|model|apiBase|roles|capabilities):' ~/.continue/config.yaml 2>/dev/null   # no apiKey lines
grep -oE '^[A-Za-z_][A-Za-z0-9_]*' ~/.continue/.env 2>/dev/null                      # secret names only
code --list-extensions --show-versions 2>/dev/null | grep -i continue.continue
command -v cn && cn --version
gh api repos/continuedev/continue/releases --jq '[.[]|select(.tag_name|test("vscode"))][0].tag_name'
LLM_API_KEY_FILE=~/.config/llm/continue.key scripts/probe.sh http://127.0.0.1:4000/v1 coder
```

Ask only what discovery cannot show: which endpoint (gateway or engine), whether Continue runs on the same machine or in a container or remote workspace, which roles (chat, edit, apply, autocomplete, embed) and which models serve them.

## Decision flow

1. **Endpoint speaks OpenAI Chat Completions** (vLLM, llama.cpp, LiteLLM, llama-swap, Ollama `/v1`): `provider: openai` with `apiBase` ending in `/v1`. -> `references/config-endpoints.md`
2. **Endpoint speaks Anthropic Messages** (LiteLLM `/v1/messages`, a gateway bridge): `provider: anthropic` with `apiBase` ending in `/v1`. -> `references/config-endpoints.md`
3. **Ollama directly:** `provider: ollama` with the bare host (no `/v1`). -> `references/config-endpoints.md`
4. **Which values per engine:** -> `references/combos/self-hosted-endpoints.md`
5. **Keys and secrets:** `${{ secrets.NAME }}` plus `~/.continue/.env`. -> `references/config-endpoints.md`
6. **Agent mode unavailable, tools ignored, wrong API sent:** -> `references/troubleshooting.md`
7. **Install, CLI, version checks, new release:** -> `references/install.md`, `references/updating.md`

## Rules

- **Ask before changing the system.** Edit `~/.continue/config.yaml` only after showing the diff; keep a backup copy and say how to restore it.
- **Secrets never touch output.** Reference keys as `${{ secrets.NAME }}`; store values in `~/.continue/.env` with mode `0600`. Never write a literal `apiKey` or an `Authorization` header into a file that may be committed, and never print the file.
- **IDE extensions cannot read shell exports.** `export X=...` helps only the `cn` CLI; for VS Code and JetBrains use the `.env` files, then restart the IDE.
- **Capabilities only add.** `capabilities: [tool_use]` cannot remove autodetected behaviour; an empty list does not disable anything.
- **Neutral aliases.** A gateway alias matching `o<digit>` or `gpt-5`-style names makes Continue use the Responses API; rename it or set `useResponsesApi: false`.
- **`apiBase` is joined to endpoints by URL rules.** Continue adds a trailing slash; give `/v1` for OpenAI and Anthropic styles, none for the Ollama provider.
- **Verify upstream.** Fields come from docs.continue.dev and the repository at use time; the schema is `schema: v1`, `config.json` is deprecated.

## Workflows

### Add a self-hosted model

- [ ] Probe the endpoint: `scripts/probe.sh <base>/v1 <model>`; note `tool_calls`.
- [ ] Put the key in `~/.continue/.env` (`0600`); copy `assets/config.yaml` entries into `~/.continue/config.yaml`.
- [ ] Set `roles`, `capabilities`, `defaultCompletionOptions.contextLength` and `maxTokens` at or below the engine's real limits.
- [ ] Reload the window ("Developer: Reload Window"); pick the model; ask for a file edit in Agent mode.
- [ ] Check the gateway log for the path (`/v1/chat/completions` or `/v1/messages`) and model name.

### Add autocomplete on a local model

- [ ] A FIM-capable model with `roles: [autocomplete]` and `autocompleteOptions`; verify the endpoint supports the route Continue uses. -> `references/config-endpoints.md`

## Reference index

| File                                         | Read when                                                                |
| -------------------------------------------- | ------------------------------------------------------------------------ |
| `references/install.md`                      | Extension, JetBrains, `cn` CLI install, files and versions               |
| `references/config-endpoints.md`             | config.yaml fields, OpenAI/Anthropic/Ollama/llama.cpp providers, secrets |
| `references/combos/self-hosted-endpoints.md` | Exact entries per vLLM, llama.cpp, Ollama, LiteLLM, llama-swap           |
| `references/troubleshooting.md`              | Symptom to cause to fix                                                  |
| `references/updating.md`                     | Updating, config migration, re-verification                              |

Template: `assets/config.yaml`. Script: `scripts/probe.sh` (read-only; key from `LLM_API_KEY` or `LLM_API_KEY_FILE`).

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `litellm`: gateway with scoped virtual keys and aliases for Continue.
- `llm-gateway`: whether to use a gateway at all.
- `llm-clients`: other coding agents and IDE extensions.
- `cursor`, `cline`, `kilo-code`: other editor clients.
- `vllm`, `llama-cpp`, `ollama`, `llama-swap`: serving the model Continue talks to.
