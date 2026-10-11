# fal Model APIs: queue, sync, webhooks

> Verified against fal.ai/docs model-apis/overview, model-apis/inference/queue, reliability, media-expiration, request-errors, use-llms example, 2026-10-11

Endpoint IDs look like `fal-ai/<name>` or `<org>/<name>`. Every model page shows its input schema and example. `genmedia schema <endpoint>` prints it.

## Hosts

| Mode        | URL                                | Use                                           |
| ----------- | ---------------------------------- | --------------------------------------------- |
| Queue       | `https://queue.fal.run/<model-id>` | Default. Reliable, retried, supports webhooks |
| Direct sync | `https://fal.run/<model-id>`       | Fast models, short jobs                       |
| WebSocket   | model dependent                    | Realtime models                               |

Backup domains `falrun.com` and `queue.falrun.com` exist.

## Queue flow

```bash
RESP=$(curl -sS -X POST "https://queue.fal.run/<model-id>" \
  -H "Authorization: Key $FAL_KEY" -H "Content-Type: application/json" \
  -d '{"prompt":"a red cube"}')
echo "$RESP" | jq '{request_id, status_url, response_url, cancel_url}'
curl -sS "$(echo "$RESP" | jq -r .status_url)?logs=1" -H "Authorization: Key $FAL_KEY" | jq .
curl -sS "$(echo "$RESP" | jq -r .response_url)" -H "Authorization: Key $FAL_KEY" | jq .
```

- Status values: `IN_QUEUE`, `IN_PROGRESS`, `COMPLETED`. `GET .../requests/{id}/status/stream` streams status.
- Cancel: `PUT .../requests/{id}/cancel`. Answers: 202 `CANCELLATION_REQUESTED`, 400 `ALREADY_COMPLETED`, 404 `NOT_FOUND`.
- Python: `fal_client.subscribe("<model-id>", arguments={...})` blocks and returns the result. `submit` returns a handle.

## Webhooks

Add `?fal_webhook=<https-url>` to the submit URL (or the client's `webhook_url`). The payload carries `request_id`, `gateway_request_id`, `status` (`OK` or `ERROR`) and `payload`. Use an HTTPS endpoint that tolerates retries. Verification instructions are on the webhooks page of the docs: unverified here, check https://fal.ai/docs before trusting an inbound call.

## Request headers

- `X-Fal-Request-Start-Timeout`: how long a request may wait to start.
- `X-Fal-Runner-Hint`: route to a specific runner.
- `X-Fal-Queue-Priority`: `normal` or `low`.
- `X-Fal-No-Retry`: turn off automatic retries.
- `X-Fal-Store-IO: 0`: do not store request payloads.
- `X-Fal-Object-Lifecycle-Preference`: JSON such as `{"expiration_duration_seconds": 3600}` (or `null`) to set media expiry.
- `x-app-fal-disable-fallback`: skip model fallbacks that some endpoints have.

## Retries and reliability

The queue retries up to 10 times on 503, 504, connection errors and 429. Some models have fallbacks to another endpoint. Both can change latency and which model produced output, so disable them where reproducibility matters.

## Retention

Request payloads are kept for 30 days by default. Generated media on the CDN follows the expiration preference. A Platform API can delete payloads and outputs. Send `X-Fal-Store-IO: 0` and an expiry for sensitive inputs. Download outputs you need to keep.

## LLM-style endpoints

- OpenAI-compatible: `https://fal.run/openrouter/router/openai/v1` with `/chat/completions`. It is served by OpenRouter and billed by tokens. Details in `references/litellm-and-llms.md`.
- Simple: the `fal-ai/any-llm` endpoint takes `{prompt, model}`.
- The tutorial's model IDs looked stale on 2026-10-11. Confirm the available model names on the endpoint's page before use.

## Platform APIs

`https://api.fal.ai/v1/...` covers model pricing, usage, analytics, billing, API keys (list, create, delete) and serverless apps, logs and metrics. Browse https://fal.ai/docs for the current paths.

## Verify

- [ ] A queue submit returns a `request_id`.
- [ ] The response retrieval returns data after `COMPLETED`.
- [ ] Cancel works on a long request.
