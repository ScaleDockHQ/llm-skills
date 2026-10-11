# LM Studio API surface

> Verified against LM Studio 0.4.26 and lmstudio.ai/docs/developer (rest, openai-compat, anthropic-compat, api-changelog), 2026-10-11

Base URL `http://localhost:1234`. Add `-H "Authorization: Bearer $LM_API_TOKEN"` to every call when **Require Authentication** is on (`x-api-key` also works). The `model` value is the model key from `lms ls` or the `--identifier` you set.

## Endpoint families

| Family                                    | Endpoints                                                                                                                                  | Since                   |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------- |
| OpenAI-compatible                         | `GET /v1/models`, `POST /v1/responses`, `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/decisions`                       | `/v1/responses` 0.3.29  |
| Anthropic-compatible                      | `POST /v1/messages`                                                                                                                        | 0.4.1                   |
| Native v1 REST (recommended for new work) | `POST /api/v1/chat`, `GET /api/v1/models`, `POST /api/v1/models/load`, `/models/unload`, `/models/download`, `GET /models/download/status` | 0.4.0                   |
| Legacy v0 REST                            | `/api/v0/models`, `/api/v0/chat/completions`, `/completions`, `/embeddings` (richer stats: tokens/s, TTFT)                                 | 0.3.6; superseded by v1 |

`/v1/decisions` is a new endpoint for decision models; `lms ls --decision` lists them. Details are in the upstream docs (not covered further here).

## Feature comparison (upstream table)

| Feature                               | `/api/v1/chat` | `/v1/responses` | `/v1/chat/completions` | `/v1/messages` |
| ------------------------------------- | :------------: | :-------------: | :--------------------: | :------------: |
| Streaming                             |      yes       |       yes       |          yes           |      yes       |
| Stateful chat                         |      yes       |       yes       |           no           |       no       |
| Remote MCPs                           |      yes       |       yes       |           no           |       no       |
| MCPs configured in LM Studio          |      yes       |       yes       |           no           |       no       |
| Custom tools                          |       no       |       yes       |          yes           |      yes       |
| Assistant messages in request         |       no       |       yes       |          yes           |      yes       |
| Model load / prompt processing events |      yes       |       no        |           no           |       no       |
| Context length in request             |      yes       |       no        |           no           |       no       |

## OpenAI-compatible

```bash
curl -s http://localhost:1234/v1/models | jq -r '.data[].id'
curl -s http://localhost:1234/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"local-model","messages":[{"role":"user","content":"Say hi"}],"temperature":0.7}'
curl -s http://localhost:1234/v1/responses -H 'Content-Type: application/json' \
  -d '{"model":"openai/gpt-oss-20b","input":"Provide a prime number less than 50","reasoning":{"effort":"low"}}'
```

Existing OpenAI SDKs only need `base_url="http://localhost:1234/v1"` (any non-empty API key if auth is off). `/v1/responses` supports `previous_response_id` for stateful follow-ups, streaming, custom tools, remote MCP (opt-in) and `reasoning.effort` for `openai/gpt-oss-20b`.

## Anthropic-compatible

```bash
curl -s http://localhost:1234/v1/messages -H 'Content-Type: application/json' \
  -H "x-api-key: ${LM_API_TOKEN:-lmstudio}" \
  -d '{"model":"ibm/granite-4-micro","max_tokens":256,"messages":[{"role":"user","content":"Say hello"}]}'
```

The `x-api-key` header is optional when authentication is off. Streaming emits the usual SSE events (`message_start`, `content_block_delta`, `message_stop`, and so on); tools use `tools` + `tool_choice`. Clients such as the Anthropic Python SDK take `base_url="http://localhost:1234"` (no `/v1`).

## Native v1 REST

```bash
# Load with settings (llama.cpp-engine-only options are ignored for MLX models)
curl -s http://localhost:1234/api/v1/models/load -H "Authorization: Bearer $LM_API_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"model":"openai/gpt-oss-20b","context_length":16384,"flash_attention":true,"echo_load_config":true}'
# Unload
curl -s http://localhost:1234/api/v1/models/unload -H "Authorization: Bearer $LM_API_TOKEN" \
  -H 'Content-Type: application/json' -d '{"instance_id":"openai/gpt-oss-20b"}'
# Download (catalog id or exact Hugging Face URL; quantization only with HF links)
curl -s http://localhost:1234/api/v1/models/download -H "Authorization: Bearer $LM_API_TOKEN" \
  -H 'Content-Type: application/json' -d '{"model":"ibm/granite-4-micro"}'
```

Load body fields: `model`, `context_length`, `eval_batch_size`, `flash_attention`, `num_experts`, `offload_kv_cache_to_gpu`, `echo_load_config`. Download returns `job_id` and `status` (`downloading`, `paused`, `completed`, `failed`, `already_downloaded`); poll `GET /api/v1/models/download/status`.

`POST /api/v1/chat` body: `model`, `input` (string or array of text/image items), `system_prompt`, `integrations` (plugin ids, `mcp/<label>` entries or ephemeral MCP objects), `context_length`, `temperature` and more. The response has `output` items of type `reasoning`, `message` and `tool_call`, plus `stats` and `response_id` for stateful chats. See `features.md` for MCP.

## Idle TTL on any request

Add `"ttl": <seconds>` to the request body of the call that triggers a JIT load (see `configuration.md`).

## Official links

- REST overview: https://lmstudio.ai/docs/developer/rest
- Chat / load / unload / download: https://lmstudio.ai/docs/developer/rest/chat, https://lmstudio.ai/docs/developer/rest/load, https://lmstudio.ai/docs/developer/rest/unload, https://lmstudio.ai/docs/developer/rest/download
- OpenAI compatibility: https://lmstudio.ai/docs/developer/openai-compat
- Responses: https://lmstudio.ai/docs/developer/openai-compat/responses
- Anthropic compatibility: https://lmstudio.ai/docs/developer/anthropic-compat
- API changelog: https://lmstudio.ai/docs/developer/api-changelog
