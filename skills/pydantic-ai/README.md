# Pydantic AI

An agent skill for pointing Pydantic AI (Python `pydantic-ai` 2.x) at self-hosted OpenAI- and Anthropic-compatible endpoints (vLLM, llama.cpp, Ollama, LiteLLM, llama-swap). It covers model classes and providers, base URLs, key handling, model profiles, output modes, tool calling, streaming, system-message and thinking quirks, and troubleshooting, with a probe script.

## Install

```bash
npx skills add ScaleDockHQ/llms-skills --skill pydantic-ai
```

## Rules

- **Ask before changing the system.** Package installs and config edits need approval.
- **Secrets never touch output.** Keys come from environment variables or `0600` files.
- **Pick the model class by API.** `'openai:name'` is Responses; chat-only endpoints need `OpenAIChatModel`.
- **`OpenAIProvider` assumes OpenAI models**; configure a profile or use `VLLMProvider`, `OllamaProvider` or `LiteLLMProvider`.
- **Tools need server support.** Tool parser flags on vLLM and `--jinja` on llama-server.
- **Verify upstream.** Versions and options come from pydantic.dev/docs/ai and PyPI at use time.

## References

- [`references/custom-endpoints.md`](references/custom-endpoints.md): model classes, providers, base URLs per backend, profiles.
- [`references/structured-output-tools-streaming.md`](references/structured-output-tools-streaming.md): output modes, tools, streaming.
- [`references/updating.md`](references/updating.md): versions and upgrade steps.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/litellm-and-llama-swap.md`](references/combos/litellm-and-llama-swap.md): gateway in front of engines.

## Companion skills

- `llm-clients`, `litellm`, `llama-swap`, `vllm`, `llama-cpp`, `ollama`, `langfuse`.

## License

MIT
