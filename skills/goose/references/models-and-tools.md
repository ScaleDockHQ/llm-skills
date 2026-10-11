# goose: models, context, tool calling, toolshim and streaming

> Verified against goose v1.54.0 (docs: guides/environment-variables, guides/tool-shim, guides/sessions/smart-context-management, getting-started/providers, troubleshooting/known-issues), 2026-10-11

## Model and provider selection

- `GOOSE_PROVIDER` and `GOOSE_MODEL` (env) override `config.yaml` for that process; the file stores `active_provider` and `providers.<name>.model`.
- `goose configure` cannot enter a model name that the provider did not list; use Desktop ("Use custom model") or edit `GOOSE_MODEL`/the provider entry. Per run: `goose run --model <id> -t "..."`.
- Model ids are sent as-is: copy them from `/v1/models` of the endpoint (gateway aliases are case and prefix sensitive).
- goose also supports multi-model setups (see its Multi-Model Configuration page); each configured model needs a working endpoint under the rules below.

## Context window

- goose picks the context limit by model-name patterns, and unknown or gateway-aliased names fall back to a default (128,000 per the env var docs). Override:
  - `context_limit` per model in a custom provider JSON.
  - `GOOSE_CONTEXT_LIMIT`: main model (also the fallback for others), for example when using LiteLLM with custom names.
  - `GOOSE_INPUT_LIMIT`: input limit for Ollama requests, mapped to `num_ctx`; unset means Ollama's own default.
- Keep `engine context >= gateway max_input_tokens >= goose context`. Ollama's own default context is small (the docs mention 4096 and 2048 in different places) and goose misbehaves when it is too low (ignores `.goosehints`, fails with extensions); set `OLLAMA_CONTEXT_LENGTH` on the server or `GOOSE_INPUT_LIMIT` in goose, or ramalama's `--ctx-size`.
- Auto-compaction triggers at `GOOSE_AUTO_COMPACT_THRESHOLD` (default 0.8, 0 disables) or `GOOSE_AUTO_COMPACT_TOKEN_LIMIT` (default 225000), whichever comes first; with a smaller real window set the token limit below it. Output cap: `GOOSE_MAX_TOKENS`.

## Tool calling

- goose "extensively uses tool calling". A model without it can only chat, and all extensions must be disabled for it to work (Extensions toggles in Desktop, or `goose configure` Toggle Extensions).
- Fix tool support at the engine: vLLM `--enable-auto-tool-choice --tool-call-parser <name>`; llama.cpp `--jinja` with a template that handles tools; ramalama `--runtime-args="--jinja"` for the Ollama provider; Ollama models tagged for tools. Engine skills own these flags.
- Some models print tool calls as text (for example `functions.shell:0 <|tool_call_argument_begin|> {...}`) or mix `<think>` with tool calls. Use the tool shim when the server cannot be fixed.
- The providers page notes that o1-mini and o1-preview are not supported because goose uses tool calling.

## Tool shim (experimental)

Converts text-formatted tool calls into real ones with a separate interpreter model.

```bash
export GOOSE_TOOLSHIM=true
ollama pull mistral-nemo                      # default interpreter model
export GOOSE_TOOLSHIM_OLLAMA_MODEL=llama3.2   # optional different interpreter
# or a built-in local backend interpreter
# export GOOSE_TOOLSHIM_BACKEND=local   # values: ollama (default), local, llama.cpp
# export GOOSE_TOOLSHIM_MODEL=<model name>
```

The interpreter is independent of the main provider, but by default it needs Ollama running locally. It can be enabled globally in `config.yaml` (`GOOSE_TOOLSHIM: true`) or per custom provider with `"toolshim": true`. Treat it as a fallback: slower, an extra model to host, and behavior may change between releases.

## Streaming

- `supports_streaming` (custom provider JSON, default per provider type) controls whether goose streams. Disable only when the server cannot stream tool calls; test with `curl -N` and `"stream":true` first.
- Reverse proxies that buffer SSE make replies arrive at once; disable buffering on the proxy (`caddy`, `llm-gateway` skills).
- Rate limits (`429`) are surfaced as errors; use a gateway with built-in rate limiting and fallbacks rather than retry loops in goose.

## Reasoning

- `CLAUDE_THINKING_TYPE` (`adaptive`, `enabled`, `disabled`) applies to Anthropic and Databricks providers; other providers expose reasoning through their own variables (for example OpenRouter and Gemini sections of the providers page).
- Custom OpenAI-engine providers preserve thinking content by default (source default for the `openai` engine). If a server rejects echoed `reasoning_content`, check the server's parser settings.

## Permission mode (affects tool runs)

`GOOSE_MODE`: `auto` (default, runs tools), `approve`, `smart_approve`, `chat` (no tools). A session stuck in `chat` never calls tools, regardless of the model.

## Verify

1. `goose info -v` shows the expected provider, model and limits.
2. Ask for "list files here and show the first three lines of the README"; tool calls appear and succeed.
3. A long session passes the compaction point without a context error.

## Official links

- Environment variables: https://goose-docs.ai/docs/guides/environment-variables
- Tool shim: https://goose-docs.ai/docs/guides/tool-shim
- Smart context management: https://goose-docs.ai/docs/guides/sessions/smart-context-management
- Providers (local LLMs): https://goose-docs.ai/docs/getting-started/providers
