# Cline with self-hosted endpoints: vLLM, llama.cpp, Ollama, LiteLLM, llama-swap

> Verified against Cline v4.1.23 docs, plus the vLLM, llama.cpp, Ollama, LiteLLM and llama-swap skill references, 2026-10-11

Cline calls from your machine, so every local, LAN, VPN or Tailscale URL works. Use "OpenAI Compatible" for everything that serves `/v1/chat/completions`.

## Per component

| Component  | Provider and Base URL                                                                     | Key                      | Engine-side requirement                                                                |
| ---------- | ----------------------------------------------------------------------------------------- | ------------------------ | -------------------------------------------------------------------------------------- |
| LiteLLM    | OpenAI Compatible, `http://host:4000/v1`                                                  | Scoped virtual key       | Alias in `model_list`; Model ID = alias                                                |
| llama-swap | OpenAI Compatible, `http://host:8080/v1`                                                  | Usually none on loopback | Model ids from `/v1/models`; first request loads the model, so the first token is slow |
| vLLM       | OpenAI Compatible, `http://host:8000/v1`                                                  | `--api-key` value        | `--served-model-name`, `--enable-auto-tool-choice --tool-call-parser <name>`           |
| llama.cpp  | OpenAI Compatible, `http://host:<port>/v1` (pass `--port`)                                | `--api-key-file` content | `--jinja` with a tool-capable template; `--alias` for a clean Model ID                 |
| Ollama     | Provider "Ollama", `http://host:11434` (or OpenAI Compatible with `http://host:11434/v1`) | none                     | Tool-capable model; `OLLAMA_CONTEXT_LENGTH` of 32000 or more; Compact Prompt on        |

## Recommended shape

```text
Cline --> LiteLLM :4000 (scoped key, aliases, budgets) --> llama-swap / vLLM / llama.cpp / Ollama
```

Give Cline its own virtual key. Enter it in the extension's API Key field, or via `cline auth` without `-k`. Keep the key file at `0600`:

```bash
umask 077; mkdir -p ~/.config/llm
curl -fsS "$GW/key/generate" -H "Authorization: Bearer $LITELLM_MASTER_KEY" -H 'Content-Type: application/json' \
  -d '{"key_alias":"cline-alice","models":["coder"],"max_budget":10,"budget_duration":"7d"}' \
  | jq -r '.key' > ~/.config/llm/cline.key
```

## Model-name mapping and limits

- Model ID is the alias, sent as is.
- Context Window = the engine's served context (vLLM `--max-model-len`, llama.cpp `--ctx-size`, Ollama `num_ctx`) or lower. Max Output Tokens well below the window.
- Image Support only for vision models.

## Tool-calling and streaming caveats

- Cline sends tool definitions and expects `tool_calls`; probe with `scripts/probe.sh` (`tool_calls=1+`).
- Local small models loop or mis-call tools more often (Kilo and Cline docs both say so): enable Compact Prompt, keep prompts short, prefer 30B-class coder models.
- Buffering proxies break streaming; the probe's `stream` line must show `done=1`.
- Long first token (model swap in llama-swap, cold vLLM): raise gateway timeouts; Cline CLI has `--timeout`.

## Verify

```bash
LLM_API_KEY_FILE=~/.config/llm/cline.key scripts/probe.sh http://host:4000/v1 coder
cline -P <provider> -m coder "create hello.txt containing hi"      # CLI route
```

Then the gateway log should show `POST /v1/chat/completions` with model `coder`.

## Official links

- OpenAI Compatible: https://docs.cline.bot/provider-config/openai-compatible
- Local models: https://docs.cline.bot/running-models-locally/overview
