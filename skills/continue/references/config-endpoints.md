# Continue: config.yaml for custom endpoints

> Verified against Continue v2.1.0-vscode (docs.continue.dev reference, provider and FAQ pages, core source on main), 2026-10-11

## What it is and when to choose it

Continue runs inside the editor (or the `cn` CLI), so requests leave from your machine and `localhost` works. Models, roles, keys and request options live in one YAML file. Use this page to point a model at an OpenAI-compatible or Anthropic-compatible base URL.

## Install

Nothing beyond the extension; see `install.md`. Config file: `~/.continue/config.yaml` (global; `~/.continue` also holds data, so deleting it resets the extension). `config.json` is deprecated.

## Minimal working config

Required top-level keys: `name`, `version`, `schema` (use `v1`). Each model needs `name`, `provider`, `model`.

```yaml
name: Self-hosted
version: 1.0.0
schema: v1
models:
  - name: Coder (gateway)
    provider: openai
    model: coder # the alias the endpoint serves
    apiBase: https://llm.example.com/v1 # OpenAI style: ends with /v1
    apiKey: ${{ secrets.LLM_API_KEY }} # value lives in ~/.continue/.env
    roles: [chat, edit, apply]
    capabilities: [tool_use]
    defaultCompletionOptions:
      contextLength: 65536
      maxTokens: 8192
    useResponsesApi: false
```

Template with more entries: `assets/config.yaml`.

## Providers for your own endpoints

| Goal                                                                      | `provider`  | `apiBase`                                                             | Wire API sent                             | Notes                                                                                      |
| ------------------------------------------------------------------------- | ----------- | --------------------------------------------------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------ |
| vLLM, LiteLLM, llama-swap, llama.cpp, Ollama `/v1`, any OpenAI-compatible | `openai`    | `http://host:port/v1`                                                 | `/chat/completions`                       | Docs list vLLM, llama.cpp-python, LiteLLM, LocalAI, KoboldCpp, TensorRT-LLM as compatible  |
| Anthropic Messages (gateway or bridge)                                    | `anthropic` | `https://host/v1` (source default is `https://api.anthropic.com/v1/`) | `POST <apiBase>messages` with `x-api-key` | Continue adds the trailing slash; test the gateway accepts `x-api-key`                     |
| Ollama native                                                             | `ollama`    | `http://host:11434` (no `/v1`)                                        | `/api/chat` (source)                      | Needs only the host; remote Ollama must listen on `0.0.0.0` or sit behind a proxy          |
| llama.cpp native                                                          | `llama.cpp` | `http://host:<port>`                                                  | llama.cpp server API                      | Docs example uses `:8080`; the llama-server default port differs by release, pass `--port` |

Source check: `apiBase` gets a trailing `/` appended if missing, then endpoints are resolved with URL rules, so `http://host:8000/v1` becomes `/v1/chat/completions`. An `apiBase` without `/v1` produces 404s.

`useLegacyCompletionsEndpoint: true` forces `/completions` instead of `/chat/completions` (useful for FIM autocomplete against engines that expose it).

## Keys and secrets

- Reference a secret anywhere with `${{ secrets.NAME }}`.
- Lookup order (FAQ): workspace `.env`, workspace `.continue/.env`, `~/.continue/.env`, then process environment.
- IDE extensions (VS Code, JetBrains) cannot read shell exports; only the `cn` CLI sees process environment variables.
- Dotenv format, no quotes around values; restart the IDE after changing secrets. Never commit `.env`.

```bash
umask 077; touch ~/.continue/.env; chmod 600 ~/.continue/.env          # keeps existing content
printf 'LLM_API_KEY=%s\n' "$(cat ~/.config/llm/continue.key)" >> ~/.continue/.env   # copies without printing
```

The docs' example `requestOptions.headers: Authorization: Bearer YOUR_KEY` works but puts a key in the file; prefer `apiKey: ${{ secrets.X }}`. For gateways needing extra headers, `requestOptions.headers` accepts them (also `timeout`, `verifySsl`, `caBundlePath`, `proxy`, `noProxy`, `extraBodyProperties`, `clientCertificate`).

## Model-name mapping

`model` is sent verbatim to the endpoint; `name` is only the label in the picker. Use the gateway alias (`coder`) as `model`. Continue's autodetection of capabilities and API choice is driven by `provider` plus `model` name.

- **Responses API trap.** Source: names matching `^o[0-9]+` or `gpt-[5-9]` are treated as reasoning models and sent to `/responses` with `provider: openai`. The docs say it applies to o-series and gpt-5 models. If your alias looks like that, rename it or set `useResponsesApi: false`.

## Capabilities, roles, limits

- `roles` default: `[chat, edit, apply, summarize]`; others: `autocomplete`, `embed`, `rerank`.
- `capabilities`: `tool_use` (needed for Agent mode) and `image_input`. You can only add; autodetection still applies, and `[]` does not disable it.
- If the model has no native tool calling, Continue's FAQ says system-message tools are a fallback; the model-capabilities page calls them experimental and not automatic. Prefer a model with native tool calls.
- `defaultCompletionOptions`: `contextLength`, `maxTokens`, `temperature`, `topP`, `topK`, `stop`, `reasoning`, `reasoningBudgetTokens`, `keepAlive` (Ollama).
- Keep `contextLength` at or below the engine's served context. Ollama: Continue can set a larger default than other tools and trigger "model requires more system memory"; lower `contextLength`.
- `autocompleteOptions` (`debounceDelay`, `maxPromptTokens`, `onlyMyCode`, `template`...) apply to `roles: [autocomplete]` models.

## Streaming and tool calls

Continue streams by default. Tool calls need the engine to emit OpenAI-format `tool_calls`: vLLM needs `--enable-auto-tool-choice --tool-call-parser <name>`; llama.cpp needs `--jinja` with a tool-capable template; Ollama needs a tool-capable model. A gateway that buffers SSE makes the UI wait; disable buffering in front proxies.

## How it plugs into the stack

```text
Continue (editor) --> gateway or engine (HTTP, your network)
```

No vendor cloud sits between, so private, LAN, VPN and Tailscale addresses work. For a remote workspace (SSH, dev container, WSL), `localhost` is relative to where the Continue extension host runs.

## Operating

- View logs: the Continue output channel and console in the IDE; plus the gateway log.
- Config changes may need "Developer: Reload Window" in VS Code (FAQ).
- Custom CA: `requestOptions.caBundlePath` (string or list) fixes `fetch failed` and certificate-chain errors.

## Known pitfalls

- 404: `apiBase` missing `/v1`, or sent to `/responses` because of the alias name.
- Agent greyed out: model lacks `tool_use`; add the capability and confirm the engine emits tool calls.
- Key not found: stored in a shell export, not `.env`.
- YAML anchors need the `%YAML 1.1` header.

## Official links

- config.yaml reference: https://docs.continue.dev/reference
- OpenAI provider (apiBase, legacy completions, Responses): https://docs.continue.dev/customize/model-providers/top-level/openai
- Anthropic provider: https://docs.continue.dev/customize/model-providers/top-level/anthropic
- Ollama provider: https://docs.continue.dev/customize/model-providers/top-level/ollama
- llama.cpp provider: https://docs.continue.dev/customize/model-providers/more/llamacpp
- Model capabilities: https://docs.continue.dev/customize/deep-dives/model-capabilities
- FAQ (secrets, certificates, tools): https://docs.continue.dev/faqs
- Source: https://github.com/continuedev/continue
