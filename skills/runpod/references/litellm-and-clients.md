# Runpod endpoints: calling them, LiteLLM and clients

> Verified against docs.runpod.io serverless/endpoints/send-requests, serverless/vllm/vllm-requests, serverless/load-balancing/overview, runpod-workers/worker-vllm v2.29.0 README, LiteLLM `openai/` and `hosted_vllm/` provider docs as used by the `litellm` skill, 2026-10-11

All calls use `Authorization: Bearer $RUNPOD_API_KEY`. Prefer a Restricted key scoped to the endpoint. Never put the key in a prompt, URL or log.

## OpenAI-compatible routes (worker-vllm)

Base URL: `https://api.runpod.ai/v2/<ENDPOINT_ID>/openai/v1`

| Route                    | Notes                                                                  |
| ------------------------ | ---------------------------------------------------------------------- |
| `POST /chat/completions` | Streaming with `"stream": true`                                        |
| `POST /completions`      | Text completions                                                       |
| `GET /models`            | Lists the served model name                                            |
| `POST /responses`        | OpenAI Responses API                                                   |
| `POST /messages`         | Anthropic Messages API, usable by Anthropic clients with this base URL |

The `model` value must equal `MODEL_NAME`, or `OPENAI_SERVED_MODEL_NAME_OVERRIDE` when set.

```bash
export RUNPOD_API_KEY="$(cat ~/.config/runpod/api-key)"
curl -s "https://api.runpod.ai/v2/$ENDPOINT_ID/openai/v1/chat/completions" \
  -H "Authorization: Bearer $RUNPOD_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"Qwen/Qwen3-8B","messages":[{"role":"user","content":"Say hi"}],"max_tokens":32}' | jq -r '.choices[0].message.content'
```

```python
import os
from openai import OpenAI

client = OpenAI(
    base_url=f"https://api.runpod.ai/v2/{os.environ['ENDPOINT_ID']}/openai/v1",
    api_key=os.environ["RUNPOD_API_KEY"],
)
print(client.chat.completions.create(model="Qwen/Qwen3-8B", messages=[{"role": "user", "content": "Say hi"}], max_tokens=32).choices[0].message.content)
```

The first request after idle waits for a cold start (worker boot plus model load). Use a client timeout of several minutes for the first call, or keep one active worker.

## Native queue API

| Call                    | Purpose                                                   |
| ----------------------- | --------------------------------------------------------- |
| `POST /run`             | Async job, returns `{"id", "status"}`; result kept 30 min |
| `POST /runsync`         | Waits for the result; result kept 1 min                   |
| `GET /status/<job-id>`  | Poll job state                                            |
| `GET /stream/<job-id>`  | Stream partial outputs                                    |
| `POST /cancel/<job-id>` | Cancel a job                                              |
| `POST /retry/<job-id>`  | Retry a failed or timed-out job                           |
| `POST /purge-queue`     | Drop all queued jobs (destructive)                        |
| `GET /health`           | Worker and job counts                                     |

Input is always `{"input": {...}}`. For worker-vllm: `{"input":{"prompt":"...","sampling_params":{"max_tokens":64}}}` or `{"input":{"messages":[...]}}`.

```bash
curl -s -X POST "https://api.runpod.ai/v2/$ENDPOINT_ID/run" -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -H "Content-Type: application/json" -d '{"input":{"prompt":"Say hi","sampling_params":{"max_tokens":32}}}'
curl -s "https://api.runpod.ai/v2/$ENDPOINT_ID/health" -H "Authorization: Bearer $RUNPOD_API_KEY" | jq
```

Job states include `IN_QUEUE`, `IN_PROGRESS`, `COMPLETED`, `FAILED`, `CANCELLED`, `TIMED_OUT`. Use `/run` plus polling for anything that may exceed a minute.

## Rate limits (per endpoint, per user)

| Route       | Requests per 10 s | Concurrent |
| ----------- | ----------------- | ---------- |
| `/runsync`  | 2000              | 400        |
| `/run`      | 1000              | 200        |
| `/openai/*` | 2000              | 400        |

Exceeding them returns `429`. The limits scale with the number of workers. Retry with exponential backoff and jitter; `Retry-After` handling is unverified.

## Load-balancing endpoint calls

`https://<ENDPOINT_ID>.api.runpod.ai/<your-path>` forwards to your server, for vLLM `/v1/chat/completions`, `/v1/models`, `/health`. During cold start you get a "no workers available" error, so wrap calls in a retry loop (for example up to 5 minutes with 5-second backoff).

## Deploying from code or API

Use `runpodctl` (see `serverless-vllm.md`) for most agent work. For programmatic provisioning use REST API v2 (`https://api.runpod.io/v2`, spec at `/v2/openapi.json`), not deprecated v1 or GraphQL. Read the spec for the exact payloads; this skill does not hardcode them.

Runpod has no dedicated LiteLLM provider prefix. Treat every Runpod LLM endpoint as an OpenAI-compatible server and use `openai/<served-model-name>` (or `hosted_vllm/<served-model-name>`) with an explicit `api_base`. Gateway design belongs to the `llm-gateway` and `litellm` skills.

## LiteLLM: Serverless (worker-vllm)

```yaml
model_list:
  - model_name: qwen3-8b # the name your clients send to the gateway
    litellm_params:
      model: openai/Qwen/Qwen3-8B # openai/ + MODEL_NAME (or OPENAI_SERVED_MODEL_NAME_OVERRIDE)
      api_base: https://api.runpod.ai/v2/<ENDPOINT_ID>/openai/v1
      api_key: os.environ/RUNPOD_API_KEY
      timeout: 600 # cold start plus load; raise for first calls
      num_retries: 2
```

Why these values:

- The path ends in `/openai/v1`; LiteLLM appends `/chat/completions`.
- `model` after the prefix is the name vLLM serves, not the Runpod endpoint id. Set `OPENAI_SERVED_MODEL_NAME_OVERRIDE` on the endpoint to get a short stable name.
- With scale-to-zero, the first request waits for a worker. Give the gateway a long `timeout`, and add a fallback to another model so interactive clients do not hang.

## LiteLLM: Load-balancing endpoint

```yaml
- model_name: qwen3-8b-lb
  litellm_params:
    model: hosted_vllm/Qwen/Qwen3-8B
    api_base: https://<ENDPOINT_ID>.api.runpod.ai/v1
    api_key: os.environ/RUNPOD_API_KEY
    num_retries: 5 # "no workers available" appears during cold start
```

If vLLM itself runs with `--api-key`, the endpoint needs the Runpod key at the edge and the vLLM key inside; the single `Authorization` header cannot carry both. Leave vLLM without `--api-key` on load-balancing endpoints (Runpod's API key already guards the URL), or confirm how headers are forwarded with a test call.

## LiteLLM: Pod behind the proxy URL

```yaml
- model_name: qwen3-8b-pod
  litellm_params:
    model: hosted_vllm/Qwen/Qwen3-8B
    api_base: https://<POD_ID>-8000.proxy.runpod.ai/v1
    api_key: os.environ/POD_VLLM_API_KEY # the key you passed to `vllm serve --api-key`
```

Pod IDs change on every new Pod, so update the gateway when you redeploy.

## LiteLLM: hybrid with a local model

Keep latency-sensitive traffic on a local engine and send overflow or large models to Runpod:

```yaml
router_settings:
  fallbacks: [{ "qwen3-8b-local": ["qwen3-8b"] }]
```

The full hybrid example is the `cloud-llms` skill's `assets/litellm-hybrid.yaml`; start from it and replace the Runpod block with the one above.

## Other OpenAI-compatible clients

```bash
export OPENAI_BASE_URL="https://api.runpod.ai/v2/$ENDPOINT_ID/openai/v1"
export OPENAI_API_KEY="$RUNPOD_API_KEY"
```

Most OpenAI-compatible tools (Open WebUI, Continue, Cline, aider) accept that base URL and key. Set the model name to the served name. For Anthropic-style clients the same worker answers `POST .../openai/v1/messages`.

Streaming, tool calls and structured outputs depend on the vLLM flags set on the endpoint (`ENABLE_AUTO_TOOL_CHOICE`, `TOOL_CALL_PARSER`). Test them with a real request before wiring clients.
