# LangChain: troubleshooting

> Verified against LangChain langchain v1.4.4 (langchain-core 1.6.9, langchain-openai 1.7.0, langchain-anthropic 1.7.5, langchain-ollama 1.1.0), 2026-10-11

First reproduce outside LangChain: `BASE_URL=... MODEL=... KEY_FILE=... scripts/probe.sh openai` (or `anthropic`). If curl works and LangChain fails, suspect URL shape, class choice, `method=` or an env var that redirects.

| Symptom                                                                    | Likely cause and fix                                                                                                                                                        |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 404 on every call                                                          | OpenAI-compatible `base_url` missing `/v1`, or `ChatAnthropic` base URL given with `/v1` (the Anthropic SDK adds it, giving `/v1/v1/messages`).                             |
| 404 on `/responses`                                                        | `use_responses_api=True`, or a Responses-only feature (built-in tools, reasoning summaries) triggered it. Remove it; chat-only endpoints serve `/chat/completions`.         |
| Calls go to api.openai.com or another host than expected                   | An env var wins when `base_url` is unset: `OPENAI_API_BASE`, `OPENAI_BASE_URL`, `ANTHROPIC_API_URL`, `ANTHROPIC_BASE_URL`, `LANGSMITH_GATEWAY`. Pass `base_url` explicitly. |
| 401 with a real key leaking to your server                                 | Ambient `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` was used. Pass `api_key` explicitly.                                                                                        |
| 401 on `ChatAnthropic` but curl with Bearer works                          | The gateway wants `Authorization: Bearer`; ChatAnthropic sends `x-api-key`. Pass `default_headers={"Authorization": ...}`.                                                  |
| "Could not resolve authentication method"                                  | No `api_key` and no Authorization header for `ChatAnthropic`; set `api_key` or `default_headers`.                                                                           |
| `model not found` / 400 on model                                           | Using the repo id, not the alias from `/v1/models` (vLLM `--served-model-name`, LiteLLM `model_name`, llama-swap key, Ollama tag).                                          |
| `usage_metadata` is None while streaming                                   | `stream_usage` is off with a custom base URL. Set `stream_usage=True`; the engine must honor `stream_options.include_usage`.                                                |
| `tool_calls` is empty, tool JSON in `content`                              | Engine lacks a tool parser: vLLM `--enable-auto-tool-choice --tool-call-parser`, llama-server `--jinja`, Ollama model without tool support.                                 |
| 400 when `tool_choice` is forced                                           | The server does not support forced tool choice; drop it or use `auto`.                                                                                                      |
| `OutputParserException` / `ValidationError` from `with_structured_output`  | Engine ignores `json_schema`. Use `method="function_calling"`, or `json_mode` plus a prompt; lower temperature; `include_raw=True` to inspect the raw reply.                |
| `create_agent` returns no `structured_response` or loops on a custom alias | Model profile unknown, so the wrong strategy was auto-selected. Pass `ToolStrategy(Schema)` or `ProviderStrategy(Schema)` explicitly; give the model a `profile`.           |
| `reasoning_content` missing                                                | `ChatOpenAI` does not extract non-standard fields. Read the raw response with the `openai` SDK, or use a provider package.                                                  |
| `<think>` in the answer                                                    | Engine reasoning parser disabled; enable it (vLLM `--reasoning-parser`) or strip in a post-processing step.                                                                 |
| Empty reply, finish reason `length`                                        | Reasoning used the whole `max_tokens`. Raise it or disable thinking.                                                                                                        |
| `ChatOllama` ignores long prompts                                          | Ollama's default context is small; set `num_ctx` on `ChatOllama` or raise `OLLAMA_CONTEXT_LENGTH` on the server.                                                            |
| `ChatOllama` connection refused from a container                           | `base_url` must be reachable from the container (`http://host.docker.internal:11434`); the server must listen beyond localhost (`OLLAMA_HOST`).                             |
| `SSLError` certificate verify failed                                       | Private CA: `SSL_CERT_FILE=/path/ca.pem`, or pass `http_client=httpx.Client(verify=...)`. Do not disable verification.                                                      |
| Stream arrives all at once                                                 | A proxy buffers SSE; disable proxy buffering or use a tunnel that streams.                                                                                                  |
| Duplicate requests after a timeout                                         | `max_retries` retries a slow generation; lower it for local models.                                                                                                         |
| Import errors after upgrade                                                | Mixed majors of `langchain`, `langchain-core` and partner packages. `pip install -U` them together; see `updating.md`.                                                      |

## Official links

- https://docs.langchain.com/oss/python/integrations/chat/openai
- https://docs.langchain.com/oss/python/langchain/structured-output
- https://github.com/langchain-ai/langchain/issues
- https://reference.langchain.com/python/langchain-openai/chat_models/base/ChatOpenAI
