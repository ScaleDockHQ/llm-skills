# Hyperbolic rentals API

> Verified against hyperbolic.ai/docs api-reference/openapi.json (API 2.0.0), on-demand/overview, on-demand/pricing, reserved/overview, changelog, 2026-10-11

Base `https://api.hyperbolic.ai`, bearer auth. The per-type `virtual-machine-rentals` and `bare-metal-rentals` endpoints and all pre-`/v2/` paths are deprecated. Use the unified endpoints below.

## Endpoints

| Method and path                                                                                                     | Purpose                                                                                                                                       |
| ------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `GET /v2/on-demand/rental-options`                                                                                  | Offered configurations with `gpuType`, `gpuCount`, `region`, `machineType`, `connectionType`, `costPerHourCents`, `enabled`, `totalAvailable` |
| `POST /v2/on-demand/rentals`                                                                                        | Create a VM or bare metal rental                                                                                                              |
| `POST /v2/on-demand/rentals/terminate`                                                                              | Terminate either machine type. Body: `rentalId` (required), `reason`                                                                          |
| `POST /v2/on-demand/rentals/reboot-instance`                                                                        | Reboot one instance in place, data preserved                                                                                                  |
| `POST /v2/on-demand/rentals/update`                                                                                 | Change the label and the reserved end-of-term action                                                                                          |
| `GET /v2/on-demand/rentals/active`                                                                                  | Active rentals, paged. Query: `page`, `pageSize` (max 100), `gpuType`, `region`, `termType`, `rentalType`                                     |
| `GET /v2/on-demand/rentals/history`                                                                                 | Past rentals, cursor paged                                                                                                                    |
| `GET /v2/on-demand/rental`                                                                                          | One rental by ID                                                                                                                              |
| `GET /v2/on-demand/active-rental-summary`                                                                           | Count of active rentals and summed hourly cost in cents                                                                                       |
| `GET /v2/on-demand/storage-volumes`                                                                                 | List volumes. Also create, attach, update and terminate under `/storage-volumes/...`                                                          |
| `GET /v2/on-demand/reserve-options`, `POST /v2/on-demand/extend-reserved`, `POST /v2/on-demand/convert-to-reserved` | Reserved terms. Quote endpoints exist for extension and conversion                                                                            |

Response bodies of most endpoints are not described in the spec. Run `jq .` on the first response and read the rental ID from it instead of assuming a field name.

## Create fields

Required: `rentalType` (`virtual-machine` or `bare-metal`) and `gpuCount`.

| Field                                | Notes                                                                                                                                                  |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `gpuType`                            | Enum in the spec: `h100`, `h200`, `b200`, `rtx-6000-pro` (default `h100`). B300 appears in the docs lineup, check `rental-options` for what is offered |
| `region`                             | Enum of region codes (default `us-central-1`). Pick one that `rental-options` shows as `enabled`                                                       |
| `networkType`                        | `infiniband` or `ethernet`. Required for bare metal, VM defaults to ethernet                                                                           |
| `gpuCount`                           | Bare metal rents whole nodes, so a multiple of 8                                                                                                       |
| `termType`                           | `on-demand` (default) or `reserved`, with `termPeriodDays` and `convertToOnDemandOnExpiry` (default true, the Reservation Protection behaviour)        |
| `sshPublicKeyId` / `sshPublicKeyIds` | Saved key IDs from `GET /v2/ssh-keys`                                                                                                                  |
| `customPorts`                        | Up to 20 ports, VMs only                                                                                                                               |
| `cudaVersion`                        | Bare metal only (`cuda12.8`, `cuda12.9`)                                                                                                               |
| `storageVolume`                      | Attach an existing volume or create a new one with the rental                                                                                          |
| `monitoringEnabled`, `label`         | Optional                                                                                                                                               |

Sending a field meant for the other machine type returns `INVALID_INPUT_FOR_RENTAL_TYPE`.

## Example (ask first)

```bash
# 1. Inspect offers: cheapest enabled single-GPU H100 VM
curl -sS https://api.hyperbolic.ai/v2/on-demand/rental-options \
  -H "Authorization: Bearer $HYPERBOLIC_API_KEY" |
  jq '[.[] | select(.enabled and .gpuType=="h100" and .machineType=="virtual-machine")]
      | sort_by(.costPerHourCents) | .[0:5]
      | map({region, gpuCount, costPerHourCents, totalAvailable})'

# 2. After the user approves the exact config
curl -sS -X POST https://api.hyperbolic.ai/v2/on-demand/rentals \
  -H "Authorization: Bearer $HYPERBOLIC_API_KEY" -H "Content-Type: application/json" \
  -d '{"rentalType":"virtual-machine","gpuCount":1,"gpuType":"h100","region":"us-central-1","label":"llm-test","customPorts":[8000]}' | jq .
```

Do not copy the region or sizes above; use whatever step 1 returns.

## Terms

- **On-demand**: hourly, locked rate, terminate any time.
- **Spot** (announced 2026-10-05 in the changelog): for eligible configurations the launch page offers Spot, with a stated discount, and instances can be interrupted with notice (the console shows the exact notice and rate). Whether the create API has a spot field is unverified: the spec read on 2026-10-11 has none, so use the console.
- **Reserved**: discounted, paid in full at creation, cannot be terminated early, extend before the end. With Reservation Protection on (default) the instance converts to on-demand at the end; with it off it is terminated.
- **Private Cloud**: custom contract, not self-serve: sales@hyperbolic.ai.
- **Managed Kubernetes** (beta): https://hyperbolic.ai/docs/on-demand/managed-kubernetes.

## Notes

- Availability changes hourly. The console has availability alerts (email, up to 10 active, personal accounts only).
- Region lists differ between machine types. Trust `rental-options`.
- Lookup of current rates: the console at https://app.hyperbolic.ai/gpus and `costPerHourCents` from `rental-options`. Do not hardcode rates in docs or scripts.
