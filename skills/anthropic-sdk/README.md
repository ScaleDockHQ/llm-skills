# Anthropic SDK

An agent skill for pointing the official Anthropic Python and TypeScript SDKs at your own servers' Messages route. It covers `base_url`/`baseURL` without `/v1`, choosing `auth_token` (Bearer) or `api_key` (`x-api-key`) per server, keys without printing secrets, custom headers, timeouts, retries, proxies, streaming, tool use, thinking, betas, per-server recipes for vLLM, llama.cpp, Ollama, LiteLLM and llama-swap including model-name mapping, and troubleshooting, with a Node smoke test and a read-only endpoint probe.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill anthropic-sdk
```

## Rules

- **Never hardcode or print keys.** Read them from env vars or a `0600` file.
- **`base_url` has no `/v1`;** the SDK appends `/v1/messages`.
- **Pick one credential.** `auth_token` is Bearer, `api_key` is `x-api-key`; vLLM accepts Bearer only.
- **`max_tokens` is required;** stream long generations.
- **Leave betas off** for self-hosted servers unless they document support.
- **Probe first.** `scripts/check-endpoint.sh` shows which header the server accepts.
- **Verify upstream.** Defaults and flags come from SDK and server docs at use time.

## References

- [`references/client-config.md`](references/client-config.md): constructors, env vars, auth choice, headers, timeouts, proxies.
- [`references/messages-tools-streaming.md`](references/messages-tools-streaming.md): Messages shape, streaming, tools, thinking, betas.
- [`references/server-recipes.md`](references/server-recipes.md): URL, auth and model names per server.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.

Asset: [`assets/client.mjs`](assets/client.mjs). Script: [`scripts/check-endpoint.sh`](scripts/check-endpoint.sh).

## Companion skills

- `openai-sdk`: the same job for OpenAI-compatible clients.
- `litellm`, `llama-swap`: gateways that translate and give stable names and keys.
- `vllm`, `llama-cpp`, `ollama`: engines behind the endpoint.
- `tool-calling-parsers`: fixing missing `tool_use`.
- `llm-clients`: choosing and troubleshooting clients of every kind.

## License

MIT
