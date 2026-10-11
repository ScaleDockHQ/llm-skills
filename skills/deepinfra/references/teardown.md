# DeepInfra teardown

> Verified against DeepInfra docs (Custom LLMs, GPU Instances, Authentication, Batch API, API reference: deploy stop, start, delete, delete API token by id), 2026-10-11

Serverless calls cost nothing while idle. Private deployments, LoRA deployments and GPU containers bill per hour until stopped. Ask before each deletion.

## Checklist

- [ ] **List what is billing**:

```bash
curl -sS https://api.deepinfra.com/deploy/list -H "Authorization: Bearer $DEEPINFRA_API_KEY" | jq '.[] | {deploy_id, model_name, status}'
curl -sS https://api.deepinfra.com/v1/containers -H "Authorization: Bearer $DEEPINFRA_API_KEY" | jq .
```

- [ ] **Stop or delete deployments.** Stop keeps the configuration so you can `start` it again (`POST /deploy/{deploy_id}/stop`); delete is permanent (`DELETE /deploy/{deploy_id}`). Unverified: whether a stopped deployment bills at all; delete if you do not need it soon.
- [ ] **Terminate GPU containers.** `DELETE /v1/containers/{id}`. All container data is permanently lost; copy results out with `scp` first.
- [ ] **Cancel batches** still running: `POST /v1/openai/batches/{id}/cancel`. Delete input and output files with the OpenAI Files API (`DELETE /v1/openai/files/{id}`, the standard OpenAI route; unverified on DeepInfra, check the file-endpoints page) or set `output_expires_after` on creation.
- [ ] **Delete test keys**: list with `GET /v1/api-tokens`, delete with `DELETE /v1/api-tokens/id/{token_id}`. Scoped JWTs signed by a deleted key stop counting; verify they fail. Alternatively set the key's monthly limit to `0` to block it without deleting (`limits-and-spend.md`).
- [ ] **Billing**: remove stored cards or set the account limit with `POST /payment/config` if the account is retired. Download invoices first.
- [ ] **Local**: `rm ~/.config/deepinfra.key`, unset shell variables, remove gateway entries and CI secrets.
- [ ] **Account deletion** exists as an API call (Account section). Only with explicit approval.

## Verify

```bash
curl -sS https://api.deepinfra.com/deploy/list -H "Authorization: Bearer $DEEPINFRA_API_KEY" | jq 'length'
curl -sS https://api.deepinfra.com/v1/containers -H "Authorization: Bearer $DEEPINFRA_API_KEY" | jq 'length'
curl -s -o /dev/null -w '%{http_code}\n' https://api.deepinfra.com/v1/openai/chat/completions -H "Authorization: Bearer $OLD_KEY" -H "Content-Type: application/json" -d '{}'
```

Expect empty lists (or only `deleted` entries) and an authentication failure for the old key. Then check the next weekly invoice for per-hour charges.
