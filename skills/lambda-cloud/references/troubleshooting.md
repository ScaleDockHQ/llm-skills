# Lambda Cloud: troubleshooting

> Verified against Lambda Cloud API docs (error codes, spec 1.10.0), On-Demand Cloud overview, Cloud Console and creating and managing instances pages, plus the Lambda community notice on the Inference API sunset (deeptalk.lambda.ai), 2026-10-11

| Symptom or error code                                            | Likely cause                                                                         | Fix                                                                                                      |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| 401 `global/invalid-api-key`                                     | Key missing, wrong, or deleted                                                       | Regenerate in the console, update the `0600` file; use `Authorization: Bearer`                           |
| 403 `global/account-inactive` or `global/invalid-address`        | Account or billing address problem                                                   | Fix account and billing details in the console, then retry                                               |
| 429 `global/rate-limited`                                        | Over about 1 request per second, or launch more than once per 12 s                   | Sleep and retry with backoff                                                                             |
| 400 `instance-operations/launch/insufficient-capacity`           | No capacity for that type in that region                                             | Re-read `/instance-types` for `regions_with_capacity_available`; try another region or type; retry later |
| 400 `global/quota-exceeded`                                      | Account launch quota reached                                                         | Terminate unused instances; the quota grows as invoices are paid; ask support to raise it                |
| 400 `instance-operations/launch/file-system-in-wrong-region`     | Filesystem and instance regions differ                                               | Create or choose a filesystem in the instance region                                                     |
| 400 `global/invalid-parameters`                                  | Bad body, for example more than one `ssh_key_names` entry, bad hostname or tag regex | Fix per the schema; one SSH key name only                                                                |
| 404 `global/object-does-not-exist`                               | Wrong instance, key or filesystem id                                                 | List first, copy ids exactly                                                                             |
| `provider/internal-unavailable`                                  | Upstream provider outage                                                             | Retry shortly                                                                                            |
| Cannot reach the model port                                      | Only TCP 22 is open by default                                                       | Attach a firewall ruleset or use an SSH tunnel                                                           |
| Filesystem not mounted                                           | It was not attached at launch, or is in another region or workspace                  | Terminate and relaunch with it attached; attach after launch is impossible                               |
| Instance in Alert status, still billing                          | Used `shutdown` or `poweroff` inside the VM                                          | Terminate via the API or console                                                                         |
| `apt full-upgrade` fails on Lambda Stack 24.04 or GPU Base 24.04 | Known image issue (as of December 2025 docs)                                         | See Lambda docs Troubleshooting for the workaround; avoid full-upgrade                                   |
| JupyterLab link not ready                                        | Takes a few minutes after launch                                                     | Wait; use SSH                                                                                            |
| Model download slow on every relaunch                            | HF cache on the root volume                                                          | Point `HF_HOME` at a filesystem path                                                                     |
| Filesystem storage bill higher than expected                     | `.Trash-*` directories                                                               | Empty them permanently (Lambda docs: Emptying `.Trash-*` directories)                                    |

## Hosted Inference API sunset

Lambda Chat and the Lambda Inference API (OpenAI-compatible, `https://api.lambda.ai/v1`) were announced for sunset on September 25 in a community post dated September 2, 2025. The current docs page `public-cloud/lambda-inference-api/` now only introduces On-Demand Cloud and 1-Click Clusters. LiteLLM still documents a `lambda_ai/` provider prefix and `LAMBDA_API_KEY`, but treat the endpoint as unavailable. Unverified: check https://lambda.ai/inference. Replacement: self-host on an instance (this skill) or use a managed API via `cloud-llms`.

## Sources

- https://docs.lambda.ai/api/cloud
- https://docs.lambda.ai/public-cloud/on-demand/
- https://deeptalk.lambda.ai/t/sunsetting-chat-sunsetting-inference/4744
- https://docs.litellm.ai/docs/providers/lambda_ai
