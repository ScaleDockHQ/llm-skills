# NVIDIA NIM API

> Verified against NIM LLM 2.0.13, 2026-10-11

Sources: API reference and Claude Code integration pages.

## Endpoints

| Method and path                                                   | Purpose                               |
| ----------------------------------------------------------------- | ------------------------------------- |
| `GET /v1/health/live`, `GET /v1/health/ready`                     | Liveness and readiness                |
| `GET /v1/models`                                                  | Served model (and LoRA adapter) ids   |
| `GET /v1/version`, `/v1/metadata`, `/v1/manifest`, `/v1/license`  | Build, model and licence info         |
| `GET /v1/metrics`                                                 | Prometheus metrics (vLLM native)      |
| `POST /v1/chat/completions`, `/v1/completions`                    | OpenAI chat and completion            |
| `POST /v1/responses`, `GET /v1/responses/{id}`, `POST .../cancel` | OpenAI Responses API                  |
| `POST /v1/messages`, `/v1/messages/count_tokens`                  | Anthropic-compatible Messages         |
| `POST /v1/embeddings`                                             | Embeddings (embedding-capable models) |
| `POST /tokenize`, `/detokenize`                                   | Tokenizer utilities                   |
| `POST /v1/chat/completions/render`, `/v1/completions/render`      | Render prompt without generating      |
| `POST /generative_scoring`, `/inference/v1/generate`              | Scoring and raw generate              |

Which endpoints respond depends on the model and backend; read `/v1/models` and the API reference page.

## Calling

```bash
MODEL=$(curl -s http://127.0.0.1:8000/v1/models | jq -r '.data[0].id')
curl -s http://127.0.0.1:8000/v1/chat/completions -H 'Content-Type: application/json' \
  -d "$(jq -n --arg m "$MODEL" '{model:$m,messages:[{role:"user",content:"Hello"}],max_tokens:64}')"
```

## Authentication

No API-key setting for `/v1` is documented. For the Anthropic endpoint, NIM does not validate
`x-api-key`; clients set any non-empty placeholder. Enforce auth in a gateway (`litellm`, `llm-gateway`
skills) or a reverse proxy.

## Anthropic clients

```bash
export ANTHROPIC_BASE_URL="http://<host>:8000"
export ANTHROPIC_API_KEY="not-used"
export ANTHROPIC_CUSTOM_MODEL_OPTION="<id from /v1/models>"
```

The model must support tool calling for agentic clients such as Claude Code.

## Limits

Set `max_tokens` (completions and chat) or `max_output_tokens` (responses) to bound output; they are
output limits, not time limits. Streaming tool-call deltas must be assembled before validating.
