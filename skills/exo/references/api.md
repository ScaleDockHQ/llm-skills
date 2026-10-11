# exo: API

> Verified against exo v1.0.71 (source 0.3.70), 2026-10-11

Sources: `docs/api.md`, README "Using the API". Base URL `http://localhost:52415`. No authentication is documented.

## Instance lifecycle

```bash
B=http://localhost:52415
M=mlx-community/Llama-3.2-1B-Instruct-4bit
curl -fsS "$B/instance/previews?model_id=$M" | jq -c '.previews[] | select(.error == null) | .instance' | head -n1 > /tmp/exo-instance.json
curl -fsS -X POST $B/instance -H 'Content-Type: application/json' -d "{\"instance\": $(cat /tmp/exo-instance.json)}"
curl -N "$B/instance/await?model_id=$M&timeout_seconds=300"     # SSE: type ready or timeout
curl -fsS $B/state | jq '.instances'                              # find the instance id
curl -fsS -X DELETE $B/instance/<instance_id>
```

Other endpoints: `GET /node_id`, `GET /state`, `GET /events` (debug), `GET /instance/{id}`, `GET /instance/placement`, `POST /place_instance`. `/instance/await` returns HTTP 200 for both outcomes; read the `type` field. `timeout_seconds` 0 waits forever, maximum positive value 300.

## Inference

| Endpoint                                        | Format                                     |
| ----------------------------------------------- | ------------------------------------------ |
| `POST /v1/chat/completions`                     | OpenAI Chat Completions, streaming via SSE |
| `POST /v1/messages`                             | Claude Messages                            |
| `POST /v1/responses`                            | OpenAI Responses                           |
| `POST /ollama/api/chat`, `GET /ollama/api/tags` | Ollama                                     |
| `GET /v1/models`                                | alias of `/models`                         |

Chat parameters documented: `model`, `messages`, `stream`, `max_tokens`, `temperature`, `top_p`, `top_k`, `stop`, `seed`, `enable_thinking` (DeepSeek V3.1, Qwen3, GLM-4.7), `tools`, `logprobs`, `top_logprobs`. Non-streaming responses include `usage`.

```bash
curl -N -X POST $B/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"model":"'$M'","messages":[{"role":"user","content":"hi"}],"stream":true}'
```

A request for a model with no instance does not work: create and await an instance first.
