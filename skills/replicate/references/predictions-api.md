# Replicate predictions API

> Verified against replicate.com/docs reference/http, topics/predictions (create-a-prediction, lifecycle, streaming, input-files, verify-webhook, data-retention), 2026-10-11

All paths are under `https://api.replicate.com/v1`. Header: `Authorization: Bearer $REPLICATE_API_TOKEN`.

## Create a prediction

| Target                          | Endpoint                                                                                                                 |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Community model, pinned version | `POST /predictions` with `{"version": "<64-char version id>", "input": {...}}` (the client form is `owner/name:version`) |
| Official model                  | `POST /models/{owner}/{name}/predictions` (no version needed)                                                            |
| Deployment                      | `POST /deployments/{owner}/{name}/predictions`                                                                           |

```bash
curl -sS -X POST https://api.replicate.com/v1/models/<owner>/<name>/predictions \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" -H "Content-Type: application/json" \
  -H "Prefer: wait=30" -H "Cancel-After: 120s" \
  -d '{"input":{"prompt":"hello"}}' | jq '{id, status, output}'
```

Input fields come from the model's schema: `GET /models/{owner}/{name}` or its page.

## Headers

- `Prefer: wait` or `Prefer: wait=<seconds>` holds the request open for a synchronous result (1 to 60 s).
- `Cancel-After`: from 5 seconds to 24 hours. A prediction aborted before starting is not charged. A canceled one is billed for the time it ran. Use it as a cost cap.

## Body options

- `webhook` (an HTTPS URL, redirects are not followed, handlers must tolerate retries) and `webhook_events_filter` from `start`, `output`, `logs`, `completed`. Output and logs events are throttled to one per 500 ms.
- `stream` in the body is deprecated. A streaming model returns `urls.stream`, an SSE source with `output`, `error` and `done` events.

## Lifecycle

Statuses: `starting`, `processing`, `succeeded`, `failed`, `canceled`, `aborted`. A prediction times out after 30 minutes.

```bash
curl -sS https://api.replicate.com/v1/predictions/$ID -H "Authorization: Bearer $REPLICATE_API_TOKEN" | jq '{status, error, output}'
curl -sS -X POST https://api.replicate.com/v1/predictions/$ID/cancel -H "Authorization: Bearer $REPLICATE_API_TOKEN"
```

`GET /predictions` lists recent predictions.

## Files

- Input: a public HTTP URL, a data URL for small files (the HTTP reference says 256 kB or less, and the data is not stored). Use an HTTP URL for larger files or ones you reuse, or a local file via a client (up to 100 MB).
- Output files are `FileOutput` objects in the clients and URLs in HTTP. They expire with the retention policy.

## Retention

Inputs, outputs, files and logs of predictions made through the API are deleted after one hour by default. Predictions made in the web UI are kept. Download what you need immediately. Check the data-retention page before sending sensitive inputs.

## Verify a webhook

Headers: `webhook-id`, `webhook-timestamp`, `webhook-signature`. Compute HMAC-SHA256 over `${webhook-id}.${webhook-timestamp}.${raw body}` with the secret from `GET /webhooks/default/secret` (key starts `whsec_`, use the part after the prefix per the docs), compare with a constant-time check, and reject stale timestamps. Never log the secret.

## Other endpoints

`GET /models`, `GET /models/{owner}/{name}`, `GET /search` (beta), `GET /hardware` (hardware SKU list), `POST /trainings`, `GET /account`.

## Rate limits

Create-prediction: 600 per minute. Other endpoints: 3000 per minute. A 429 body reads like `{"detail":"Request was throttled. Expected available in 1 second."}`. Back off and retry. Throttling is stricter when the balance is near zero, and accounts with granted credit but no payment method are limited to a very low rate. Check https://replicate.com/docs/topics/predictions/rate-limits for current numbers.

## Cold boots

Public models share capacity. A model that nobody has run recently boots from cold. That can take minutes (LiteLLM notes 3 to 5 minutes for some). Use `Prefer: wait` plus a webhook or polling, and a gateway timeout to match, or use a deployment with `min_instances >= 1`.
