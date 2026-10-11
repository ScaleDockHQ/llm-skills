# llama.cpp: HTTP API

> Verified against llama.cpp b11556 (master; tools/server/README.md) and v0.6.0, 2026-10-11

Base URL `http://HOST:PORT` (default `127.0.0.1:9931` on master, 8080 on v0.6.0 and older). OpenAI SDKs use `base_url=http://HOST:PORT/v1`. Add `Authorization: Bearer $(cat ~/.config/llama-server/key)` when `--api-key`/`--api-key-file` is set (read the key from a file; never paste it into a command line or log).

## Endpoint map

| Endpoint                                                                        | Purpose                                                                                                                    |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `GET /health`, `/v1/health`                                                     | Public. 503 while loading, 200 `{"status":"ok"}` when ready.                                                               |
| `GET /v1/models`, `GET /models`                                                 | Model list (alias name). `/models` is the router listing with status.                                                      |
| `POST /v1/chat/completions`                                                     | OpenAI chat: streaming, `tools`, `response_format`, images/audio/video parts, `chat_template_kwargs`.                      |
| `POST /v1/completions`                                                          | OpenAI text completion.                                                                                                    |
| `POST /v1/responses`                                                            | OpenAI Responses API. Token counting: `/v1/responses/input_tokens`, `/v1/chat/completions/input_tokens`.                   |
| `POST /v1/embeddings`, `/embedding`, `/embeddings`                              | Embeddings (need pooling not `none`).                                                                                      |
| `POST /v1/messages`, `/v1/messages/count_tokens`                                | Anthropic Messages API (clients send `x-api-key`).                                                                         |
| `POST /completion`                                                              | Native: `prompt`, `n_predict`, `json_schema`, `grammar`, `cache_prompt`, `id_slot`, `lora`, samplers.                      |
| `POST /tokenize`, `/detokenize`, `/apply-template`                              | Tokenizer and template helpers.                                                                                            |
| `POST /infill`                                                                  | Fill-in-the-middle for code models.                                                                                        |
| `POST /reranking`, `/rerank`, `/v1/rerank`, `/v1/reranking`                     | Reranking (`--embedding --pooling rank`, `--rerank`).                                                                      |
| `GET /props`, `POST /props`                                                     | Server properties: build, `chat_template`, modalities, default generation settings, sleeping status. POST needs `--props`. |
| `GET /slots`, `POST /slots/{id}?action=save\|restore\|erase`                    | Slot state and prompt-cache files (`--slot-save-path`).                                                                    |
| `GET/POST /lora-adapters`                                                       | List or set adapter scales.                                                                                                |
| `GET /metrics`                                                                  | Prometheus, needs `--metrics`. Router mode requires `?model=`.                                                             |
| `POST /models/load`, `/models/unload`, `GET /models/sse`, `POST/DELETE /models` | Router mode model control.                                                                                                 |
| `POST /v1/chat/completions/control`                                             | Control a running chat completion in real time (see the server README for payload).                                        |
| `POST /v1/systemone`                                                            | New in v0.6.0 for "decision" models only; not a general API.                                                               |

`/tools` is internal to the Web UI and not a stable API.

## Examples

```bash
B=http://127.0.0.1:9931
curl -s $B/v1/models | jq '.data[].id'

# Chat, streamed
curl -sN $B/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model":"local-model","stream":true,
  "messages":[{"role":"user","content":"Write a haiku about GPUs."}]
}'

# Structured output
curl -s $B/v1/chat/completions -H 'Content-Type: application/json' -d '{
  "model":"local-model",
  "messages":[{"role":"user","content":"Name and age of a fictional person as JSON."}],
  "response_format":{"type":"json_schema","schema":{"type":"object","properties":{"name":{"type":"string"},"age":{"type":"integer"}},"required":["name","age"]}}
}' | jq -r '.choices[0].message.content'

# Anthropic style
curl -s $B/v1/messages -H 'Content-Type: application/json' -H 'anthropic-version: 2023-06-01' -d '{
  "model":"local-model","max_tokens":128,"messages":[{"role":"user","content":"hi"}]}'

# Native completion with cache control and a pinned slot
curl -s $B/completion -H 'Content-Type: application/json' -d '{"prompt":"Once upon a time","n_predict":32,"cache_prompt":true,"id_slot":0}'

# Token count and loaded settings
curl -s $B/tokenize -H 'Content-Type: application/json' -d '{"content":"hello world"}' | jq
curl -s $B/props | jq '{build_info, model_path, modalities, default_generation_settings: .default_generation_settings.params | {temperature, top_k, top_p}}'
curl -s $B/slots | jq '.[] | {id, is_processing, n_ctx}'
```

Images in chat (multimodal model loaded):

```json
{
  "model": "local-model",
  "messages": [
    {
      "role": "user",
      "content": [
        { "type": "text", "text": "Describe this." },
        {
          "type": "image_url",
          "image_url": { "url": "data:image/png;base64,<BASE64>" }
        }
      ]
    }
  ]
}
```

## Useful request fields

- `cache_prompt` (default true), `id_slot` (pin a conversation to a slot for cache reuse), `n_predict`/`max_tokens`, `stop`, `seed`, `logit_bias`, `samplers`, per-request `temperature`, `top_k`, `top_p`, `min_p`, `repeat_penalty`, DRY and XTC fields.
- `chat_template_kwargs` per request (for example toggle thinking), `reasoning_format`-dependent `reasoning_content` in responses, `parallel_tool_calls`.
- `timings_per_token`, and the `timings` object in responses (prompt and predicted tokens per second) are the quickest per-request speed check.

## Errors

OpenAI-format error bodies, for example `{"error":{"code":401,"message":"Invalid API Key","type":"authentication_error"}}`. Common: 401 (bad or missing key; the Anthropic route needs `x-api-key`), 503 `Loading model` with type `unavailable_error` (wait for `/health` 200), 400 on router `/metrics` without `?model=` (`model name is missing from the request`). A prompt longer than the per-slot context is rejected or truncated (response field `truncated`); the per-slot window is `-c / -np` unless a unified KV buffer is used. Exact wording of context-overflow errors varies by build (unverified). Read/write timeouts follow `--timeout`.

## Sources

- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
