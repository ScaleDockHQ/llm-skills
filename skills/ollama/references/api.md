# Ollama: APIs

> Verified against Ollama v0.40.3, 2026-10-11

Docs/openapi.yaml, docs: api/openai-compatibility, api/anthropic-compatibility, api/authentication, faq; server/routes.go route table

Base URL `http://127.0.0.1:11434`. No authentication locally; OpenAI clients need a dummy `api_key`. Direct cloud use is `https://ollama.com` with a bearer key (`features.md`).

## Native API

| Endpoint                                                    | Purpose                                                                             |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `GET /`, `GET /api/version`                                 | Liveness ("Ollama is running") and `{"version": ...}`. Neither loads a model        |
| `GET /api/status`                                           | Cloud status (`cloud.disabled`)                                                     |
| `POST /api/chat`                                            | Chat with `messages`, `tools`, `think`, `format`, `options`, `keep_alive`, `stream` |
| `POST /api/generate`                                        | Prompt completion; empty request preloads; `keep_alive: 0` unloads                  |
| `POST /api/embed` (older: `/api/embeddings`)                | Embeddings                                                                          |
| `GET /api/tags`                                             | Local models (also `HEAD`)                                                          |
| `GET /api/ps`                                               | Loaded models: `size`, `size_vram`, `context_length`, `expires_at`                  |
| `POST /api/show`                                            | Model details, capabilities, `thinking` values, parameters, template                |
| `POST /api/pull`, `POST /api/push`, `DELETE /api/delete`    | Manage models                                                                       |
| `POST /api/create`, `POST /api/copy`, `/api/blobs/{digest}` | Create from Modelfile content, copy, upload blobs                                   |
| `GET /api/usage`, `GET /api/balance`                        | Cloud usage and balance for the signed-in account                                   |

`options` (per request) take the Modelfile parameters, for example `num_ctx`, `temperature`, `top_p`, `top_k`, `seed`, `num_predict`, `stop`. Responses end with timing fields (`total_duration`, `load_duration`, `prompt_eval_count`, `prompt_eval_duration`, `eval_count`, `eval_duration`, nanoseconds). `format` takes `"json"` or a JSON schema.

```bash
curl -s http://127.0.0.1:11434/api/chat -d '{"model":"qwen3:8b","messages":[{"role":"user","content":"Hi"}],"stream":false,"options":{"num_ctx":16384},"keep_alive":"10m"}' | jq .
```

## OpenAI-compatible (`/v1`)

Base URL `http://127.0.0.1:11434/v1/`, any api key string.

| Endpoint                               | Supported                                                                                                                                                                                                   | Not supported                                                       |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `POST /v1/chat/completions`            | streaming, `stream_options.include_usage`, JSON mode and `response_format`, `seed`, `stop`, `temperature`, `top_p`, `max_tokens`, penalties, `tools`, base64 images, `reasoning_effort`, `reasoning.effort` | `tool_choice`, `logprobs`, `logit_bias`, `n`, `user`, image URLs    |
| `POST /v1/completions`                 | streaming, `suffix`, `seed`, `stop`, sampling params                                                                                                                                                        | `best_of`, `echo`, `logprobs`, `n`, prompt as anything but a string |
| `GET /v1/models`, `GET /v1/models/{m}` | listing; `owned_by` is the Ollama username (default `library`)                                                                                                                                              |                                                                     |
| `POST /v1/embeddings`                  | string or array of strings, `encoding_format`, `dimensions`                                                                                                                                                 | token arrays, `user`                                                |
| `POST /v1/responses`                   | stateless: streaming, `tools`, `instructions`, `max_output_tokens`, `reasoning.effort`, `think` extension (added in v0.13.3)                                                                                | `previous_response_id`, `conversation`, `truncation`                |

- The context size cannot be set through `/v1`; use `OLLAMA_CONTEXT_LENGTH` or a Modelfile with `PARAMETER num_ctx` and call the derived model name.
- Clients that hardcode `gpt-3.5-turbo`: `ollama cp llama3.2 gpt-3.5-turbo`.
- The model name is the Ollama name (`qwen3:8b`), not a Hugging Face id.

```python
from openai import OpenAI
client = OpenAI(base_url="http://127.0.0.1:11434/v1/", api_key="ollama")  # key is required but ignored
print(client.chat.completions.create(model="qwen3:8b", messages=[{"role": "user", "content": "Say hi"}]).choices[0].message.content)
```

## Anthropic-compatible

`POST /v1/messages` on the same port (`ANTHROPIC_BASE_URL=http://127.0.0.1:11434`; for Claude Code use a dummy token). Supported: messages, streaming events, system prompts, multi-turn, base64 vision, `tools`, `tool_result`, thinking blocks, `thinking`, `output_config.effort`, `top_k`, `stop_sequences`. Not supported: `tool_choice`, `metadata`, `/v1/messages/count_tokens`, prompt caching (`cache_control`), batches, citations, PDF `document` blocks, URL images, in-stream `error` events (errors return an HTTP status); `budget_tokens` is accepted but not enforced; token counts are approximate. Alias hardcoded names: `ollama cp qwen3-coder claude-3-5-sonnet`. Recommended local models in the docs: `qwen3-coder`, `gpt-oss:20b`.

## Errors and limits

- `503`: queue full (`OLLAMA_MAX_QUEUE`).
- `403` with an empty body: unfamiliar `Host` header while bound to loopback (`serve-config.md`).
- `404 model not found`: pull first, or use the exact name from `/api/tags`.
- Requests for a model that does not fit wait in the queue instead of failing (`parallelism-multinode.md`).

## Useful one-liners

```bash
curl -s http://127.0.0.1:11434/api/tags | jq -r '.models[].name'
curl -s http://127.0.0.1:11434/api/show -d '{"model":"qwen3:8b"}' | jq '{capabilities, details, thinking}'
curl -s http://127.0.0.1:11434/api/generate -d '{"model":"qwen3:8b","keep_alive":0}'     # unload
```
