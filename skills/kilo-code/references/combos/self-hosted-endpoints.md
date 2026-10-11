# Kilo Code with self-hosted endpoints: vLLM, llama.cpp, Ollama, LiteLLM, llama-swap

> Verified against Kilo Code v7.8.8 docs, plus the vLLM, llama.cpp, Ollama, LiteLLM and llama-swap skill references, 2026-10-11

Kilo calls from your machine, so every local, LAN, VPN or Tailscale URL works. Choose the Provider API by what the endpoint serves.

## Per component

| Component  | Provider API and `baseURL`                                                                  | Key                                                      | Engine-side requirement                                                      |
| ---------- | ------------------------------------------------------------------------------------------- | -------------------------------------------------------- | ---------------------------------------------------------------------------- |
| LiteLLM    | OpenAI Compatible, `http://host:4000/v1` (Anthropic Messages: same base for `/v1/messages`) | `{env:LLM_API_KEY}` scoped virtual key                   | Alias in `model_list`; model key/id = alias                                  |
| llama-swap | OpenAI Compatible, `http://host:8080/v1`                                                    | usually none on loopback                                 | Ids from `/v1/models`; first request loads the model (raise `timeout`)       |
| vLLM       | OpenAI Compatible, `http://host:8000/v1`                                                    | `--api-key` value (docs example uses `"none"` when open) | `--served-model-name`, `--enable-auto-tool-choice --tool-call-parser <name>` |
| llama.cpp  | OpenAI Compatible, `http://host:<port>/v1` (pass `--port`)                                  | `--api-key-file` content                                 | `--jinja` with a tool-capable template; `--alias` for a clean id             |
| Ollama     | Built-in `ollama` provider, `http://host:11434/v1` (or Custom provider)                     | none                                                     | Tool-capable model; set `num_ctx` (32k or more); `ollama/<model>` prefix     |

## Recommended shape

```text
Kilo --> LiteLLM :4000 (scoped key, aliases, budgets) --> llama-swap / vLLM / llama.cpp / Ollama
```

vLLM example straight from Kilo's docs, adapted:

```jsonc
{
  "provider": {
    "vllm": {
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "http://my.url:8000/v1",
        "apiKey": "{env:VLLM_API_KEY}",
      },
      "models": {
        "qwen35": {
          "name": "Qwen 3.5",
          "tool_call": true,
          "limit": { "context": 262144, "output": 16384 },
        },
      },
    },
  },
  "model": "vllm/qwen35",
}
```

Create the gateway key without printing it:

```bash
umask 077; mkdir -p ~/.config/llm
curl -fsS "$GW/key/generate" -H "Authorization: Bearer $LITELLM_MASTER_KEY" -H 'Content-Type: application/json' \
  -d '{"key_alias":"kilo-alice","models":["coder"],"max_budget":10,"budget_duration":"7d"}' \
  | jq -r '.key' > ~/.config/llm/kilo.key
export LLM_API_KEY="$(cat ~/.config/llm/kilo.key)"   # in the shell that launches kilo; or use {file:/abs/path}
```

For the VS Code extension launched from the Dock or a menu, exported variables may not reach it; prefer `{file:/abs/path}` in global config or the extension's key field.

## Model-name mapping

Key under `models` is what you pick; `id` is what the endpoint receives. Use the gateway alias as the key or set `id` to it. Reference as `provider_id/model_id` (`gateway/coder`).

## Limits and caveats

- Set `limit.context` at or below the engine's served context and `limit.output` well below it; with `0` Kilo never compacts.
- `tool_call: true` and an engine that returns `tool_calls`; check with `scripts/probe.sh`.
- Local models can loop or mis-call tools (Kilo's own Ollama guide says so): keep conversations short, disable unused MCP tools, prefer a 30B-class coder model (the guide recommends `qwen3-coder:30b`, alternative `devstral:24b`).
- Reasoning models: if output ends at `limit.output` with no text, disable reasoning or raise the limit.
- Streaming through buffering proxies hangs; set `chunkTimeout` (15000 to 30000) to fail fast.

## Verify

```bash
LLM_API_KEY_FILE=~/.config/llm/kilo.key scripts/probe.sh http://host:4000/v1 coder
kilo models | grep -i gateway
kilo debug config | jq '.provider | keys'      # resolved providers; do not paste the output if it includes keys
```

## Official links

- OpenAI compatible: https://kilo.ai/docs/ai-providers/openai-compatible
- Custom models: https://kilo.ai/docs/code-with-ai/agents/custom-models
- Ollama: https://kilo.ai/docs/ai-providers/ollama
