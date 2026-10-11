# llama-swap API surface

> Verified against llama-swap v263 (README feature list, docs/kb), 2026-10-11

All inference routes read the `model` field (or the `?model=` query where noted), load that model if needed, then proxy the request. The IDs are the keys under `models:`, their `aliases`, `setParamsByID` keys and peer IDs.

## Inference endpoints

| Family               | Paths                                                                                                                                                                                                        |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| OpenAI               | `/v1/completions`, `/v1/chat/completions`, `/v1/responses`, `/v1/embeddings`, `/v1/models`, `/v1/audio/speech`, `/v1/audio/transcriptions`, `/v1/audio/voices`, `/v1/images/generations`, `/v1/images/edits` |
| Anthropic            | `/v1/messages`, `/v1/messages/count_tokens`                                                                                                                                                                  |
| llama-server         | `/v1/rerank`, `/v1/reranking`, `/rerank`, `/infill`, `/completion`, `/models`, `/props?model=<id>` (autoload ignored)                                                                                        |
| stable-diffusion.cpp | `/sdapi/v1/txt2img`, `/sdapi/v1/img2img`, `/sdapi/v1/loras` (needs `model` in the body)                                                                                                                      |
| audio.cpp            | `/audioapi/v1/tasks/run`                                                                                                                                                                                     |
| ComfyUI              | `/comfyui/` custom endpoint for reliable swapping (see `combos/comfyui-images.md`)                                                                                                                           |

Whether a model works on a given route depends on the upstream server, not on llama-swap.

## Control endpoints

| Path                                            | Purpose                                                                                                                |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `GET /health`                                   | Returns `OK`.                                                                                                          |
| `GET /running`                                  | Loaded models and their state.                                                                                         |
| `POST /api/models/unload`                       | Unload everything.                                                                                                     |
| `POST /api/models/unload/<id>`                  | Unload one model.                                                                                                      |
| `GET /api/profiles`, `PUT /api/profiles/active` | List and select profiles.                                                                                              |
| `/upstream/<id>/<path>`                         | Direct pass-through to a model's own API and web UI (loads it). Paths in `upstream.ignorePaths` do not trigger a swap. |
| `/ui`                                           | Web UI: playground, Activity, models, logs, Help agent.                                                                |
| `/metrics`                                      | System and GPU metrics for Prometheus.                                                                                 |
| `/api/mcp`                                      | MCP endpoint serving llama-swap's own documentation tools.                                                             |

## Logs

```bash
curl -s  http://host/logs                      # buffered plain text (Accept: text/html redirects to /ui/)
curl -Ns http://host/logs/stream               # live, history first
curl -Ns http://host/logs/stream/proxy         # llama-swap itself
curl -Ns http://host/logs/stream/upstream      # engine stdout and stderr
curl -Ns http://host/logs/stream/http          # access log
curl -Ns http://host/logs/stream/<model_id>    # one model (IDs with slashes work)
curl -Ns 'http://host/logs/stream?no-history'  # new lines only
```

## Auth

With `apiKeys` set, add `-H "Authorization: Bearer $KEY"` (or `x-api-key`) everywhere, including `/ui` and `/api/`. Read the key from a file or an environment variable; do not paste it into logs.

## Model listing

`/v1/models` returns `name`, `description`, `metadata` and `capabilities` for listed models. Aliases appear only with `includeAliasesInList: true`; `unlisted: true` models are hidden but callable. Clients should read it before choosing a model and tolerate a long first-request wait (`sendLoadingState: true` streams progress).

## Sources

- <https://github.com/mostlygeek/llama-swap#features>
- <https://github.com/mostlygeek/llama-swap/tree/main/docs/kb/guides/api-integration>
