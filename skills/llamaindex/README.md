# LlamaIndex

An agent skill for pointing LlamaIndex (Python `llama-index` 0.14.x) at self-hosted OpenAI- and Anthropic-compatible endpoints (vLLM, llama.cpp, Ollama, LiteLLM, llama-swap). It covers `OpenAILike`, `Anthropic`, `Ollama` and `OpenAILikeEmbedding`, capability flags and context windows, Settings defaults that fall back to OpenAI, key handling, structured output, agent tools, streaming usage and troubleshooting, with a probe script.

## Install

```bash
npx skills add ScaleDockHQ/llm-skills --skill llamaindex
```

## Rules

- **Ask before changing the system.** Package installs and config edits need approval.
- **Secrets never touch output.** Keys come from environment variables or `0600` files.
- **Use `OpenAILike` for non-OpenAI servers**, and declare `is_chat_model`, `is_function_calling_model` and `context_window`.
- **Set `Settings.llm` and `Settings.embed_model`** or the OpenAI defaults ask for a key.
- **Test per alias.** Tools and `response_format` depend on the engine.
- **Verify upstream.** Versions and parameters come from PyPI and the LlamaIndex source at use time.

## References

- [`references/custom-endpoints.md`](references/custom-endpoints.md): classes, base URLs per backend, auth, model names, embeddings.
- [`references/structured-output-tools-streaming.md`](references/structured-output-tools-streaming.md): structured output, agents, streaming.
- [`references/updating.md`](references/updating.md): versions and upgrade steps.
- [`references/troubleshooting.md`](references/troubleshooting.md): symptom to cause to fix.
- [`references/combos/litellm-and-llama-swap.md`](references/combos/litellm-and-llama-swap.md): gateway in front of engines.

## Companion skills

- `llm-clients`, `litellm`, `llama-swap`, `vllm`, `llama-cpp`, `ollama`, `langfuse`.

## License

MIT
