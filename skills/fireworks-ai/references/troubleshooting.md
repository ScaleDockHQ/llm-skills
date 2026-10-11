# Fireworks AI troubleshooting

> Verified against Fireworks docs: Serverless Rate Limits, Account quotas, Deployments Quickstart and guide, Autoscaling, Tool Calling troubleshooting, Structured Outputs, Batch API, 2026-10-11

| Symptom                                              | Cause                                                                        | Fix                                                                                                                     |
| ---------------------------------------------------- | ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| 401 Unauthorized                                     | Wrong, expired or deleted key                                                | Check variable names with `env \| cut -d= -f1`; create a key with `firectl api-key create`                              |
| 429 on serverless                                    | Exceeded adaptive TPM or account request limit; traffic ramped too fast      | Ramp gradually, back off, check `firectl quota list` and the Serverless dashboard; higher spending tier raises ceilings |
| 503 Service Overloaded on serverless                 | Load shedding                                                                | Retry with backoff; use `service_tier: "priority"` on supported models                                                  |
| 429 on an on-demand deployment                       | Deployment saturation, not TPM tier                                          | Raise `--max-replica-count` or lower load target; request still counts against the account request limit                |
| 503 right after idle on a deployment                 | Scaled to zero and starting                                                  | Retry with backoff; keep `--min-replica-count 1` for latency-sensitive traffic                                          |
| All API calls blocked                                | Monthly spend limit reached (100%) or credits depleted or payment problem    | Raise `monthly-spend-usd`, add credits, check account status                                                            |
| `firectl deployment create` fails with a shape error | Old `firectl`: `default` treated as a literal name                           | `firectl version`; upgrade to 1.8.8 or newer                                                                            |
| Deployment creation fails or stalls without a shape  | Shapeless deployment                                                         | Pass `--deployment-shape default` or a matched shape                                                                    |
| Deployment fails on GPU quota                        | Per-GPU-type, per-placement quota                                            | `firectl quota list`; use another placement or request quota                                                            |
| `--preemptible` had no effect                        | `firectl` older than 1.7.26 ignores it silently                              | Upgrade and recreate (the flag is immutable)                                                                            |
| Deployment disappeared after a week                  | Auto-deleted after 7 days of no traffic with min replicas 0                  | Recreate; `firectl deployment undelete` if still soft-deleted                                                           |
| Tool call not produced                               | Model not calling tools                                                      | `tool_choice="required"`, simpler schema, check model supports tools                                                    |
| 400 on tool or response schema with `$ref`           | External `$ref` URI, or old deployment image for recursive or nested `$defs` | Use in-document `#/...` pointers; redeploy on a current image                                                           |
| JSON never ends or whitespace flood                  | Prompt did not ask for JSON                                                  | Say "respond in JSON" and include the schema in the prompt                                                              |
| Truncated invalid JSON                               | `finish_reason="length"`                                                     | Raise `max_tokens`                                                                                                      |
| No reasoning output with `json_schema`               | `response_format` json_schema disables reasoning                             | Put the schema in the prompt and omit `response_format`                                                                 |
| Batch job stays pending                              | Model not batch-compatible, job waiting for the window, or capacity          | Verify model support, check JSONL, wait; contact support after 30 minutes "creating"                                    |
| Training job 403 `quota_exceeded` or `tier_required` | No payment method or no free GPUs of that type                               | Add a payment method, free GPUs, resubmit                                                                               |
| Model not found                                      | Wrong ID format                                                              | Use `accounts/fireworks/models/<name>`; list from Model Library or the models API                                       |

If an error is not here, search https://docs.fireworks.ai with the exact text and run `firectl <command> --help`.

## Sources

- https://docs.fireworks.ai/serverless/rate-limits
- https://docs.fireworks.ai/guides/quotas_usage/account-quotas
- https://docs.fireworks.ai/guides/ondemand-deployments
- https://docs.fireworks.ai/deployments/autoscaling
- https://docs.fireworks.ai/guides/function-calling
