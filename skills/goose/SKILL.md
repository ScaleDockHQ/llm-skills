---
name: goose
description: goose, the open-source AI agent (Desktop app and `goose` CLI, aaif-goose/goose, formerly block/goose) with MCP extensions. Use to point goose at self-hosted or gateway endpoints (vLLM, llama.cpp, Ollama, LM Studio, LiteLLM, llama-swap) via OPENAI_HOST, custom_providers JSON or the Ollama provider, handle keys, map models and context, enable the tool shim, update, or fix 404, 401 No api key passed in, keyring errors, no tool calls. Not for choosing a client (llm-clients).
license: MIT
compatibility: goose Desktop or CLI on macOS, Linux or Windows. Commands assume bash, curl and jq. Installing goose, writing config and provider files, and handling secrets need the user's explicit approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# goose

A working goose (`aaif-goose/goose`, Apache-2.0, binary `goose`) that talks to your own OpenAI-compatible, Anthropic-compatible or Ollama-style endpoint, with its key in the keyring or environment, the right model and context settings, and tool calling that actually runs.

**Scope:** goose's model providers and the settings that decide whether tools, streaming and long sessions work. MCP extension authoring, recipes and goose's permission modes beyond what affects provider setup are out of scope. Choosing among clients belongs to `llm-clients`. Running the endpoint belongs to the engine, `litellm` or `llama-swap` skills.

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only, never prints secret values.

```bash
command -v goose && goose --version 2>/dev/null                                      # CLI build
rg -n "^(active_provider|GOOSE_|  [a-z_]+:$)" ~/.config/goose/config.yaml 2>/dev/null | head -30   # provider and settings (keys never live here)
ls -la ~/.config/goose/ ~/.config/goose/custom_providers/ 2>/dev/null                # config.yaml, secrets.yaml (if file storage), custom providers (Windows: %APPDATA%\Block\goose\config)
env | cut -d= -f1 | grep -E '^(GOOSE_|OPENAI_|ANTHROPIC_|OLLAMA_|LITELLM_|LMSTUDIO_|LLAMA_SWAP_)' | sort   # variable NAMES only
B="${LLM_BASE_URL:-http://localhost:4000/v1}"
curl -fsS -m 5 "$B/models" -H "Authorization: Bearer ${LLM_API_KEY:-none}" | jq -r '.data[].id' | head -20
gh api repos/aaif-goose/goose/releases/latest --jq .tag_name                         # newest release
```

Ask only what discovery cannot show: endpoint shape (OpenAI chat, Anthropic Messages, Ollama API), model id and real context window, whether the model has native tool calling, whether goose runs in a container or headless host (keyring), Desktop or CLI.

## Decision flow

1. **One OpenAI-compatible endpoint, quick start:** built-in OpenAI provider with `OPENAI_HOST` and `OPENAI_BASE_PATH`. -> `references/custom-endpoints.md`
2. **Several endpoints, shareable config, headers, per-model context:** a custom provider JSON in `custom_providers/`. -> `references/custom-endpoints.md`
3. **Anthropic-shaped gateway (`/v1/messages`) or Ollama API:** custom provider with `engine` `anthropic` or `ollama`, or the built-in Ollama provider. -> `references/custom-endpoints.md`
4. **LiteLLM, llama-swap, LM Studio:** dedicated or built-in providers exist. -> `references/combos/engines-and-gateways.md`
5. **Model chats but tools never run, or errors on extensions:** tool calling, toolshim, context. -> `references/models-and-tools.md`
6. **Install, headless, update:** -> `references/install.md`
7. **Error or odd behavior:** -> `references/troubleshooting.md`

## Rules

- **Ask before changing the system.** Installs, `config.yaml` and `custom_providers/` edits, exported keys and `goose configure` runs need approval; back up `~/.config/goose` first.
- **Secrets never touch output.** goose ignores provider keys in `config.yaml`. Keys live in the keyring (via `goose configure` or Desktop), `secrets.yaml` (file storage, mode 0600) or the provider's environment variable; check presence by name only. `goose info -v` lists active settings; redact its output before sharing.
- **Use least privilege.** Give goose a gateway virtual key limited to the aliases it needs, not a master key.
- **Mind the URL shape.** OpenAI provider: `OPENAI_HOST` is the root and `OPENAI_BASE_PATH` the path (default `v1/chat/completions`). Custom OpenAI engine: `base_url` is the full chat completions URL. Anthropic engine: `base_url` is the root; goose appends `v1/messages`.
- **Tools or nothing.** goose leans on tool calling; a model without it can only chat, with extensions disabled. Fix the engine's tool parser first, use the tool shim second.
- **Declare context.** Unknown models get a default context; set `context_limit` in the provider JSON or `GOOSE_CONTEXT_LIMIT`, at or below the engine's real window.
- **Verify upstream.** Variable names and defaults come from goose-docs.ai (docs are in `documentation/docs` of the repo) and releases at use time, not memory.

## Workflows

### Connect a self-hosted OpenAI-compatible endpoint

- [ ] Run Discover; confirm `/models` and one chat completion with the key.
- [ ] Choose env vars or a custom provider JSON -> `references/custom-endpoints.md`; use `assets/custom_provider.openai.json`.
- [ ] Provide the key through the keyring or `OPENAI_API_KEY`/`<NAME>_API_KEY`; never in `config.yaml`.
- [ ] Set `GOOSE_PROVIDER` and `GOOSE_MODEL` (or pick in Desktop); `goose info -v` confirms.
- [ ] Prove tools: ask goose to list files in the working directory -> `references/models-and-tools.md`.

### Run headless or in a container

- [ ] Set `GOOSE_PROVIDER`, `GOOSE_MODEL`, the host and key variables in the environment.
- [ ] No desktop keyring: set `GOOSE_DISABLE_KEYRING=1` for configure steps or pass keys as env vars -> `references/install.md`.

### Update

- [ ] `goose update` (CLI), `brew upgrade` or Desktop prompt; run `goose info -v` and one tool chat after -> `references/install.md`.

## Reference index

| File                                        | Read when                                                                                   |
| ------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `references/install.md`                     | Install, config files, keys storage, headless and Docker, update                            |
| `references/custom-endpoints.md`            | OpenAI provider env vars, custom provider JSON, Anthropic and Ollama engines, auth commands |
| `references/models-and-tools.md`            | Model and context mapping, tool calling, toolshim, streaming, reasoning                     |
| `references/troubleshooting.md`             | Symptom to cause to fix                                                                     |
| `references/combos/engines-and-gateways.md` | vLLM, llama.cpp, Ollama, LM Studio, llama-swap, LiteLLM specifics                           |

Templates: `assets/custom_provider.openai.json`, `assets/custom_provider.anthropic.json`, `assets/goose.env.example`.

## Companion skills

Install any with `npx skills add ScaleDockHQ/llm-skills --skill <name>`.

- `llm-clients`: choosing a client, shared capability and troubleshooting notes.
- `litellm`: the gateway that gives goose one endpoint, virtual keys and `/v1/messages`.
- `llama-swap`: hot-swapping local models behind one URL.
- `vllm`, `llama-cpp`, `ollama`, `lm-studio`: engines goose connects to; they own tool-parser and context flags.
