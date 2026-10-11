# Pydantic AI: troubleshooting

> Verified against Pydantic AI v2.55.0 (docs: models/openai, models/compatible-apis, models/ollama, output), 2026-10-11

First reproduce outside Pydantic AI: `BASE_URL=... MODEL=... KEY_FILE=... scripts/probe.sh openai` (or `anthropic`). If curl works and Pydantic AI fails, suspect the model class, the profile or an env var.

| Symptom                                                                | Likely cause and fix                                                                                                                                                            |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 404 on `/responses`                                                    | `'openai:name'` or `OpenAIResponsesModel` was used. Use `OpenAIChatModel` or the `'openai-chat:'` prefix.                                                                       |
| 404 on every call                                                      | OpenAI base URL missing `/v1`; or an Anthropic base URL given with `/v1`.                                                                                                       |
| Calls go to api.openai.com or ask for `OPENAI_API_KEY`                 | A string model (`'openai:...'`) or `OpenAIProvider()` without arguments. Build the model with an explicit provider, or set `OPENAI_BASE_URL` and `OPENAI_API_KEY` deliberately. |
| 400 `System message must be at the beginning.` or roles must alternate | The chat template accepts one leading system message. Set `openai_chat_supports_multiple_system_messages=False` in the profile (`VLLMProvider` merges by default).              |
| 400 on `max_completion_tokens`                                         | The server only accepts `max_tokens`. Set `openai_chat_supports_max_completion_tokens=False` in the profile.                                                                    |
| 400 about `strict` in tools                                            | The server rejects strict tool definitions. Use a profile with `openai_supports_strict_tool_definition=False`.                                                                  |
| Agent returns text instead of calling tools; JSON in the reply         | Engine lacks a tool parser: vLLM `--enable-auto-tool-choice --tool-call-parser <name>`, llama-server `--jinja`, Ollama model without tool support.                              |
| `NativeOutput` ignored, prose returned or error                        | The engine does not enforce `json_schema`, or the profile says unsupported. Use `ToolOutput` or `PromptedOutput`; Ollama Cloud does not enforce schemas.                        |
| Output validation retries exhausted                                    | Model is not following the schema. Use a stronger model, `PromptedOutput` with a clearer description, lower temperature, or raise the output retry budget.                      |
| `thinking` setting ignored or rejected                                 | `OpenAIProvider` assumed an OpenAI profile for a non-OpenAI model. Configure an `OpenAIModelProfile`, or use `VLLMProvider`, `OllamaProvider` or `LiteLLMProvider`.             |
| Thinking text missing or shown inline                                  | Field name differs: set `openai_chat_thinking_field`. Inline `<think>` means the engine's reasoning parser is off.                                                              |
| Truncated stream looks like a complete answer                          | Server closed the stream without `finish_reason`. Set `openai_chat_streaming_requires_finish_reason=True` if the server normally sends one.                                     |
| Usage is zero when streaming                                           | Server ignores `stream_options.include_usage`. Pydantic AI requests it by default; upgrade or configure the engine.                                                             |
| 401 with a real key leaking to your server                             | Ambient `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` used. Pass `api_key` and `base_url` explicitly.                                                                                 |
| 401 on `AnthropicModel` but curl with Bearer works                     | The gateway wants `Authorization: Bearer`. Pass `AnthropicProvider(anthropic_client=AsyncAnthropic(auth_token=..., base_url=...))`.                                             |
| `model not found` / 400 on model                                       | Using the repo id, not the alias from `/v1/models` (vLLM `--served-model-name`, LiteLLM `model_name`, llama-swap key, Ollama tag).                                              |
| Requests repeated after a timeout                                      | The SDK client retries (`max_retries` default 2 for Anthropic, OpenAI similar). Pass your own client with `max_retries=0` or a lower value.                                     |
| Ollama answers ignore long context                                     | Ollama's default context is small; raise `OLLAMA_CONTEXT_LENGTH` or the model's `num_ctx` (see the `ollama` skill).                                                             |
| `SSLError` certificate verify failed                                   | Private CA: `SSL_CERT_FILE=/path/ca.pem`, or pass `http_client=httpx.AsyncClient(verify=...)` to the provider. Do not disable verification.                                     |
| Import error for a provider                                            | Missing extra with `pydantic-ai-slim`: `pip install "pydantic-ai-slim[openai]"` or `[anthropic]`, or install `pydantic-ai`.                                                     |

## Official links

- https://pydantic.dev/docs/ai/models/compatible-apis/
- https://pydantic.dev/docs/ai/output/
- https://github.com/pydantic/pydantic-ai/issues
