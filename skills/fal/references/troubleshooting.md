# fal troubleshooting

> Verified against fal.ai/docs model-apis/request-errors, concurrency-limits, reliability, serverless/pricing, development/getting-started/installation, 2026-10-11

The error type is in the JSON `error_type` and the `X-Fal-Error-Type` header. Model validation errors come back with a `detail` array.

## Request error types

| `error_type`                                                                        | Meaning and first step                                                                                   |
| ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `request_timeout`                                                                   | The request ran past its limit. Use the queue, shorten the job, or raise the timeout on your app         |
| `startup_timeout`                                                                   | The runner did not start in time. Raise `startup_timeout`, trim image size, check `setup()`              |
| `runner_scheduling_failure`                                                         | No capacity for the machine type. Retry, try another machine type or region                              |
| `runner_connection_timeout`, `runner_connection_refused`, `runner_connection_error` | Network trouble to the runner. Retry, check the app is listening on the right port in Direct Server Mode |
| `runner_disconnected`, `runner_incomplete_response`                                 | The runner died mid-request. Look for OOM or a crash in logs                                             |
| `runner_server_error`                                                               | Your app raised an error. Read the app logs                                                              |
| `client_disconnected`, `client_cancelled`                                           | The caller went away or canceled                                                                         |
| `bad_request`                                                                       | Input did not validate. Compare with the model schema                                                    |
| `internal_error`                                                                    | fal side. Retry, then contact support with the request ID                                                |

5xx responses are not charged.

## Common situations

- **401 or 403:** wrong header form (use `Authorization: Key $FAL_KEY`), expired key, key preset without the needed scope, or a model not in the key's allowed list.
- **429 `concurrent_requests_limit`:** you hit your concurrency cap. SDKs retry. Raw callers need backoff, or buy credits to raise the limit.
- **HTTP 422 on your own app:** the endpoint parameter is not a Pydantic model.
- **Deploy refused:** serverless access is not approved for the account. Request it at https://fal.ai/dashboard/serverless-get-started.
- **First request slow:** a cold start with `min_concurrency 0`. Reduce image size, use warm runners, or accept it. See https://fal.ai/docs/documentation/serverless/optimizations/optimize-cold-starts.
- **Scale changed after deploy:** scale settings are inherited unless `--reset-scale`.
- **Surprise bill:** a high `keep_alive`, `min_concurrency` above zero, or a forgotten app. Run `fal apps list` and `fal apps runners <app>`.
- **Output link broke:** CDN media expired. Download results at completion.
- **Wrong model answered:** a model fallback kicked in. Set `x-app-fal-disable-fallback` where it matters.
- **CLI mix-up:** `fal` is the serverless CLI. `genmedia` is the model discovery and run CLI.

## Where to look

```bash
fal apps runners <app>
fal apps list-rev <app>
curl -sS "<status_url>?logs=1" -H "Authorization: Key $FAL_KEY"
```

Platform APIs also expose app logs, queue size and metrics (see https://fal.ai/docs). Never paste keys into tickets.
