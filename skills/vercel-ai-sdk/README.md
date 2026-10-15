# Vercel AI SDK

An agent skill for pointing the Vercel AI SDK (`ai`, `@ai-sdk/*`) at self-hosted OpenAI- and Anthropic-compatible endpoints (vLLM, llama.cpp, Ollama, LiteLLM, llama-swap). It covers provider and base-URL choice, key handling, model-name aliases, structured output, tool calling, streaming caveats, v7 migration points and troubleshooting, with a probe script and templates.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill vercel-ai-sdk
```

## Rules

- **Ask before changing the system.** Package installs and config edits need approval.
- **Secrets never touch output.** Keys come from environment variables or `0600` files.
- **Never use bare model strings** against your own endpoint; they go to the Vercel AI Gateway.
- **Match the factory to the API.** `openai(id)` is Responses; chat-only endpoints need `openai.chat` or `createOpenAICompatible`.
- **Test per alias.** Tools, `json_schema` and streamed usage depend on the engine.
- **Verify upstream.** Versions and options come from ai-sdk.dev and npm at use time.

## References

- [`references/custom-endpoints.md`](references/custom-endpoints.md): provider choice, base URLs per backend, auth, model mapping.
- [`references/structured-output-tools-streaming.md`](references/structured-output-tools-streaming.md): `Output.object`, tools, streaming, reasoning.
- [`references/updating.md`](references/updating.md): versions and v6 to v7 changes.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/litellm-and-llama-swap.md`](references/combos/litellm-and-llama-swap.md): gateway in front of engines.

## Companion skills

- `llm-clients`, `litellm`, `llama-swap`, `vllm`, `llama-cpp`, `ollama`, `langfuse`.

## License

MIT
