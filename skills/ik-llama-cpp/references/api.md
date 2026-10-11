# API of ik_llama.cpp llama-server

> Verified against ik_llama.cpp main (89bba35c), examples/server/README.md, 2026-10-11

Default base URL `http://127.0.0.1:8080`. Authentication is a bearer key when `--api-key`/`--api-key-file` is set.

| Endpoint                                       | Notes                                                                                                   |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `GET /health`                                  | 200 `{"status":"ok",...}`, 503 while loading, 500 on load failure; `?fail_on_no_slot`, `?include_slots` |
| `POST /v1/chat/completions`                    | OpenAI Chat Completions; tools need `--jinja`                                                           |
| `POST /v1/responses`                           | OpenAI Responses API                                                                                    |
| `POST /v1/embeddings`, `/embedding`            | Embeddings (use `--embedding` models)                                                                   |
| `GET /v1/models`                               | Model list; name comes from `-a`                                                                        |
| `POST /completion`                             | Native completion with llama.cpp parameters                                                             |
| `POST /tokenize`, `/detokenize`                | Tokenizer helpers                                                                                       |
| `POST /infill`                                 | Code infill                                                                                             |
| `GET /slots`                                   | Slot state; disable with `--slots-endpoint-disable`                                                     |
| `POST /slots/{id}?action=save\|restore\|erase` | Needs `--slot-save-path`                                                                                |
| `GET/POST /lora-adapters`                      | List and set LoRA adapter scales                                                                        |
| `GET /metrics`                                 | Prometheus, needs `--metrics`                                                                           |

```bash
curl -s http://127.0.0.1:8080/v1/models | jq -r '.data[].id'
curl -sN http://127.0.0.1:8080/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"my-model","stream":true,"messages":[{"role":"user","content":"hi"}]}'
```

## Request-level extras

llama.cpp-style fields (`top_k`, `min_p`, `mirostat`, `grammar`, `json_schema`, `cache_prompt`, `id_slot`, `n_probs`) and ik additions (`speculative.n_max`, `speculative.n_min`, `speculative.p_min`, `speculative.stages`, string ban, logit bias expiry) go in the JSON body; check the server README for field names.

## Errors

The server README documents error JSON (`code`, `message`, `type`). 401 means a missing or wrong key; 503 on `/health` means the model is still loading.
