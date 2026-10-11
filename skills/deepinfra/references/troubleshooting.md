# DeepInfra troubleshooting

> Verified against DeepInfra docs (Rate Limits, Authentication, Quickstart, Custom LLMs, GPU Instances, Batch API, Anthropic integration), 2026-10-11

| Symptom                                           | Likely cause                                                    | Fix                                                                                        |
| ------------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| 401 or invalid token                              | Deleted or mistyped key; expired scoped JWT; wrong base URL.    | New key; check `[ -n "$DEEPINFRA_API_KEY" ]`; base `https://api.deepinfra.com/v1/openai`.  |
| Key rejected after setting its monthly limit to 0 | `0` blocks the key.                                             | Set a positive limit, or `null` to remove (`limits-and-spend.md`).                         |
| Scoped JWT rejected                               | Model not in its list, expired, or over its `spending_limit`.   | Issue a new JWT with the right model, expiry and cap.                                      |
| 429 `Rate limited`                                | Over 200 concurrent requests for a model, or model very busy.   | Retry after a short delay; cap concurrency; request an increase in Dashboard, Account.     |
| 402 on deployment create                          | Payment required.                                               | Add funds or fix the payment method (ask the user).                                        |
| 409 on key or deployment create                   | Name conflict.                                                  | Use a different name.                                                                      |
| Model not found                                   | Undated or retired slug; deployment name missing your username. | List `/v1/openai/models`; deployments are `YOUR_GITHUB_USERNAME/name` or `deploy_id:<id>`. |
| Deployment `status` not `deployed`                | GPU not available, bad weights, init failure (`fail_reason`).   | `GET /deploy/{id}`; check `deploy/llm/gpu_availability`; try another GPU or fewer GPUs.    |
| First call on a private model is slow or errors   | Scaled to zero or still starting.                               | Keep `min_instances` at 1 during use; retry after warm-up.                                 |
| Unexpected bill                                   | Deployment or container left running.                           | List `/deploy/list` and `/v1/containers`; stop or delete; set limits.                      |
| Container never reaches `running`                 | Capacity or bad cloud-init.                                     | Describe the container; delete and recreate with another config.                           |
| Cannot SSH into container                         | Wrong key or user.                                              | Use `ubuntu@<ip>` and the public key you put in cloud-init.                                |
| Batch line fails validation                       | Mixed endpoints or models, duplicate `custom_id`, non-POST.     | One endpoint and model per file; unique ids.                                               |
| Batch rejected for endpoint                       | Endpoint not supported (images, responses, videos).             | Use chat, completions or embeddings.                                                       |
| Claude Code 404 on messages                       | Base URL has `/v1`.                                             | `ANTHROPIC_BASE_URL=https://api.deepinfra.com/anthropic`.                                  |
| Anthropic request ignores a Claude model name     | Needs a DeepInfra slug.                                         | Use slugs, not `claude-*` names.                                                           |
| LiteLLM cannot find model                         | Missing `deepinfra/` prefix or old model name.                  | `deepinfra/<org>/<slug>` from the live list.                                               |

Report: request ID and model slug. Logs contain metadata only (request ID, cost, sampling parameters), so content cannot be recovered by support.
