# Replicate billing, limits, spend control and teardown

> Verified against replicate.com/docs topics/billing, topics/billing/prepaid-credit, topics/predictions/rate-limits, topics/models/official-models, topics/deployments/delete-a-deployment, topics/models/delete-a-model, 2026-10-11

Do not store prices. Read them from the model page, the hardware page and https://replicate.com/pricing.

## How billing works

| Item                           | Behaviour                                                                                                                                                                                                                            |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Public models                  | Active (prediction) time only. Setup and idle time are free. Failed runs are not charged                                                                                                                                             |
| Official models                | Priced per output or input unit shown on the model page                                                                                                                                                                              |
| Private models and deployments | Setup, idle and active time                                                                                                                                                                                                          |
| Canceled predictions           | Billed for the time they ran. Aborted ones (never started) are not                                                                                                                                                                   |
| Prepaid credit                 | Credit is valid for one year and non-refundable. Auto-reload has a minimum threshold and reload amount (see the prepaid-credit page for current values). At zero balance new work is blocked and running infrastructure is shut down |
| Billed in arrears              | The other account type, invoiced after use                                                                                                                                                                                           |

Accounts are one or the other, so check which you have in the billing settings: https://replicate.com/account/billing.

## Spend controls

1. **Prepaid with a small balance** is a hard ceiling: when credit runs out, work stops. Auto-reload removes that ceiling, so enable it only on purpose.
2. **`Cancel-After`** on every prediction caps its runtime (`references/predictions-api.md`).
3. **`max_instances`** on every deployment.
4. **`min_instances: 0`** unless latency requires warm instances.
5. A dashboard review of the billing page after any new deployment. Replicate has no per-key budget, as far as the docs read show: unverified, check the billing page.

## Rate limits

Create prediction: 600 per minute. Other endpoints: 3000 per minute. Near-zero balance and accounts with credit but no payment method are throttled harder. A 429 includes the expected wait. See the rate-limits page for current values.

## Tear down

Order matters.

- [ ] List what exists: `GET /v1/deployments`, `GET /v1/models` (yours), `GET /v1/predictions` (in-flight).
- [ ] Cancel running predictions: `POST /v1/predictions/{id}/cancel`.
- [ ] Remove the model from LiteLLM and client configs.
- [ ] Deployments: set `min_instances` to 0 with `PATCH`, wait until offline and idle for 15 minutes, then `DELETE /v1/deployments/{owner}/{name}` (expect 204).
- [ ] Models you pushed: `DELETE /v1/models/{owner}/{name}/versions/{version_id}` for each version, then `DELETE /v1/models/{owner}/{name}`. Only private models you own can be deleted.
- [ ] Disable API tokens made for this job at https://replicate.com/account/api-tokens.
- [ ] Download any outputs you need now. They expire an hour after creation.
- [ ] Verify: the three list calls above show nothing unintended, and the next day's billing shows no idle charges.

```bash
curl -sS -X PATCH https://api.replicate.com/v1/deployments/<owner>/<name> \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"min_instances":0}'
curl -sS -o /dev/null -w "%{http_code}\n" -X DELETE https://api.replicate.com/v1/deployments/<owner>/<name> \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN"
```

Get approval for the exact names before any DELETE.

## Refunds

Prepaid credit is non-refundable, so top up in small amounts.
