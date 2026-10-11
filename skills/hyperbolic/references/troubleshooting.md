# Hyperbolic troubleshooting

> Verified against hyperbolic.ai/docs on-demand/troubleshooting, on-demand/maintenance, general/account-management, changelog, api-reference/openapi.json, 2026-10-11

## Connection

| Symptom                                     | Check                                                                                                                                                       |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Permission denied (publickey)`             | The instance uses the key you selected at launch. Use the matching private key with `chmod 600`. Copy the exact command from Active Instances. Run `ssh -v` |
| SSH refuses or times out right after launch | SSH works only in the Ready state. Wait, then retry                                                                                                         |
| Connection drops                            | Use `tmux` or `screen`. Run long jobs under `nohup` or a service                                                                                            |
| Service not reachable from outside          | Port not opened on the instance, or the server is bound to `localhost`. Bind `0.0.0.0` and confirm the port in the instance details                         |
| Lost the private key                        | A saved key can be attached to a running VM without a reboot (changelog 2026-10-10, API paths unverified), VMs only                                         |

## Instance

| Symptom                                          | Check                                                                                                              |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| Pending for over 30 minutes                      | Contact support with the instance ID. It is terminated automatically at about 3 hours and never charged            |
| `nvidia-smi` shows no GPUs                       | Drivers are preinstalled. Do not install or upgrade them. Send support the instance ID and the `nvidia-smi` output |
| Terminated unexpectedly                          | Balance reached zero, or a reservation ended with Reservation Protection off. On-machine data is gone              |
| Slower than expected                             | Run https://hyperbolic.ai/docs/on-demand/verifying-performance and send the output to support                      |
| Hardware fault in `dmesg` (Xid, GPU off the bus) | Back up first. A reboot on a faulted host may not come back, and the fix can be a fresh instance                   |
| Out of disk                                      | `df -h`. Attach a persistent volume or clean caches and unused container images                                    |

## API errors seen in the docs

| Code                                                | Meaning                                                                                                    |
| --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `INVALID_INPUT_FOR_RENTAL_TYPE`                     | A field belongs to the other machine type (for example `customPorts` on bare metal, `cudaVersion` on a VM) |
| `MULTIPLE_SSH_PUBLIC_KEYS_NOT_SUPPORTED_FOR_REGION` | Several keys sent to a single-key region                                                                   |
| `RENTAL_NOT_FOUND`                                  | Unknown or already ended rental ID                                                                         |
| `SSH_PUBLIC_KEY_IN_USE`                             | Deleting a key that a live rental uses. Terminate first                                                    |
| `SSH_PUBLIC_KEY_NOT_FOUND`                          | Key does not exist or is not yours                                                                         |
| `CANNOT_DETACH_LAST_RENTAL_SSH_KEY`                 | A rental must keep one key                                                                                 |
| `RENTAL_SSH_KEY_UPDATE_NOT_SUPPORTED`               | The rental type cannot change keys, such as bare metal                                                     |
| `FAILED_TO_UPDATE_RENTAL_SSH_KEYS`                  | Safe to retry                                                                                              |

HTTP status codes and the error envelope were not described in the pages read: unverified, check https://hyperbolic.ai/docs/api-reference.

## Billing

- "Cannot create instance": the balance must cover at least one hour across all instances, including the new one. Add funds. Free-tier accounts cannot launch GPUs at all.
- Balance dropping after you thought you were done: list active rentals and storage volumes. Volumes bill until terminated.
- Auto top-up retries after an interrupted charge and is guarded against double charges (changelog 2026-10-05).

## Old inference code failing

See `references/inference-retired.md`.

## Support

https://hyperbolic.ai/docs/general/support, support@hyperbolic.ai, status page https://status.hyperbolic.ai. Include instance ID, region, time, `ssh -v` or `nvidia-smi` output. Never include API keys.
