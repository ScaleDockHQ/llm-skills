# Crusoe: troubleshooting

> Verified against Crusoe Cloud docs read for this skill, 2026-10-11

| Symptom                                      | Likely cause                                                 | Fix                                                                             |
| -------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| 401 `{"code":"bad_credential"}` on inference | Wrong key or project, or `$` in the key mangled by the shell | Re-export with single quotes; create a new Intelligence API key                 |
| 429                                          | Per-model TPM or RPM limit                                   | Back off using `x-ratelimit-*`; reduce concurrency; use a self-serve deployment |
| 503                                          | Model overloaded                                             | Retry with backoff; switch model                                                |
| Model not found                              | Deprecated model or LiteLLM example name                     | `GET /v1/models` and use a current id                                           |
| Tools or JSON ignored                        | Model lacks the parameter                                    | Check `supported_parameters` in `/v1/models`                                    |
| VM created but not reachable                 | VM not started                                               | `crusoe compute vms start`; check `get`                                         |
| VM create fails on quota or capacity         | Quota exhausted or no GPU in that location                   | Check quotas in the console; try another location or type                       |
| GPU data gone after stop                     | Ephemeral local disk wiped                                   | Use persistent disk or object storage                                           |
| `crusoe kubernetes` not found                | Old CLI or docs mismatch                                     | Upgrade CLI; unverified: check docs                                             |
| Cluster delete fails                         | Node pools remain                                            | Delete node pools first                                                         |
| Deployment stuck provisioning                | Provisioning can take up to ~40 minutes                      | Poll `/progress`; check quota for replicas                                      |
| Other error strings                          | Not captured                                                 | unverified: check https://docs.crusoecloud.com                                  |
