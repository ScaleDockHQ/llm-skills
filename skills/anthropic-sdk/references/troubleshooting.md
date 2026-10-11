# Anthropic SDK troubleshooting against self-hosted servers

> Verified against anthropic-sdk-python v1.13.0 and anthropic-sdk-typescript sdk-v0.133.0 (client source and platform docs), vLLM, llama.cpp, Ollama and llama-swap docs, 2026-10-11

Isolate first: `BASE=<root> MODEL=<id> LLM_API_KEY_FILE=<file> scripts/check-endpoint.sh` and read the `/v1/messages` lines. If the probe fails, fix the server or URL; if it passes, compare URL, header, model and body with the app's.

| Symptom                                                     | Cause                                                                 | Fix                                                                                                  |
| ----------------------------------------------------------- | --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `404` on `/v1/v1/messages`                                  | `base_url` ends with `/v1`                                            | Use the root without `/v1`                                                                           |
| `404` on `/v1/messages`                                     | Server has no Messages route                                          | Use `openai-sdk`, or a gateway that translates                                                       |
| `404` or "model not found"                                  | Model id not served                                                   | Use ids from `/v1/models`, `--served-model-name`, `--alias`, gateway alias                           |
| `401` with a valid key                                      | Wrong header: vLLM wants Bearer, the app sent `api_key` (`x-api-key`) | Use `auth_token` / `authToken`                                                                       |
| `401` on Ollama cloud                                       | `x-api-key` alone rejected                                            | `auth_token` with the Ollama key                                                                     |
| `401` and both options set                                  | Both headers sent; one is wrong                                       | Set only the one the server checks                                                                   |
| Request fails before sending, auth error                    | No credential at all                                                  | Pass a placeholder for keyless servers                                                               |
| `400` `anthropic-beta` or unknown field                     | Server rejects betas or Anthropic-only fields                         | Use `client.messages`, drop `betas`, `thinking`, `cache_control`, server tools                       |
| `400` `max_tokens` missing                                  | Required field absent                                                 | Always pass `max_tokens`                                                                             |
| `ValueError` or error about expected time for non-streaming | Large `max_tokens` without streaming                                  | Stream, or set `timeout`                                                                             |
| `tool_use` blocks never appear, JSON in text                | No tool parser or template                                            | vLLM `--enable-auto-tool-choice --tool-call-parser`, llama.cpp `--jinja`; see `tool-calling-parsers` |
| `400` on `tool_result`                                      | Missing matching `tool_use_id`, or result not in a `user` message     | Echo the assistant content blocks, then a `user` message with `tool_result`                          |
| Stream arrives all at once or stalls                        | Proxy buffering or idle timeout                                       | Disable buffering, raise timeouts                                                                    |
| Stream events malformed                                     | Route returns OpenAI-style chunks                                     | The server is not Messages-compatible: use `openai-sdk`                                              |
| `APITimeoutError` / connection errors                       | Model loading, long generation, networking, proxy                     | Raise `timeout`, warm the model, set `NO_PROXY` for LAN hosts                                        |
| Retries multiply latency                                    | 2 default retries on timeouts/5xx                                     | `max_retries=0` while debugging                                                                      |
| Certificate errors                                          | Private CA                                                            | Trust the CA (`NODE_EXTRA_CA_CERTS`, Python HTTP client TLS settings)                                |
| Calls go to the wrong host                                  | `ANTHROPIC_BASE_URL` or default left unset                            | Set `base_url` explicitly; check `env`                                                               |
| `count_tokens` 404                                          | Route not implemented                                                 | Use `usage` from responses                                                                           |

## Debug logging

`ANTHROPIC_LOG=debug` logs requests in both SDKs. Credentials may appear in headers: redact before sharing.

## Capture a clean report

1. Version: `anthropic.__version__` or `npm ls @anthropic-ai/sdk`.
2. URL shape (host redacted), credential option used, model string, probe result.
3. The server's log line for the failing request.
4. Never include keys, `.env` files or full headers.

## Official links

- Python SDK issues: https://github.com/anthropics/anthropic-sdk-python/issues
- TypeScript SDK issues: https://github.com/anthropics/anthropic-sdk-typescript/issues
