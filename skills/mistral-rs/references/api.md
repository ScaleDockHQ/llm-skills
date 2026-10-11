# API and exposure

> Verified against mistral.rs v0.9.4 (docs `reference/http-api`, `reference/openai-compatibility`, `guides/deploy/production-checklist`), 2026-10-11

## Endpoints

| Surface                 | Paths                                                                                                                                 |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| OpenAI                  | `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/models`, `/v1/images/generations`, `/v1/audio/speech`               |
| Responses               | `/v1/responses` (+ `GET`/`DELETE` by id, `POST .../cancel`, `background: true`)                                                       |
| Anthropic               | `/v1/messages`, `/v1/messages/count_tokens` (base URL has no `/v1` for clients that append it)                                        |
| Files, skills, sessions | `/v1/files`, `/v1/skills`, `/v1/sessions/{id}`                                                                                        |
| Agent approvals         | `POST /v1/agent/approvals/{approval_id}`                                                                                              |
| LoRA                    | `/v1/lora_adapters`, `/v1/load_lora_adapter`, `/v1/unload_lora_adapter`                                                               |
| Ops                     | `/health` and `/` (liveness), `/metrics`, `/docs` (Swagger), `/api-doc/openapi.json`, `/ui` (web UI), `POST /mcp` (with `--mcp-port`) |

Not implemented: `/v1/tokenize`, moderation, Assistants, fine-tuning and batch APIs, `/v1/audio/transcriptions`. The live
`/docs` page matches the running build exactly; trust it over any list here.

```bash
curl -s http://127.0.0.1:1234/v1/models | jq '.data[] | {id, status, tools_available}'
curl -s http://127.0.0.1:1234/api-doc/openapi.json | jq '.paths | keys'
```

## Model routing

`"model": "default"` (or omitted) targets the default model. With several models, use ids exactly as `/v1/models` returns them. A
loaded LoRA alias can be sent as `model` using the exact returned id. `status` is `loaded`, `unloaded` or `reloading`.

## Authentication gap

None. `Authorization: Bearer ...` and `x-api-key` are accepted and ignored, so clients with a required key field work with any
non-empty string. Defaults you inherit: bind `0.0.0.0`, CORS allows any origin, body limit 50 MB; none are CLI-configurable (embed
`mistralrs-server-core`'s router for custom values).

Everything that mutates or executes is unauthenticated too: file upload and deletion, sessions, LoRA load/unload (when enabled),
agent approvals, skill upload, MCP port. Treat the whole HTTP surface as admin.

### Reverse proxy pattern

- Bind the server to `127.0.0.1` (or the container network only) and terminate TLS and auth in the proxy.
- Disable buffering for streaming: SSE is used by all three APIs. Raise read timeouts above the longest generation or tool loop
  (agent runs and background Responses can be minutes).
- Forward `x-request-id` so access logs correlate.
- Block `/metrics`, `/docs`, `/ui`, `/v1/load_lora_adapter`, `/v1/unload_lora_adapter` and `/mcp` from public routes unless you
  authenticate them. A global bearer check in front is simplest.
- Ready-made recipes: see the `caddy` skill (`npx skills add ScaleDockHQ/llms-skills --skill caddy`).

```bash
# Verify auth is enforced at the proxy before pointing users at it (key from a 0600 file, never echoed)
curl -s -o /dev/null -w 'no key: %{http_code}\n' https://llm.example.internal/v1/models
curl -s -o /dev/null -w 'with key: %{http_code}\n' -H "Authorization: Bearer $(cat ~/.config/llm/key)" https://llm.example.internal/v1/models
```

## Sessions and state

Sessions, uploaded files and uploaded skills live in process memory (skills in `--skills-dir`, default a temp dir). Sessions have a
30-minute idle TTL and a 128-entry LRU cap; export with `GET /v1/sessions/{id}` and re-import with `PUT` to survive restarts.
`DELETE` returns 200 even if the id did not exist. Responses objects are stored by default (`store: true`); use `store: false` for
sensitive prompts.

## Streaming

All three APIs use server-sent events (`text/event-stream`). `[DONE]` ends chat streams. Keep-alive comment frames are sent
(interval `KEEP_ALIVE_INTERVAL` ms), which keeps idle proxies from closing long prefill waits.

## Logging and privacy

`-l/--log <path>` records full model requests and responses. Access logs (`--access-log-format json`) record metadata only.
Prompts are not sent anywhere by the server itself, but `--enable-search` makes outbound web requests, and Hugging Face downloads
call the Hub unless `HF_HUB_OFFLINE=1`.
