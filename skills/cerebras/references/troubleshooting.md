# Cerebras troubleshooting

> Verified against Cerebras Inference docs (Error Codes, Rate Limits, OpenAI Compatibility, Structured Outputs, Deprecations, Console Logs), 2026-10-11

| Symptom                                             | Likely cause                                                                                             | Fix                                                                                                  |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `401 Unauthorized` / `AuthenticationError`          | Key deleted, mistyped, wrong environment variable, or sent to the wrong base URL.                        | Create a new key; check `[ -n "$CEREBRAS_API_KEY" ]`; base URL must be `https://api.cerebras.ai/v1`. |
| `402 Payment required`                              | Free-trial credits expired, no payment method, or credits used up.                                       | Add a payment method or credits in Billing (ask the user first).                                     |
| `403 PermissionDenied`                              | Key's project or org lacks access to the model or feature (Dedicated, Batch).                            | Check Projects and model access; Batch and tiers are private preview.                                |
| `404 NotFound` for a model                          | Retired or misspelled ID, or a Dedicated-only model.                                                     | `GET /v1/models`; read the Deprecations page; update the config.                                     |
| `429` mentioning uncached or total tokens           | Dual-bucket token limit; large `max_completion_tokens`; cold cache.                                      | Lower `max_completion_tokens`; stabilize prefixes; project or org limit increase; see limits file.   |
| `429` after both projects look fine                 | Org-level ceiling shared across projects.                                                                | Look at All projects in Console, Limits; reduce project quotas so the sum fits.                      |
| `400` on `n > 1`                                    | Only `n: 1` supported.                                                                                   | Send several requests.                                                                               |
| `400 HTTPS image URLs are not supported`            | Image passed as URL.                                                                                     | Send a base64 data URI (PNG or JPEG).                                                                |
| `413` with image dimensions                         | Image over 15000 px per side.                                                                            | Resize before sending.                                                                               |
| `400` with `tools` and `response_format` on gpt-oss | Unsupported combination.                                                                                 | Two requests: tools first, structured output second.                                                 |
| `400` on a strict JSON schema                       | Unsupported keyword (`oneOf`, `pattern`, `$ref`, `minItems`...) or missing `additionalProperties:false`. | Simplify per `models-and-features.md`.                                                               |
| `422 UnprocessableEntity`                           | Valid JSON, invalid parameter values.                                                                    | Compare with the Chat Completions reference.                                                         |
| `503 ServiceUnavailable` or `500`                   | Capacity or server issue.                                                                                | Retry with backoff; fall back to another provider in the gateway.                                    |
| Request times out                                   | SDK default timeout is one minute.                                                                       | Raise `timeout`; use streaming; cut `max_completion_tokens`.                                         |
| Output differs after a model swap                   | Different weights, reasoning defaults.                                                                   | Rerun evals (`llm-evals`); set `reasoning_effort` explicitly.                                        |
| Costs higher than expected                          | Reasoning tokens counted as output; cache misses.                                                        | Analytics, Cost and Cached-Usage tabs; lower reasoning effort; stable prefixes.                      |

## Collect evidence for support

Console, Logs: filter by key and status code and copy the Request ID. Do not paste keys. Include the model ID, timestamp (UTC) and the error body.
