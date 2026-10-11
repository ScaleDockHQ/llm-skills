# llamafile API

> Verified against llamafile 0.10.6 (main a3ccf09), 2026-10-11

`llamafile --server` exposes llama.cpp's server. Default base URL `http://127.0.0.1:8080`. Fields and behavior follow the bundled llama.cpp and change between releases.

## Auth

`--api-key-file FILE` (or `--api-key KEY`). Send `Authorization: Bearer <key>` or `X-Api-Key: <key>`. Without a key omit the header. OpenAI SDKs need a non-empty `OPENAI_API_KEY` value even then. CORS limits browsers only; it is not authentication.

## Endpoints

| Area               | Endpoints                                                                                                                                              |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Chat               | `POST /v1/chat/completions` (+ `/input_tokens`, `/control`), `POST /v1/completions`                                                                    |
| Responses          | `POST /v1/responses` (+ `/input_tokens`; `previous_response_id` unsupported)                                                                           |
| Anthropic          | `POST /v1/messages`, `POST /v1/messages/count_tokens` (`max_tokens` defaults to 4096)                                                                  |
| Models             | `GET /v1/models`, `GET /models`                                                                                                                        |
| Embeddings, rerank | `POST /v1/embeddings`, `POST /v1/rerank` (alias `/v1/reranking`), native `/embedding`, `/rerank`                                                       |
| Audio              | `POST /v1/audio/transcriptions` when the model supports it                                                                                             |
| Native             | `GET /health` (alias `/v1/health`), `/props`, `/slots`, `POST /completion`, `/tokenize`, `/detokenize`, `/apply-template`, `/infill`, `/lora-adapters` |
| Metrics            | `GET /metrics` only with `--metrics`                                                                                                                   |
| Tools              | `GET /tools`, `POST /tools` (experimental; only with `--tools` or `--agent`)                                                                           |

Use `--alias` for a stable model name, `--api-prefix` to prefix paths (also for `/tools`).

## Examples

```bash
H=(); [ -n "${LLAMAFILE_API_KEY:-}" ] && H=(-H "Authorization: Bearer $LLAMAFILE_API_KEY")
curl -s "${H[@]}" http://127.0.0.1:8080/health
curl -s "${H[@]}" http://127.0.0.1:8080/v1/models | jq -r '.data[].id'
curl -s "${H[@]}" http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"local-model","messages":[{"role":"user","content":"Say OK"}],"max_tokens":16}' | jq -r '.choices[0].message.content'
curl -s "${H[@]}" http://127.0.0.1:8080/v1/messages -H 'Content-Type: application/json' \
  -d '{"model":"local-model","max_tokens":64,"messages":[{"role":"user","content":"Say OK"}]}' | jq -r '.content[0].text'
```

The chat response includes a `timings` object (prompt and predicted tokens per second) useful for quick benchmarks.

## Tool-call shapes

| API                | Tool definitions              | Requested call                  | Result goes back as                            |
| ------------------ | ----------------------------- | ------------------------------- | ---------------------------------------------- |
| Chat Completions   | `tools[].function`            | `message.tool_calls[]`          | message with `role: "tool"` and `tool_call_id` |
| Responses          | `tools[]` function objects    | `output[]` item `function_call` | `input[]` item `function_call_output`          |
| Anthropic Messages | `tools[]` with `input_schema` | content block `tool_use`        | user content block `tool_result`               |

## Errors

API errors use an OpenAI-style envelope with `error.code` (the HTTP status), `error.message` and `error.type` (`invalid_request_error`, `authentication_error`, `permission_error`, `not_found_error`, `server_error`, `not_supported_error`). `/health` returns 503 while the model loads. Large models take time to load; set client timeouts accordingly.
