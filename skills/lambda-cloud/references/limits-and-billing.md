# Lambda Cloud: limits, capacity and billing

> Verified against Lambda docs: Billing overview, Creating and managing instances, Filesystems, Cloud API (rate limits and error codes), Resource hierarchy, 2026-10-11

## Limits you will hit

| Limit                                                                          | Where to see it                                                                                                      |
| ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| API rate: about 1 request per second; launch 1 per 12 s (5 per min)            | API docs page; HTTP 429 `global/rate-limited`                                                                        |
| Instance launch quota: new accounts have a cap that grows as invoices are paid | Error `global/quota-exceeded` on launch; console notification                                                        |
| Capacity per instance type and region                                          | `regions_with_capacity_available` in `GET /instance-types`; error `instance-operations/launch/insufficient-capacity` |
| 24 filesystems; `us-south-1` capped at 10 TB                                   | Filesystems docs                                                                                                     |
| 200 workspaces per account                                                     | Resource hierarchy docs                                                                                              |

No numeric quota table is published in the docs read; ask Lambda support to raise the launch quota. Do not copy quota numbers into configs.

## Billing model

- ODC instances: hourly price, billed in one-minute increments, from launch (after health checks) until terminate, whether or not the GPU is used. Weekly invoices.
- Filesystems: per GiB used per month, billed in one-hour increments while the filesystem exists, mounted or not. No ingress or egress fees.
- 1CC: per GPU per hour, billed in weekly increments under the reservation.
- Refunds are service credits that expire after 12 months.
- There is no stop or pause that keeps the instance but ends billing.

Read prices live: `GET /instance-types` (`price_cents_per_hour`), the on-demand pricing page on lambda.ai, and the pricing shown when you create a filesystem. Do not hardcode them.

## Budget controls

No account spend cap or budget alert API was found in the docs read. Unverified: check the console billing page for any usage limit or alert before relying on one. Until then:

- Tag every instance (`owner`, `purpose`) and run a periodic read-only sweep of `GET /instances` and `GET /file-systems`.
- Make the launch step print an estimate (`price_cents_per_hour` x planned hours) and get approval.
- Set a calendar reminder or a scheduled agent task to run the teardown check.
- Use the gateway's budgets (`llm-gateway`) to bound request volume to the box, which does not cap VM cost but caps use.

## See current spend

- Console Usage page (per resource type, filesystems tab).
- Audit events: `GET /audit-events` shows who launched or terminated what.
- Running cost estimate:

```bash
curl -sS -H "Authorization: Bearer $LAMBDA_API_KEY" https://cloud.lambda.ai/api/v1/instances \
  | jq '[.data[] | .instance_type.price_cents_per_hour] | add // 0 | "\(. ) cents per hour across running instances"'
```

## Sources

- https://docs.lambda.ai/public-cloud/billing/
- https://docs.lambda.ai/public-cloud/on-demand/creating-managing-instances/
- https://docs.lambda.ai/api/cloud
