# Together AI troubleshooting

> Verified against Together docs: Serverless rate limits, OpenAI compatibility, Manage endpoints and deployments (Troubleshooting), Migrate from v1, Deploy a fine-tuned model, Manage batch jobs, Structured outputs, 2026-10-11

| Symptom                                                                   | Cause                                                            | Fix                                                                                                       |
| ------------------------------------------------------------------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| 401                                                                       | Missing, wrong, revoked or expired key; key from another project | Check `TOGETHER_API_KEY` is set (names only: `env \| cut -d= -f1`), create a new key in the right project |
| 404 on a model such as `gpt-4o`                                           | OpenAI model names are not valid                                 | Use a namespaced ID from `GET /v1/models`                                                                 |
| `Unable to access non-serverless model`                                   | Model is only available dedicated                                | Deploy it with `tg beta endpoints deploy`                                                                 |
| 429 `Too Many Requests` (serverless)                                      | Burst or high demand                                             | Spread requests, exponential backoff; consider dedicated or provisioned throughput                        |
| 503 `Service Unavailable`                                                 | High demand                                                      | Retry with backoff                                                                                        |
| 429 `GPU quota exceeded` on deploy or update                              | Per-GPU-type quota for project or organization                   | Lower replicas, stop unused deployments, contact support                                                  |
| Deployment `DEGRADED`: `Cannot place replicas: insufficient GPU capacity` | Hardware constrained                                             | Wait (scheduler retries), fewer replicas or a smaller-footprint config                                    |
| Deployment `FAILED`: `Timed out waiting for readiness`                    | No replica provisioned in six hours                              | Read `status.message`; create a new deployment                                                            |
| `endpoint_not_configured` (400) while deployment is `READY`               | Deployment not in the traffic split with non-zero weight         | Add it to the split with a positive weight                                                                |
| 404 or wrong model on a dedicated call                                    | Wrong base URL or model string                                   | Use `https://api-inference.together.ai/v1` and `<project_slug>/<endpoint_name>`                           |
| `endpoints_v1_create_access_disabled` (403)                               | v1 create and restart are retired                                | Deploy on v2: `tg beta endpoints deploy`; upgrade to `together>=2.24.0`                                   |
| `unknown field "..."` (400) on management API                             | Body or query has a key the API does not define                  | Remove the named field (including retired keys such as `inactive_timeout`)                                |
| Restart fails: `the deployment is in a terminal FAILED state`             | `FAILED` is terminal                                             | Create a new deployment                                                                                   |
| Restart fails: `must be stopped before it can be restarted`               | Not yet `STOPPED`                                                | Wait for `DEPLOYMENT_STATE_STOPPED` or set both bounds to 0 first                                         |
| Delete fails: `stands in an endpoint's traffic split`                     | Still a member of the split (even at weight 0)                   | `tg beta endpoints rm dep_...` detaches automatically                                                     |
| Stop or delete disabled in the console                                    | Active rollout                                                   | Complete or cancel the rollout                                                                            |
| Deploy of a fine-tune: `Model not found` or `Multiple models found`       | Name not fully qualified, or ambiguous                           | Pass `model_object_name` with the project slug, or the `model_object_id`                                  |
| Scaling on `ttft` does not scale                                          | Non-streaming requests                                           | Send `stream: true` for `ttft`, `decoding_speed`, `throughput_per_replica`                                |
| Cached or reasoning token counts read `0`                                 | `usage` shape varies by model                                    | Read both nested `*_details` and flat `cached_tokens`                                                     |
| Structured output cut off                                                 | `finish_reason` is `length`                                      | Raise `max_tokens` or simplify the schema                                                                 |
| Batch line error `error reading input file`                               | A line over 10 MB (often inline base64)                          | Reference images by URL or compress                                                                       |
| Batch audio error `Content-Type must be multipart/form-data`              | Missing `"method": "FILE"`                                       | Add it to each line                                                                                       |
| Batch `COMPLETED` but results missing                                     | Per-request failures                                             | Read the error file via `error_file_id`                                                                   |
| Batch output gone                                                         | Files kept 7 days                                                | Download earlier next time                                                                                |
| API access stops unexpectedly                                             | Prepaid balance reached zero                                     | Add credits; consider auto-recharge with a card as default                                                |

If an error string is not here, search https://docs.together.ai with the exact text and check `tg <command> --help`.

## Sources

- https://docs.together.ai/docs/dedicated-endpoints/manage
- https://docs.together.ai/docs/dedicated-endpoints/migrate-from-v1
- https://docs.together.ai/docs/serverless/rate-limits
- https://docs.together.ai/docs/inference/batch/manage
