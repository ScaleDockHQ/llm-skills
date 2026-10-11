# KoboldCpp API

> Verified against KoboldCpp v1.122.1 (README, koboldcpp.py --help, GitHub releases), 2026-10-11

Base URL `http://127.0.0.1:5001` (change with `--host`, `--port`). Interactive docs at `/api`; the
reference at https://lite.koboldai.net/koboldcpp_api. Chat and completion paths also work without the `/v1` prefix
(`/chat/completions`, `/completions`, `/models`).

## Interfaces

| Path                | What                 |
| ------------------- | -------------------- |
| `/`                 | KoboldAI Lite UI     |
| `/lcpp`             | llama.cpp web UI     |
| `/sdui`, `/musicui` | image and music UIs  |
| `/api` (`/docs`)    | interactive API docs |

## OpenAI style

`/v1/chat/completions`, `/v1/completions`, `/v1/responses`, `/v1/embeddings`, `/v1/models`,
`/v1/images/generations`, `/v1/images/edits`, `/v1/audio/speech`, `/v1/audio/transcriptions`,
`/v1/audio/voices`. Anthropic style: `/v1/messages`. Ollama style: `/api/chat`, `/api/generate`, `/api/embed`,
`/api/show`. Others: A1111 `/sdapi/v1/*`, ComfyUI emulation, XTTS, `/props` and `/slots` (llama.cpp web UI),
`POST /mcp`.

```bash
curl -s http://127.0.0.1:5001/v1/chat/completions -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $KCPP_PASSWORD" \
  -d '{"model":"koboldcpp","stream":true,"messages":[{"role":"user","content":"Hi"}]}'
```

The `model` value is ignored in normal mode (one model per process). In router mode it names a file in
`--admindir`.

## KoboldAI native

`POST /api/v1/generate`, `GET /api/v1/model`, `/api/v1/config/max_context_length`, `/api/v1/config/max_length`.
Extra: `POST /api/extra/generate/stream` (SSE), `GET /api/extra/generate/check` (poll partial output),
`POST /api/extra/abort`, `/api/extra/tokencount`, `/api/extra/tokenize`, `/api/extra/detokenize`,
`GET /api/extra/last_logprobs`, `GET /api/extra/true_max_context_length`, `GET /api/extra/version`
(capabilities), `GET /api/extra/perf` (speeds, queue, idle, uptime), `POST /api/extra/shutdown`
(only honoured from localhost when `--singleinstance` is set), `/api/extra/websearch` (needs `--websearch`), `/api/extra/data/*` (needs `--savedatafile`).

## Auth

`--password` requires `Authorization: Bearer <key>` on text endpoints (`secure_endpoint` returns 401
otherwise). `/api/v1/model` returns `koboldcpp/protected-model` without a valid key. Image endpoints are not
secured. `--adminpassword` guards `/api/admin/*`. There is no per-user key model: use a gateway for that.

## Admin routes (need `--admin --admindir`)

`GET /api/admin/list_options` (configs in the dir), `POST /api/admin/reload_config` with
`{"filename":"x.kcpps"}` (also `unload_model` and `initial_model`; optional `baseconfig`), plus
`/api/admin/save_state`, `load_state`, `check_state`, `clear_state`. Only files listed in the admin directory
are accepted.

## Streaming

OpenAI `"stream": true` returns SSE chunks; native streaming uses `/api/extra/generate/stream`. Reverse
proxies must not buffer SSE (see `integrations.md`).
