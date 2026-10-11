# Anthropic API: troubleshooting

> Verified against Claude Platform docs: API errors, Rate limits, OpenAI SDK compatibility, Prompt caching, Message Batches, API and data retention, 2026-10-11

Error bodies look like `{"type":"error","error":{"type":"...","message":"..."},"request_id":"req_..."}`. Quote `request_id` when contacting support.

| Symptom                                                                                               | Cause                                                                            | Fix                                                                                                   |
| ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `401 authentication_error`                                                                            | Malformed, revoked or expired key; bad AWS credentials on Claude Platform on AWS | Check the key and its expiry; expired keys cannot be reactivated, create a new one                    |
| `403 permission_error`                                                                                | Key lacks access to the resource or workspace                                    | Check workspace membership and the `anthropic-workspace-id` header                                    |
| Multi-workspace key fails, single-workspace key works                                                 | Missing workspace header                                                         | Send `anthropic-workspace-id: wrkspc_...`                                                             |
| `402 billing_error`                                                                                   | Payment or billing problem                                                       | Fix payment details in the Console                                                                    |
| `404 not_found_error`                                                                                 | Wrong path, retired model or missing resource ID                                 | Re-list `/v1/models` (`lifecycle`); check IDs                                                         |
| `413 request_too_large`                                                                               | Over 32 MB (Messages), 256 MB (Batches) or 500 MB (Files)                        | Shrink the payload; use the Files API for large attachments                                           |
| `429 rate_limit_error` with `retry-after`                                                             | RPM, ITPM or OTPM limit, or acceleration limit                                   | Wait `retry-after`, ramp traffic gradually, cache prefixes, request a tier increase                   |
| `429` with `error_code: enforced_spend_limit_reached` and no `retry-after`                            | Tier monthly spend cap reached                                                   | SDK retries cannot fix it; move up a tier or wait until 00:00 UTC on the 1st                          |
| `400` "You have reached your specified API usage limits"                                              | A spend limit you set (org or workspace) was reached                             | Raise or remove the limit in Console > Billing or Workspaces                                          |
| `400` "...must have data retention enabled"                                                           | Covered Model needs 30-day retention                                             | Enable 30-day retention for the workspace or pick another model                                       |
| `400 invalid_request_error` for `thinking`                                                            | Wrong thinking type for the model (e.g. `enabled` on 4.7+ models)                | Omit `thinking` or use `adaptive`; check `capabilities.thinking.types` in `/v1/models`                |
| `400` on `temperature` or `top_p`                                                                     | 4.7+ models reject `temperature` below 1, non-default `top_p`, or both set       | Omit them                                                                                             |
| `400` on `tool_choice` any or named tool                                                              | Some models do not support forced tool use                                       | Use `auto`                                                                                            |
| `400` for top-level `cache_control`                                                                   | Legacy Bedrock integration (Opus 4.6 and earlier)                                | Use explicit block-level `cache_control`; also `400` if 4 explicit breakpoints exist or TTLs conflict |
| No cache hits and no error                                                                            | Prompt shorter than the model's minimum cacheable length, or prefix changed      | Check `usage.cache_creation_input_tokens` / `cache_read_input_tokens`; keep static content first      |
| HIPAA org gets `400` "...not available for HIPAA-regulated organizations without Zero Data Retention" | Non-eligible feature in the request                                              | Remove the feature (for example code execution)                                                       |
| `500 api_error`                                                                                       | Internal error                                                                   | Retry with exponential backoff; include `request_id` if persistent                                    |
| `504 timeout_error`                                                                                   | Long non-streaming request                                                       | Stream the response                                                                                   |
| `529 overloaded_error`                                                                                | API temporarily overloaded across all users                                      | Back off and retry; add a gateway fallback model                                                      |
| Stream ends with an `error` event after 200                                                           | Mid-stream error                                                                 | Handle `error` events; do not assume HTTP status covers it                                            |
| Batch results missing                                                                                 | Older than 29 days from `created_at`                                             | Resubmit; download results sooner                                                                     |
| OpenAI SDK output ignores schema                                                                      | `response_format` and `strict` are ignored by the compat layer                   | Use native `output_config.format` or strict tool use                                                  |
| Federated workload still uses a key                                                                   | `ANTHROPIC_API_KEY` set in the environment overrides federation                  | Unset it; check `ant auth status`                                                                     |

## Quick diagnostics

```bash
curl -sS https://api.anthropic.com/v1/models -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" | jq '.error // (.data | length)'
```

## Where to read more

- https://platform.claude.com/docs/en/api/errors
- https://platform.claude.com/docs/en/api/rate-limits
