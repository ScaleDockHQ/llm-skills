# Nebius Token Factory: dedicated endpoints

> Verified against Nebius Token Factory docs (Dedicated endpoints, Dedicated endpoints API, Billing), 2026-10-11

Dedicated endpoints run a model on GPUs reserved for you, with a control-plane API and an OpenAI-compatible data plane.

## Facts

- Control plane: `/v0/dedicated_endpoints` on the Token Factory API (templates list, create, get, update, delete).
- Regions: `eu-north1`, `eu-west1`, `us-central1`.
- Minimum replicas are reserved while the endpoint is active (billing runs per GPU-hour while reserved).
- Stopping (`PATCH` with `enabled: false`) releases the capacity; starting again needs capacity to be available (no guarantee).
- Deleting stops billing.
- Inference uses a `routing_key` from the endpoint that starts with `dedicated/` as the model. The base URL can be regional (for example `api.tokenfactory.us-central1.nebius.com`); take the exact URL from the endpoint's details.

## Flow

```bash
BASE=https://api.tokenfactory.nebius.com
# 1. templates (what you can deploy)
# templates path unverified: confirm in the API reference
curl -sS "$BASE/v0/dedicated_endpoints/templates" -H "Authorization: Bearer $NEBIUS_API_KEY" | jq .
```

Show the user the template, region, replica count and the billing rule, then ask. Create with `POST $BASE/v0/dedicated_endpoints` using the body shape in the API reference (https://docs.tokenfactory.nebius.com/api-reference, unverified body fields: copy from the current reference rather than from this file). Poll until the endpoint reports ready, then call with the routing key:

```bash
curl -sS "$INFERENCE_BASE/v1/chat/completions" -H "Authorization: Bearer $NEBIUS_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"'"$ROUTING_KEY"'","messages":[{"role":"user","content":"ping"}]}'
```

Stop: `PATCH /v0/dedicated_endpoints/<id>` with `{"enabled": false}`. Delete: `DELETE /v0/dedicated_endpoints/<id>`.

Autoscaling, custom weights and the exact create body: read https://docs.tokenfactory.nebius.com/ (unverified: check the dedicated endpoints pages from https://docs.tokenfactory.nebius.com/llms.txt).
