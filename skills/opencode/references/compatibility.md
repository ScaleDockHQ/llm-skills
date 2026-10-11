# OpenCode: compatibility with self-hosted backends

> Verified against OpenCode v1.19.0 (docs: providers, models, config; GitHub issues checked 2026-10-11), 2026-10-11

OpenCode sends AI SDK requests: streamed chat completions (or Responses or Messages) with the `tools` array on every turn. What breaks is almost always the engine's tool parsing, the declared window, or a parameter the backend rejects.

## Tool calling

- OpenCode needs structured tool calls from the endpoint for every read, edit and shell step. A model that writes the call as text does nothing.
- Engine side first: vLLM `--enable-auto-tool-choice --tool-call-parser <name>` (skill `tool-calling-parsers`); llama.cpp `--jinja` and a template with a tool section; Ollama a model with the `tools` capability. Then declare `tool_call: true`.
- Ollama docs tip (OpenCode providers page): if tool calls are not working, raise `num_ctx`, starting around 16k to 32k. Ollama truncates silently above its window, so use `OLLAMA_CONTEXT_LENGTH` of 64k or more for agents and confirm with `ollama ps`.
- OpenCode docs tip for local models: pick models with strong tool-calling (Qwen-Coder or DeepSeek-Coder families are named).
- Contaminated or invalid tool-call arguments (stray text in the JSON) show up with small or heavily quantized models. A closed upstream issue about this exists (anomalyco/opencode#48119); prefer a larger or coder-tuned model, and a parser that tolerates the format.
- Tool-call errors against vLLM have been reported upstream (anomalyco/opencode#22525, closed); verify the engine's parser flags before filing anything.

## Streaming and timeouts

- `chunkTimeout` aborts a request when no SSE chunk arrives for that many ms (default 300000). Long prefill or a cold model load can exceed it; set `options.chunkTimeout` higher (or `false`) on the provider. `timeout` bounds the whole request.
- Proxies must not buffer SSE (Caddy `flush_interval -1`, nginx `proxy_buffering off`); Cloudflare returns 524 when the origin is silent too long (skill `cloudflare-tunnel`).
- `setCacheKey: true` sends a prompt cache key; leave it off unless the backend supports it (default false).

## Reasoning fields

- Reasoning text must arrive in a field OpenCode can read; set `interleaved.field` to `reasoning_content`, `reasoning` or `reasoning_text` to match the engine, and enable the engine's reasoning parser so thinking is not mixed into `content` (vLLM `--reasoning-parser`, llama.cpp `--reasoning-format`).
- Variant options such as `reasoningSummary`, `reasoningEffort`, `textVerbosity` are sent to the provider package. Chat backends and gateways can reject unknown params: remove the variant or drop params in the gateway (LiteLLM `drop_params` or `additional_drop_params`). The earlier `llm-clients` notes recorded a `reasoningSummary` rejection through LiteLLM; it was carried over, not re-reproduced.

## Wire-format notes

- `@ai-sdk/openai-compatible` speaks Chat Completions only. Endpoints that implement only Responses need `@ai-sdk/openai`; Messages-only need `@ai-sdk/anthropic`. Do not guess: probe with `scripts/check-endpoint.sh` (chat) or the other clients' scripts.
- List every model of a custom v1 provider in config; the docs say each ID must match `GET /v1/models`, and do not describe automatic discovery for v1 custom providers (v2 discovers Ollama, LM Studio and vLLM).
- Usage and cost: local models have no cost data; ignore cost fields.

## Defaults that surprise

- OpenCode checks for updates and downloads new versions on start (`autoupdate`, `OPENCODE_DISABLE_AUTOUPDATE`), fetches models from models.dev (`OPENCODE_DISABLE_MODELS_FETCH` turns it off), and may download LSP servers (`OPENCODE_DISABLE_LSP_DOWNLOAD`). On offline or restricted hosts disable these.
- Sharing is manual by default (`share: "manual"`); `OPENCODE_AUTO_SHARE` and `share: "auto"` publish sessions, which a self-hosted setup should never enable.
- The TUI talks to a local server: set `NO_PROXY=localhost,127.0.0.1` when using a proxy.
- Reads `.claude` prompts and skills by default; disable with `OPENCODE_DISABLE_CLAUDE_CODE` if that mixes instructions.

## Honest limits

Weak or heavily quantized models fail on tool use before OpenCode's config matters. When edits misbehave, test the same model with the check script's tool probe and a larger context before changing client settings.
