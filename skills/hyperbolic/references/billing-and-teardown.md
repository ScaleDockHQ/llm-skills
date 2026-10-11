# Hyperbolic billing, spend control and teardown

> Verified against hyperbolic.ai/docs on-demand/pricing, general/billing-payments, general/auto-top-up, on-demand/maintenance, api-reference rentals and balances endpoints, 2026-10-11

Do not hardcode rates. Read them at decision time from `costPerHourCents` in `GET /v2/on-demand/rental-options` or the console at https://app.hyperbolic.ai/gpus.

## How billing works

| Item             | Behaviour                                                                                                                                                                                                     |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| On-demand        | Hourly, from the moment the instance is Ready (provisioned and SSH-reachable) until terminated. No minimum charge. Rate is locked at creation, apart from a rare notice for long-running below-market rentals |
| Never charged    | An instance that never becomes Ready. The provisioning timeout is about 3 hours, then it is terminated automatically                                                                                          |
| Required balance | Enough for at least one hour of runtime across all your instances, including the new one                                                                                                                      |
| Reserved         | Paid in full at creation, no early termination. A failed provisioning is refunded                                                                                                                             |
| Spot             | Cheaper for eligible configurations, can be interrupted with notice, see `references/rentals-api.md`                                                                                                          |
| Storage volumes  | Billed hourly by provisioned size, regardless of use, until terminated                                                                                                                                        |
| Credits          | Bought in dollars, 1:1, do not expire. Private Cloud is billed separately by contract                                                                                                                         |

## Spend control

The docs describe no per-key or per-project spend cap (unverified beyond the pages above). The controls are:

1. **Balance as the ceiling.** Instances are terminated automatically when the balance is no longer positive. Keep only what you are willing to lose in the balance.
2. **Auto top-up** (opposite of a cap): charges a stored card when the balance falls below your threshold. Enable it only if the user wants uninterrupted service: Settings, Billing, https://hyperbolic.ai/docs/general/auto-top-up.
3. **Your own check.** Poll the summary and alert yourself:

```bash
curl -sS https://api.hyperbolic.ai/v2/on-demand/active-rental-summary -H "Authorization: Bearer $HYPERBOLIC_API_KEY" | jq .
curl -sS https://api.hyperbolic.ai/v2/customer/balance -H "Authorization: Bearer $HYPERBOLIC_API_KEY" | jq .
```

The summary returns the count of active rentals and their summed hourly cost in cents. Spec has no field list, so inspect the JSON before scripting against it.

Data risk when the balance hits zero: on-machine data is lost. Volumes get a 30-day grace period before automatic termination.

## Tear down

Termination is permanent. On-machine data cannot be recovered.

- [ ] List active rentals and note IDs: `GET /v2/on-demand/rentals/active`.
- [ ] Copy anything needed (weights you cannot re-download, checkpoints, logs) to a volume you are keeping or to object storage.
- [ ] Remove the box from LiteLLM and any DNS or firewall entries.
- [ ] Get approval for the exact rental IDs, then terminate:

```bash
curl -sS -X POST https://api.hyperbolic.ai/v2/on-demand/rentals/terminate \
  -H "Authorization: Bearer $HYPERBOLIC_API_KEY" -H "Content-Type: application/json" \
  -d '{"rentalId": <ID>, "reason": "done"}' | jq .
```

- [ ] Reserved rentals cannot be terminated early. Turn off Reservation Protection in the instance settings if it should end at term end instead of converting to on-demand.
- [ ] Storage volumes keep billing after the instance is gone. Terminate unneeded ones with `POST /v2/on-demand/storage-volumes/terminate` (or in the console). Volume termination is permanent too.
- [ ] Delete SSH keys you no longer want, only after the instance is terminated.
- [ ] Verify: `GET /v2/on-demand/rentals/active` is empty, `GET /v2/on-demand/storage-volumes` shows only intended volumes, and the summary hourly cost is zero.
- [ ] Rentals of a managed Kubernetes cluster cannot be terminated individually. Manage them through the cluster.

Terminating a rental that does not exist or already ended returns `RENTAL_NOT_FOUND` (bare metal).

## Refunds

Unused credit: see "Refunds and withdrawals" at https://hyperbolic.ai/docs/faq/account-billing, or email support@hyperbolic.ai.
