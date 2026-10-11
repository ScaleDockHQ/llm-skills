# LocalAI API

> Verified against LocalAI v4.11.0, 2026-10-11

Base URL `http://127.0.0.1:8080`. The model field is the model YAML `name` or a gallery name. With auth on, send `Authorization: Bearer <key>`, `x-api-key` or `xi-api-key`.

## Endpoints

| Area                  | Endpoints                                                                                                                                 |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Chat and text         | `POST /v1/chat/completions`, `/v1/completions`, `/v1/edits`, `GET /v1/models`                                                             |
| Anthropic             | `POST /v1/messages` (tools, streaming)                                                                                                    |
| Open Responses        | `POST /v1/responses`, `GET /v1/responses/:id`, `/v1/responses/:id/events`; background mode and WebSocket                                  |
| Embeddings and rerank | `POST /v1/embeddings`, `POST /v1/rerank` (also `/jina/v1/rerank`)                                                                         |
| Tokens                | `POST /v1/tokenize`, `/v1/detokenize`                                                                                                     |
| Images and video      | `POST /v1/images/generations`, `/v1/images/edits`, `/v1/video/generations`                                                                |
| Audio                 | `POST /v1/audio/transcriptions`, `/v1/audio/speech`, `/tts`, VAD (`/v1/vad` or `/v1/audio/vad`; check `/swagger`), `/v1/sound-generation` |
| Vision tasks          | `POST /v1/detection`                                                                                                                      |
| MCP                   | `POST /v1/mcp/chat/completions`                                                                                                           |
| Ollama style          | `/api/*` routes (always available); `LOCALAI_OLLAMA_API_ROOT_ENDPOINT=true` makes `/` an Ollama health check instead of the web UI        |
| Ops                   | `GET /healthz`, `/readyz`, `/version`, `/metrics`, `/swagger`                                                                             |

Per-modality details change often; fetch `/swagger` from the running server.

## Smoke tests

```bash
H=(-H "Authorization: Bearer $LOCALAI_API_KEY")        # drop when auth is off
curl -s "${H[@]}" http://127.0.0.1:8080/v1/models | jq -r '.data[].id'
curl -s "${H[@]}" http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"qwen3-4b","messages":[{"role":"user","content":"Say OK"}],"max_tokens":16}' | jq -r '.choices[0].message.content'
curl -sN "${H[@]}" http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"qwen3-4b","stream":true,"messages":[{"role":"user","content":"Count to 3"}]}'
curl -s "${H[@]}" http://127.0.0.1:8080/v1/embeddings -H 'Content-Type: application/json' \
  -d '{"model":"<embedding-model>","input":"hello"}' | jq '.data[0].embedding | length'
curl -s "${H[@]}" http://127.0.0.1:8080/v1/rerank -H 'Content-Type: application/json' \
  -d '{"model":"<reranker>","query":"organic skincare","documents":["a","b"],"top_n":1}'
```

A first request to a model loads it, which can take minutes for large models; set client timeouts accordingly.

## Errors

| Code      | Meaning                                                                                                                  |
| --------- | ------------------------------------------------------------------------------------------------------------------------ |
| 400 / 422 | Bad JSON, missing `model` or `messages`, invalid parameter values                                                        |
| 401       | Missing or wrong API key                                                                                                 |
| 404       | Model or resource not found                                                                                              |
| 429       | Concurrency saturated (per-model `max_concurrent` or the process ceiling) with `Retry-After`                             |
| 500       | Backend or server error; the log has the real cause                                                                      |
| 503       | Model-load cooldown after a failed load (with `Retry-After`), cold-loading model, or no healthy node in distributed mode |

Error bodies follow the endpoint's own shape: OpenAI style, Anthropic style on `/v1/messages`, Open Responses style on `/v1/responses`. `LOCALAI_OPAQUE_ERRORS=true` replaces them with blank 500s.

## Python client

```python
from openai import OpenAI
import os
client = OpenAI(base_url="http://127.0.0.1:8080/v1", api_key=os.environ["LOCALAI_API_KEY"])
print(client.chat.completions.create(model="qwen3-4b",
      messages=[{"role": "user", "content": "Say OK"}]).choices[0].message.content)
```
