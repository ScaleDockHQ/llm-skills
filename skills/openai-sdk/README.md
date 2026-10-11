# OpenAI SDK

An agent skill for pointing the official OpenAI Python and Node SDKs at your own model servers. It covers `base_url`/`baseURL` and key handling without printing secrets, custom headers, timeouts, retries, proxies and TLS, Chat Completions versus Responses, streaming and usage, tool calling, structured output, reasoning fields, `extra_body`, per-server recipes for vLLM, llama.cpp, Ollama, LiteLLM and llama-swap including model-name mapping, and troubleshooting, with a Node smoke test and a read-only endpoint probe.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill openai-sdk
```

## Rules

- **Never hardcode or print keys.** Read them from `OPENAI_API_KEY` or a `0600` file.
- **`base_url` ends in `/v1`**, never `/chat/completions`.
- **The SDK needs a non-empty key** even for keyless servers; pass a placeholder.
- **Probe first.** `scripts/check-endpoint.sh` separates server problems from client problems.
- **Chat Completions is the portable default;** use Responses only where the server answers `/v1/responses`.
- **Prefer constructor arguments over `OPENAI_BASE_URL`** in applications, so other OpenAI-SDK programs are not redirected.
- **Verify upstream.** Defaults and flags come from SDK and server docs at use time.

## References

- [`references/client-config.md`](references/client-config.md): constructors, env vars, keys, headers, timeouts, proxies.
- [`references/apis-tools-streaming.md`](references/apis-tools-streaming.md): APIs, streaming, tools, structured output, reasoning.
- [`references/server-recipes.md`](references/server-recipes.md): URLs, auth and model names per server.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.

Asset: [`assets/client.mjs`](assets/client.mjs). Script: [`scripts/check-endpoint.sh`](scripts/check-endpoint.sh).

## Companion skills

- `anthropic-sdk`: the same job for Anthropic Messages clients.
- `litellm`, `llama-swap`: gateways for stable names and keys.
- `vllm`, `llama-cpp`, `ollama`: engines behind the endpoint.
- `tool-calling-parsers`: fixing empty `tool_calls`.
- `llm-clients`: choosing and troubleshooting clients of every kind.

## License

MIT
