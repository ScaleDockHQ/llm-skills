# OpenAI SDK troubleshooting against self-hosted servers

> Verified against openai-python v3.28.0 and openai-node v7.32.0 (client source and README), vLLM, llama.cpp, Ollama and llama-swap docs, 2026-10-11

Isolate first: run `BASE=<root> MODEL=<id> LLM_API_KEY_FILE=<file> scripts/check-endpoint.sh`. If the probe fails, the server or URL is wrong; if it passes, compare the app's URL, key, model and body.

| Symptom                                              | Cause                                                                                 | Fix                                                                                                  |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `Missing credentials` (Python and Node)              | No `api_key`/`apiKey` and no `OPENAI_API_KEY`                                         | Pass a key; use a placeholder for keyless servers                                                    |
| `404 Not Found` on every call                        | `base_url` lacks `/v1`, or includes `/chat/completions`, or a path prefix is dropped  | `https://host/v1`; check the proxy path                                                              |
| `404` only on `responses.create`                     | Server has no `/v1/responses`                                                         | Use `chat.completions`, or bridge in the gateway                                                     |
| `404` or `model not found` with the right URL        | Model string not served                                                               | List ids from `/v1/models`; use `--served-model-name`, `--alias`, gateway alias                      |
| `401 Unauthorized`                                   | Wrong or missing key; keyless client against a server with `--api-key`                | Send the right key; confirm the same key works with the probe                                        |
| `401` through a gateway that wants another header    | SDK only sends Bearer                                                                 | `default_headers` / `defaultHeaders`                                                                 |
| `APIConnectionError`, `ECONNREFUSED`, `fetch failed` | Server down, wrong port, container networking, or proxy                               | Probe from the same host; Docker needs a reachable hostname; set `NO_PROXY` for LAN hosts            |
| Certificate errors                                   | Self-signed or private CA                                                             | Trust the CA (`NODE_EXTRA_CA_CERTS`, Python TLS settings on the HTTP client)                         |
| `APITimeoutError` / hang then error                  | Model loading, long generation, or idle proxy timeout                                 | Raise `timeout`, stream, warm the model, raise the proxy timeout                                     |
| Retries multiply latency                             | Default 2 retries on timeout or 5xx                                                   | `max_retries=0` while debugging                                                                      |
| `tool_calls` is `None`, JSON appears in `content`    | Server lacks a tool parser or template                                                | vLLM `--enable-auto-tool-choice --tool-call-parser`, llama.cpp `--jinja`; see `tool-calling-parsers` |
| `400` on `tools` or `tool_choice`                    | Engine does not support the field (for example Ollama `tool_choice`)                  | Remove it, or use an engine that supports it                                                         |
| `400` unknown or invalid parameter                   | Vendor field rejected, or an OpenAI-only field (`store`, `metadata`, `service_tier`)  | Remove it; send vendor fields via `extra_body` only to servers that accept them                      |
| `stream_options` rejected                            | Server does not accept it                                                             | Omit `stream_options`; usage then arrives only in non-stream calls                                   |
| Empty `choices` in the last stream chunk             | `include_usage` usage chunk                                                           | Guard `chunk.choices` before indexing                                                                |
| Reasoning text missing or in `content`               | Parser off, or field name differs (`reasoning` vs `reasoning_content`)                | Enable `--reasoning-parser` or `--reasoning-format`; read both names                                 |
| `Invalid JSON` in tool `arguments`                   | Small model emitted malformed JSON                                                    | Retry, validate, or switch to a model with a native parser                                           |
| Wrong provider called after changing shells          | `OPENAI_BASE_URL` set in env or unset                                                 | Set the constructor argument explicitly; check `env`                                                 |
| Extra headers missing                                | `OPENAI_CUSTOM_HEADERS` lines not `Name: value`, or explicit `Authorization` override | One header per line; constructor headers win                                                         |

## Debug logging

`OPENAI_LOG=debug` prints requests (Python and Node). The Authorization header may appear: redact before pasting anywhere.

## Capture a clean report

1. Version: `openai.__version__` or `npm ls openai`.
2. URL shape (host redacted), model string, and whether the probe passes.
3. The server's log line for the failing request.
4. Never include keys, the `.env`, or full headers.

## Official links

- openai-python issues: https://github.com/openai/openai-python/issues
- openai-node issues: https://github.com/openai/openai-node/issues
