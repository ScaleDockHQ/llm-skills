# Crusoe: Managed Inference (Intelligence Foundry)

> Verified against Crusoe Cloud docs (Intelligence Foundry API, Managed Inference quickstart and limits, Self-serve deployments), 2026-10-11

## Serverless API

| Item     | Value                                                                                                |
| -------- | ---------------------------------------------------------------------------------------------------- |
| Base URL | `https://api.inference.crusoecloud.com/v1`                                                           |
| Auth     | `Authorization: Bearer $CRUSOE_API_KEY`                                                              |
| Models   | `GET /v1/models`; the response includes `supported_parameters` such as `tools` and `response_format` |

```bash
curl -sS https://api.inference.crusoecloud.com/v1/models -H "Authorization: Bearer $CRUSOE_API_KEY" \
  | jq -r '.data[] | [.id, ((.supported_parameters // []) | join(","))] | @tsv'
curl -sS https://api.inference.crusoecloud.com/v1/chat/completions \
  -H "Authorization: Bearer $CRUSOE_API_KEY" -H 'Content-Type: application/json' \
  -d '{"model":"'"$MODEL"'","messages":[{"role":"user","content":"Hello"}]}' | jq .
```

Model lists change and several launch models have been deprecated (examples reported: Llama 3.3 70B, DeepSeek V3, Qwen3 235B, some Kimi and GLM versions). Always take the id from `/v1/models`, and check `supported_parameters` before relying on tools or JSON output.

Fine-tuning and batch use the Intelligence Foundry API (`/fine_tuning/jobs`, files with purpose `batch`): https://docs.crusoecloud.com/api/managed-ai/. Fine-tuning bills; ask first. The `crusoe` CLI has no fine-tuning or self-serve deployment subcommand.

## Self-serve deployments (dedicated)

Same Intelligence API key. Console path: Intelligence Foundry app, Inference, Self-Serve Deployments.

```bash
export DEPLOYMENT_URL="https://api.crusoecloud.com/v1/projects/${PROJECT_ID}/foundry/selfserve"
curl -sS "$DEPLOYMENT_URL/flavors" -H "Authorization: Bearer $CRUSOE_API_KEY" | jq .
```

A flavor is a base model plus optimization profile (responsiveness, throughput or balanced) plus hardware. Show the user the flavor, replicas and billing rule, then ask before creating:

```bash
curl -sS "$DEPLOYMENT_URL/deployments" -X POST -H "Authorization: Bearer $CRUSOE_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"flavor_id":"'"$FLAVOR_ID"'","deployment_name":"'"$ALIAS"'","replicas":1}'
```

- Creation is asynchronous (HTTP 202); provisioning can take up to about 40 minutes. Check `GET $DEPLOYMENT_URL/deployments/{id}` and `/progress`.
- `deployment_name` is the model name you send in inference requests; it must be unique in the project.
- Replicas must fit the project's self-serve quota.
- Fine-tuned checkpoint or LoRA: add the fine-tuned model id and pick a flavor marked `lora_suitable` whose `model_name` matches. The field name differs between docs (`fine_tuned_model_id` in the guide, `fine_tuned_model` in the OpenAPI schema); check the current API reference.
- `PATCH .../deployments/{id}` changes name or replicas. `DELETE` stops billing.
- Billing is per GPU-hour while the deployment exists.
