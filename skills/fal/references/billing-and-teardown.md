# fal billing, concurrency, retention and teardown

> Verified against fal.ai/docs model-apis/pricing, concurrency-limits, serverless/pricing, media-expiration, request-errors, 2026-10-11

Do not store rates. Look them up at call time.

## Price lookup

```bash
curl -sS "https://api.fal.ai/v1/models/pricing?endpoint_id=<model-id>" -H "Authorization: Key $FAL_KEY" | jq .
```

Model pages and the dashboard show the same data. Serverless machine prices are on the machine-types page and the dashboard.

## How billing works

| Product    | Billing                                                                                                                                                                                                                                        |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Model APIs | Per output unit (image, megapixel, video second, request) depending on the model. LLM routes are billed by tokens. 5xx responses and queue time are not charged                                                                                |
| Serverless | Per second by machine type while a runner is in SETUP, IDLE (including `keep_alive`), RUNNING, DRAINING or TERMINATING. Not charged in PENDING, DOCKER_PULL or TERMINATED. 5xx responses are not charged. Multi-GPU is GPU count times seconds |
| Credits    | Prepaid. Buy in the dashboard billing page                                                                                                                                                                                                     |

## Concurrency

- A new account starts with a small concurrent-request limit that rises with credit purchases up to a self-serve cap. Read yours on the dashboard Concurrency page (https://fal.ai/docs/documentation/model-apis/concurrency-limits has the current ladder).
- Going over returns 429 with type `concurrent_requests_limit` and `X-Fal-needs-retry: 1`. The official SDKs retry automatically. For raw HTTP, retry with backoff.

## Spend controls

1. Prepaid credit with a modest balance.
2. Keys with an expiry and an allowed-model list. Use separate keys per project so one can be revoked.
3. `max_concurrency` on every app, `min_concurrency 0` and a short `keep_alive`.
4. Gateway rate limits (`llm-gateway`) in front of client traffic.
5. Review usage and billing in the dashboard, or the Platform APIs (usage, analytics, billing) described at https://fal.ai/docs.

## Retention

- Request payloads: 30 days by default. `X-Fal-Store-IO: 0` disables storage.
- CDN media: governed by the expiration preference (`X-Fal-Object-Lifecycle-Preference`). A Platform API deletes payloads and outputs.
- Download outputs you keep. Do not rely on CDN URLs long term.

## Tear down

- [ ] `fal apps list` and note every app you created. Get approval for exact names.
- [ ] Remove the app from LiteLLM and client configs.
- [ ] Stop traffic first. Then `fal apps scale <app> --min-concurrency 0` (keep the app, no standing cost) or `fal apps delete <app>` (final). Delete old revisions with `fal apps delete-rev`.
- [ ] Check `fal apps runners <app>` is empty after a keep-alive period.
- [ ] fal Compute (GPU instances): list and delete instances with the Platform API if you created any. A `COMPUTE` key preset exists for this.
- [ ] Revoke temporary keys: dashboard keys page or the Platform API keys endpoints.
- [ ] Delete stored payloads and outputs for sensitive jobs through the Platform API.
- [ ] Verify: `fal apps list` shows only what you meant to keep, and the dashboard shows no running runners.

## Migrating in or out

fal publishes migration guides from Replicate, Baseten, Modal and RunPod: https://fal.ai/docs/documentation/development/migrating-to-fal. For moving off fal, the models you deployed are plain Python apps, so a Docker server is the simplest exit.
