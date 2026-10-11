# API of mlc_llm serve

> Verified against MLC LLM main (8978ea9a; tags v0.20.0 and v0.26.dev0), 2026-10-11

Default base URL `http://127.0.0.1:8000`. When `--api-key` is set, send `Authorization: Bearer <key>`; a mismatch returns 401 `Invalid API Key`.

| Endpoint                                                                                                                                       | Notes                                                                                |
| ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `GET /v1/models`                                                                                                                               | Lists loaded model ids (the `HF://...` string or path you passed)                    |
| `POST /v1/chat/completions`                                                                                                                    | OpenAI chat, streaming, `tools`, `tool_choice`, `response_format`, `n`, `max_tokens` |
| `POST /v1/completions`                                                                                                                         | OpenAI text completions                                                              |
| `POST /v1/embeddings`                                                                                                                          | Needs `--embedding-model`                                                            |
| `GET /metrics`                                                                                                                                 | Prometheus text from the first engine                                                |
| `POST /debug/dump_event_trace`, `/debug/cuda_profiler_start`, `/debug/cuda_profiler_stop`, `/debug/dump_engine_metrics`, `/debug/reset_engine` | Only with `--enable-debug`                                                           |
| `POST /microserving/prep_recv`, `/remote_send`, `/start_generate`                                                                              | MicroServing sub-request APIs                                                        |

The `model` field in requests must match the served model id (the same string as `--model` or the id from `/v1/models`).

```bash
curl -s http://127.0.0.1:8000/v1/models | jq -r '.data[].id'
curl -sN http://127.0.0.1:8000/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"<id from /v1/models>","stream":true,"messages":[{"role":"user","content":"hi"}]}'
```

Auth is verified by a dependency on the OpenAI router; the `/metrics` router is mounted without it, so a key does not protect `/metrics`. Restrict it at the network or proxy.

## Python

`MLCEngine` (sync, no batching) and `AsyncMLCEngine` (batching) expose `engine.chat.completions.create(...)` with the OpenAI shape; construct with a model path or `HF://` id and optional `mode`, `model_lib`, `device`. Call `engine.terminate()` at the end.
