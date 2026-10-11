# API

> Verified against LMDeploy v0.18.0 (source `lmdeploy/serve/openai/endpoints/*`, `serve/utils/server_utils.py`; docs `llm/api_server*.md`), 2026-10-11

Base URL `http://127.0.0.1:23333`. Swagger UI at `/` (docs on unless `--disable-fastapi-docs`).

| Endpoint                                                                          | Notes                                                                                                                                                                               |
| --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GET /v1/models`                                                                  | Model IDs: `--model-name`, plus each LoRA adapter key                                                                                                                               |
| `POST /v1/chat/completions`                                                       | OpenAI chat; tools, `response_format`, streaming, `reasoning_content`                                                                                                               |
| `POST /v1/completions`                                                            | Text completions                                                                                                                                                                    |
| `POST /v1/responses`                                                              | Text-first subset of OpenAI Responses (no `background`, no `previous_response_id`; hosted tools like `web_search` accepted but ignored)                                             |
| `POST /v1/messages`, `/v1/messages/count_tokens`, `GET /anthropic/v1/models`      | Anthropic-compatible; send `anthropic-version: 2023-06-01`; text, `thinking` and `tool_use` blocks; `count_tokens` is an estimate                                                   |
| `POST /v1/embeddings`                                                             | Tagged unsupported                                                                                                                                                                  |
| `POST /v1/encode`                                                                 | Tokenize                                                                                                                                                                            |
| `POST /pooling`, `POST /get_ppl`                                                  | Pooling for reward models; perplexity                                                                                                                                               |
| `POST /generate`                                                                  | Native generate; `input_ids`, `return_logprob`, `logprob_start_len` (input scoring needs `--backend pytorch --logprobs-mode raw_logprobs`, `max_tokens=0`, no speculative decoding) |
| `GET /health`                                                                     | 200 when `healthy` or `sleeping`, else 503; JSON status snapshot                                                                                                                    |
| `GET /metrics`                                                                    | Prometheus, when metrics are enabled (default)                                                                                                                                      |
| `POST /sleep?level=1                                                              | 2`, `POST /wakeup`, `GET /is_sleeping`                                                                                                                                              | Free or restore GPU memory without exiting (RL and colocated workloads) |
| `POST /abort_request`                                                             | Needs `--enable-abort-handling`                                                                                                                                                     |
| `GET /terminate`                                                                  | Needs `--allow-terminate-by-client`                                                                                                                                                 |
| `/update_weights*`, `/init_weights_update_group`, `/destroy_weights_update_group` | Weight-sync routes for training loops                                                                                                                                               |
| `/distserve/*`                                                                    | Disaggregated serving control                                                                                                                                                       |

## Auth

`--api-keys k1 k2` makes `Authorization: Bearer <key>` mandatory for paths starting with `/v1`. Skipped: `OPTIONS`,
anything not under `/v1` (so `/generate`, `/pooling`, `/get_ppl`, `/sleep`, `/wakeup`, `/update_weights*`,
`/abort_request`, `/terminate`, `/metrics`), plus `/health`, `/docs`, `/redoc`, `/nodes`. Treat the key as protection for
the OpenAI routes only: put a gateway with real auth in front, deny the management paths there, and bind to
loopback. The Anthropic route `/v1/messages` is under `/v1`; the Anthropic `GET /anthropic/v1/models` is not.

```bash
KEY=$(cat ~/.config/lmdeploy/key)          # 0600 file
curl -s http://127.0.0.1:23333/v1/models -H "Authorization: Bearer $KEY" | jq '.data[].id'
```

## Sampling defaults

`--generation-config auto` (default) loads the model's `generation_config.json`; `lmdeploy` uses LMDeploy defaults;
a folder path loads that folder's config. v0.18.0 fixed a fallback to the model generation config. After an upgrade,
compare outputs if sampling seems different.
