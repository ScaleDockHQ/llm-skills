# Custom model endpoints: Model Garden deploy and gcloud ai endpoints

> Verified against Agent Platform docs (Deploy open models from Model Garden, Use models in Model Garden, Deploy a model by using the gcloud CLI or API, Undeploy a model and delete the endpoint, Use dedicated private endpoints based on Private Service Connect), 2026-10-11

## When to use

Self-deployed models are not serverless. You pick the model, accelerator and replica counts, and the endpoint bills while a model is deployed. Use this when the managed APIs do not host the model (a fine-tune, custom weights, a specific quantization). For hosted open models prefer MaaS (`api-and-models.md`).

Self-deployed models deploy inside your project and VPC network. Model Garden has self-deployable cards and, where both exist, a separate "API Service" card for the managed version.

## Deploy from Model Garden

```bash
# Discover
gcloud ai model-garden models list
gcloud ai model-garden models list-deployment-config --model=MODEL_ID

# Deploy with the default config, or override machine/accelerator
gcloud ai model-garden models deploy \
  --model=MODEL_ID \
  --region=LOCATION_ID \
  [--machine-type=MACHINE_TYPE] \
  [--accelerator-type=ACCELERATOR_TYPE] \
  [--endpoint-display-name=ENDPOINT_NAME] \
  [--hugging-face-access-token="$HF_TOKEN"]   # for gated models; read from env, never inline

# See the result
gcloud ai endpoints list --region=LOCATION_ID --project="$PROJECT_ID"
```

Reservation flags (`--reservation-affinity ...`) exist for reserved GPU capacity. Gated models can need `accept_eula` (SDK) or EULA acceptance in the console. Python SDK equivalent: `model_garden.OpenModel("<publisher/model@version>").deploy(accept_eula=True, machine_type=..., accelerator_type=..., accelerator_count=..., use_dedicated_endpoint=True)`.

Check the deployment config first (`list-deployment-config`), then verify GPU quota (`limits-and-budgets.md`): new projects often have no GPU quota for large accelerators.

Custom weights from a Cloud Storage bucket are supported for some models: https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/open-models/deploy-model-garden (see "Deploy models with custom weights" there).

## Deploy a registered model to an existing endpoint

```bash
gcloud ai endpoints deploy-model ENDPOINT_ID \
  --region=LOCATION_ID \
  --model=MODEL_ID \
  --display-name=DEPLOYED_MODEL_NAME \
  --min-replica-count=1 \
  --max-replica-count=2 \
  --traffic-split=0=100
```

`0` is the temporary ID of the new deployed model. To canary, keep traffic on the old one: `--traffic-split=0=20,OLD_DEPLOYED_MODEL_ID=80`. GPU deploys add accelerator flags; read the page below for the current set.

REST form: `POST https://LOCATION_ID-aiplatform.googleapis.com/v1/projects/PROJECT_ID/locations/LOCATION_ID/endpoints/ENDPOINT_ID:deployModel`.

Docs: https://docs.cloud.google.com/gemini-enterprise-agent-platform/machine-learning/predictions/deploy-model-api

## Call a self-deployed LLM endpoint

For OSS LLMs deployed from Model Garden the endpoint serves OpenAI-style routes. Dedicated endpoints have their own DNS name:

```bash
TOKEN=$(gcloud auth application-default print-access-token)
DNS=$(gcloud ai endpoints describe "$ENDPOINT_ID" --project="$PROJECT_ID" --region="$REGION" \
  --format='value(dedicatedEndpointDns)')
HOST=${DNS:-$REGION-aiplatform.googleapis.com}

curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "https://$HOST/v1/projects/$PROJECT_ID/locations/$REGION/endpoints/$ENDPOINT_ID/chat/completions" \
  -d '{"messages":[{"role":"user","content":"Hello"}],"max_tokens":512}'
```

The `model` field may be omitted because the endpoint fixes the model. Use `max_tokens` (OpenAI vocabulary). Reasoning models spend `max_tokens` on thinking before the answer, so very small caps return empty content. This calling recipe comes from Google's published agent skill for Agent Platform inference (github.com/google/skills, `agent-platform-inference`); confirm against the endpoint's model card because routes depend on the serving container. Custom containers may only expose `:predict`.

Endpoint auth is Google IAM only. To expose OpenAI-style access to clients, put the LiteLLM gateway in front and let it hold the identity (`litellm-and-clients.md`).

## Private dedicated endpoints

Private Service Connect lets consumer VPCs reach an endpoint without public IPs: the deployed endpoint has a service attachment (`gcloud ai endpoints describe` shows its URI); create a forwarding rule with `gcloud compute forwarding-rules create`. For gRPC include the `x-vertex-ai-endpoint-id` header. Model Garden one-click **public dedicated** endpoints are not supported inside a VPC Service Controls perimeter; use a private endpoint instead. See `private-access-and-data.md`.

## Sources

- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/model-garden/use-models
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/open-models/deploy-model-garden
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/machine-learning/predictions/deploy-model-api
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/machine-learning/predictions/undeploy-model
- https://docs.cloud.google.com/gemini-enterprise-agent-platform/machine-learning/predictions/private-service-connect
