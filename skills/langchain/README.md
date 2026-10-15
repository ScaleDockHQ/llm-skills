# LangChain

An agent skill for pointing LangChain (Python `langchain`, `langchain-openai`, `langchain-anthropic`, `langchain-ollama`) at self-hosted OpenAI- and Anthropic-compatible endpoints (vLLM, llama.cpp, Ollama, LiteLLM, llama-swap). It covers class and base-URL choice, key handling, env vars that silently redirect, model names and profiles, structured output, tool calling, agents, streaming usage, dropped reasoning content and troubleshooting, with a probe script.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill langchain
```

## Rules

- **Ask before changing the system.** Package installs and config edits need approval.
- **Secrets never touch output.** Keys come from environment variables or `0600` files.
- **`ChatOpenAI` targets the official OpenAI spec.** Non-standard fields such as `reasoning_content` are dropped.
- **Set `stream_usage=True` yourself** when using a custom base URL.
- **Pass `base_url` and `api_key` explicitly**; env vars and `LANGSMITH_GATEWAY` can redirect silently.
- **Test per alias.** Tools and `json_schema` depend on the engine.
- **Verify upstream.** Versions and parameters come from docs.langchain.com and PyPI at use time.

## References

- [`references/custom-endpoints.md`](references/custom-endpoints.md): classes, base URLs per backend, auth, model names, profiles.
- [`references/structured-output-tools-streaming.md`](references/structured-output-tools-streaming.md): structured output, tools, agents, streaming.
- [`references/updating.md`](references/updating.md): versions and upgrade steps.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/litellm-and-llama-swap.md`](references/combos/litellm-and-llama-swap.md): gateway in front of engines.

## Companion skills

- `llm-clients`, `litellm`, `llama-swap`, `vllm`, `llama-cpp`, `ollama`, `langfuse`.

## License

MIT
