# Cursor with self-hosted endpoints: vLLM, llama.cpp, Ollama, LiteLLM, llama-swap

> Verified against Cursor 3.23 docs, Cursor staff forum answers, and the vLLM, llama.cpp, Ollama, LiteLLM and llama-swap skill references, 2026-10-11

Cursor needs one thing from every engine: a public HTTPS `/v1` OpenAI-compatible URL with a bearer key. Never expose an engine directly; put the gateway (or a guard proxy) in front and give Cursor a scoped key.

## Per component

| Component  | Local URL it serves                          | What Cursor needs from it                                                                                         | Pitfall                                                                |
| ---------- | -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| LiteLLM    | `http://127.0.0.1:4000/v1`                   | Alias as model name; virtual key with `models`, `max_budget`, `rpm_limit`                                         | Best front for Cursor: one public hostname, scoped keys, logs          |
| llama-swap | `http://127.0.0.1:8080/v1`                   | Model id from `/v1/models`; put a gateway or Caddy auth in front                                                  | llama-swap has no per-user keys; do not publish it raw                 |
| vLLM       | `http://127.0.0.1:8000/v1`                   | `--served-model-name coder`, `--enable-auto-tool-choice --tool-call-parser <name>`, `--api-key` only guards `/v1` | Missing parser means no tool calls; bind loopback, not all interfaces  |
| llama.cpp  | `http://127.0.0.1:<port>/v1` (pass `--port`) | `--alias coder`, `--jinja`, `--api-key-file` (0600)                                                               | Default port changed between releases; always pass it                  |
| Ollama     | `http://127.0.0.1:11434/v1`                  | A tool-capable model, `OLLAMA_CONTEXT_LENGTH` of 32000 or more, a guard proxy with auth                           | Ollama has no auth; a tunnel straight to 11434 exposes pull and delete |

## Recommended shape

```text
Cursor servers --> https://llm.example.com/v1  (Caddy or Cloudflare Tunnel, TLS, bearer check)
              --> LiteLLM :4000 (virtual key "cursor", model allowlist, budget)
              --> llama-swap / vLLM / llama.cpp / Ollama on loopback
```

1. Engine on loopback with a neutral alias (`coder`).
2. LiteLLM `model_list` entry `model_name: coder` pointing at the engine (see the `litellm` skill for config and `/key/generate`).
3. Public TLS in front: `cloudflare-tunnel` or `caddy` (both skills show SSE-safe settings, for example Caddy `flush_interval -1`).
4. Create the key without printing it, store it in a `0600` file:

```bash
curl -fsS "$GW/key/generate" -H "Authorization: Bearer $LITELLM_MASTER_KEY" -H 'Content-Type: application/json' \
  -d '{"key_alias":"cursor-alice","models":["coder"],"max_budget":10,"budget_duration":"7d","rpm_limit":60,"duration":"90d"}' \
  | jq -r '.key' > ~/.config/llm/cursor.key && chmod 600 ~/.config/llm/cursor.key
```

5. Probe, then configure Settings > Models as in `../custom-endpoint.md`.

## Model-name mapping

Cursor sends exactly the string you add as the custom model. Make that string the gateway alias. Keep it plain alphanumeric (see `../custom-endpoint.md`). If you run several models, add several aliases (`coder`, `fast`); the override is global, so all of them share one base URL.

## Tool-calling and streaming caveats

- Cursor's agent always sends tools. If the engine returns none, you get chat only. Run `scripts/probe.sh` and look for `tool_calls=1` or more.
- Reasoning models that put `<think>` text into `content` pollute the chat; set the engine's reasoning parser so thinking goes into a separate field.
- SSE must be unbuffered end to end; test with the probe's `stream` line (`done=1`).
- Large prompts: the Cursor backend sends full agent context. Keep engine context at 32k or more and set gateway request timeouts above your slowest prefill.

## Verify

```bash
LLM_API_KEY_FILE=~/.config/llm/cursor.key scripts/probe.sh https://llm.example.com/v1 coder
```

Then in Cursor ask the agent to create a file; the gateway log should show `POST /v1/chat/completions` with model `coder` from Cursor's servers, not from your IP.

## Official links

- Bring your own API key: https://cursor.com/help/models-and-usage/api-keys
- Staff on public URL requirement: https://forum.cursor.com/t/how-can-i-use-a-local-llm-on-my-desktop-ai-computer/152419
