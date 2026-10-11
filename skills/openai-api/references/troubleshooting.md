# OpenAI API: troubleshooting

> Verified against OpenAI docs: Rate limits, Spend limits, Batch API, Your data, Structured outputs, Prompt caching, Streaming API responses, 2026-10-11

Check the HTTP status **and** `error.code` in the JSON body; several conditions share a status.

| Symptom                                        | Cause                                                                 | Fix                                                                                                 |
| ---------------------------------------------- | --------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `401` on any call                              | Missing, wrong, expired or revoked key                                | Re-export the key; check expiry and revocation; verify with `GET /v1/models`                        |
| `429` code `slow_down`                         | Request rate rose too quickly (even under RPM/TPM)                    | Follow `Retry-After`, drop the rate, ramp up (about +50% per 15 min above ~1M TPM)                  |
| `429` rate_limit_error on RPM/TPM              | Org or project limit hit                                              | Read `x-ratelimit-*` headers; lower `max_output_tokens`; Batch; request higher tier                 |
| `503` code `server_is_overloaded`              | Model temporarily overloaded                                          | Retry after `Retry-After` with backoff and jitter; add a fallback model in the gateway              |
| `429` code `organization_spend_limit_exceeded` | Org hard spend limit reached                                          | Raise or remove the limit, or wait for the monthly reset                                            |
| `429` code `project_spend_limit_exceeded`      | Project hard spend limit reached                                      | Raise the project limit or use another project                                                      |
| `429` code `organization_usage_limit_exceeded` | OpenAI-approved monthly usage limit reached                           | Request a higher approved limit                                                                     |
| `429` code `credit_balance_exhausted`          | Prepaid credits used up                                               | Add credits                                                                                         |
| Retries make it worse                          | Failed requests still count toward per-minute limits                  | Cap attempts; honor `Retry-After`; do not retry quota or billing errors                             |
| `413` on `POST /v1/responses` with `zstd`      | Body over 128 MiB or decompression ratio over 100x                    | Shrink the body or send uncompressed; invalid zstd data returns `400`                               |
| Batch `failed` at validation                   | Bad JSONL, mixed models in one file, unsupported endpoint             | One model per file; unique `custom_id`; endpoints from the Batch guide                              |
| Batch `expired`; error lines `batch_expired`   | Not finished within 24h                                               | Resubmit unfinished `custom_id`s; split into smaller batches; completed ones were billed            |
| Batch output order differs from input          | Order is not preserved                                                | Join on `custom_id`                                                                                 |
| Structured output rejected or `refusal`        | Schema not strict-compatible, or model refused                        | `additionalProperties: false`, all fields `required`; handle refusals; check model support          |
| Low cache hit rate                             | Prefix changed (tools, `text.format`, effort) or prompt under minimum | Put static content first; keep tools and schema stable; check the Prompt Cache Diagnostics          |
| `store` ignored; stored objects missing        | ZDR enabled forces `store=false`                                      | Expected; keep state client-side                                                                    |
| Parsing `output[0].content[0].text` fails      | `output` can include tool-call and reasoning items                    | Use SDK `output_text` or filter `type == "message"`                                                 |
| Model not found / shutdown                     | Alias retired or `shutdown_date` passed                               | Re-list `/v1/models`; pin a supported snapshot; migrate (`gpt-3.5-turbo-instruct` ended 2026-09-28) |
| Stream stops with an `error` event             | Error after the stream began                                          | Do not auto-replay after consuming output; retry only if the output can be discarded                |
| LiteLLM `AuthenticationError`                  | Env var not exported in the proxy's environment                       | Export `OPENAI_API_KEY` where `litellm` runs; reference it as `os.environ/OPENAI_API_KEY`           |

## Quick diagnostics

```bash
# Is the key valid and are the expected models visible?
curl -sS -o /dev/null -w '%{http_code}\n' https://api.openai.com/v1/models -H "Authorization: Bearer $OPENAI_API_KEY"
# Print the error body of a failing call without the key
curl -sS https://api.openai.com/v1/responses -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" -d "$(jq -n --arg m "$OPENAI_MODEL" '{model:$m,input:"hi",max_output_tokens:16}')" | jq '.error'
```

## Where to read more

- https://developers.openai.com/api/docs/guides/rate-limits
- https://developers.openai.com/api/docs/guides/spend-limits
