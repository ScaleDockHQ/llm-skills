# Continue with self-hosted endpoints: vLLM, llama.cpp, Ollama, LiteLLM, llama-swap

> Verified against Continue v2.1.0-vscode docs and source, plus the vLLM, llama.cpp, Ollama, LiteLLM and llama-swap skill references, 2026-10-11

Continue calls from your machine, so every local, LAN, VPN or Tailscale URL works. Pick the provider by the API the endpoint speaks.

## Per component

| Component  | Entry                                                                                                          | Key                                                  | Engine-side requirement                                                                                    |
| ---------- | -------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| LiteLLM    | `provider: openai`, `apiBase: http://host:4000/v1`, `model: <alias>`                                           | Virtual key via `${{ secrets.LLM_API_KEY }}`         | Alias in `model_list`; for Claude-style use `provider: anthropic`, `apiBase: http://host:4000/v1`          |
| llama-swap | `provider: openai`, `apiBase: http://host:8080/v1`, `model: <id from /v1/models>`                              | Usually none behind loopback; use a gateway for keys | Model must be defined in llama-swap config; first call loads the model (slow first token)                  |
| vLLM       | `provider: openai`, `apiBase: http://host:8000/v1`, `model: <--served-model-name>`                             | `--api-key` value                                    | `--enable-auto-tool-choice --tool-call-parser <name>` for Agent mode                                       |
| llama.cpp  | `provider: openai`, `apiBase: http://host:<port>/v1` (or `provider: llama.cpp`, `apiBase: http://host:<port>`) | `--api-key-file` content                             | `--jinja` with a tool-capable template; pass `--port` explicitly, defaults changed between releases        |
| Ollama     | `provider: ollama`, `apiBase: http://host:11434` (or `provider: openai`, `apiBase: http://host:11434/v1`)      | none                                                 | Tool-capable model; raise `OLLAMA_CONTEXT_LENGTH`; remote use needs `OLLAMA_HOST=0.0.0.0:11434` or a proxy |

## Recommended shape

```text
Continue (editor) --> LiteLLM :4000  (scoped key, aliases, budgets) --> llama-swap / vLLM / llama.cpp / Ollama
```

One key per person or tool. Give Continue its own virtual key (see `litellm` skill, `/key/generate`) and place it in `~/.continue/.env`:

```bash
umask 077; mkdir -p ~/.continue
printf 'LLM_API_KEY=%s\n' "$(cat ~/.config/llm/continue.key)" >> ~/.continue/.env   # no echo of the value
```

## Model-name mapping

- `model:` is the gateway alias (or llama-swap id, or vLLM `--served-model-name`, or llama.cpp `--alias`). `name:` is only a label.
- Keep aliases away from `gpt-5*`, `o3` and similar names, or add `useResponsesApi: false`.
- Roles map to aliases: `coder` for chat/edit/apply, `autocomplete` for FIM, `embed` for embeddings.

## Tool-calling and streaming

- Agent mode needs `capabilities: [tool_use]` and an engine that returns `tool_calls`; confirm with `scripts/probe.sh` (`tool_calls=1+`).
- Reasoning models that emit `<think>` in content need the engine's reasoning parser; otherwise the thinking shows as answer text.
- Autocomplete needs a FIM-capable model; if the engine only exposes FIM on `/completions` set `useLegacyCompletionsEndpoint: true` for that model.

## Verify

```bash
LLM_API_KEY_FILE=~/.config/llm/continue.key scripts/probe.sh http://host:4000/v1 coder
```

In the IDE: reload the window, select the model, ask Agent mode to create a file, and confirm the request in the gateway log.

## Official links

- OpenAI-compatible providers list: https://docs.continue.dev/customize/model-providers/top-level/openai
- Ollama: https://docs.continue.dev/customize/model-providers/top-level/ollama
- llama.cpp: https://docs.continue.dev/customize/model-providers/more/llamacpp
