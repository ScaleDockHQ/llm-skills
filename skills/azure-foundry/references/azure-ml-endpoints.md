# Azure Machine Learning managed online endpoints (custom models)

> Verified against Azure Machine Learning docs (Online endpoints YAML reference, Authenticate clients for online endpoints, Deploy an ML model with an online endpoint), a Microsoft Community Hub vLLM-on-Azure-ML walkthrough and a community vLLM-on-Azure-ML repository, `az ml` CLI v2, 2026-10-11

## When to use

Use when Foundry does not host the model (custom weights, a fine-tune, a niche model) and you want managed serving without running VMs or Kubernetes. You choose a GPU instance type and container. An endpoint is only the network front; **compute charges start when a deployment exists** and continue per instance-hour, including idle. Foundry also offers managed-compute deployments for catalog open models (`az cognitiveservices account managed-compute-deployment`, preview); use whichever your model supports.

Prerequisites: an Azure ML workspace, the `ml` CLI extension (`az extension add -n ml`), and GPU VM quota in the region (request in Azure portal quotas before deploying).

## Endpoint and deployment

```yaml
# endpoint.yml
$schema: https://azuremlschemas.azureedge.net/latest/managedOnlineEndpoint.schema.json
name: my-llm
auth_mode: key # key | aml_token | aad_token (managed endpoints only for aad_token)
# public_network_access: disabled   # inbound via the workspace private endpoint only
```

```yaml
# deployment.yml  (vLLM pattern; image lives in your workspace ACR)
$schema: https://azuremlschemas.azureedge.net/latest/managedOnlineDeployment.schema.json
name: blue
endpoint_name: my-llm
environment_variables:
  MODEL_NAME: <hub-model-id>
  VLLM_ARGS: "--max-model-len 8192"
  # Gated weights: supply the Hugging Face token through a workspace secret/Key Vault reference,
  # not as a literal in this file.
environment:
  image: <acr-name>.azurecr.io/<vllm-image>:<pinned-tag>
  inference_config:
    liveness_route: { port: 8000, path: /ping }
    readiness_route: { port: 8000, path: /health }
    scoring_route: { port: 8000, path: / }
instance_type: <GPU SKU, e.g. a Standard_NC...ads_A100_v4 size you have quota for>
instance_count: 1
request_settings:
  request_timeout_ms: 60000
  max_concurrent_requests_per_instance: 16
```

The vLLM container itself (serving flags, tool-call parser, image build) belongs to `self-hosted-llms`; the walkthroughs build a custom image that exposes vLLM on port 8000 and `/ping`, `/health` probes. In a private workspace the ACR cannot pull from public registries, so build and push to the workspace ACR.

```bash
az ml online-endpoint create -f endpoint.yml -g "$RG" -w "$WS"
az ml online-deployment create -f deployment.yml -g "$RG" -w "$WS" --all-traffic

az ml online-endpoint show -n my-llm -g "$RG" -w "$WS" --query scoring_uri -o tsv
```

## Call it

Key mode: the key (primary key) goes in `Authorization: Bearer`. Retrieve it without printing:

```bash
umask 077
az ml online-endpoint get-credentials -n my-llm -g "$RG" -w "$WS" --query primaryKey -o tsv > ~/.config/aml-my-llm.key
```

```bash
curl -sS "$SCORING_URI" -H "Authorization: Bearer $(cat ~/.config/aml-my-llm.key)" \
  -H "Content-Type: application/json" -d '{"prompt":"hello"}'
```

The request shape depends on your scoring route; a vLLM container with `scoring_route.path: /` serves whatever route it exposes at that base (OpenAI routes under `/v1/...` need the URI path to match what the deployment forwards; test with a small request first).

Auth modes (data plane): `key` (static, lowest security, dev/test), `aml_token` (short-lived, auto-refreshed), `aad_token` (Entra, managed endpoints only, needs RBAC `score/action`, recommended for production). Control-plane auth is separate (RBAC on the workspace).

## Rollouts

Blue/green: create a second deployment under the same endpoint without `--all-traffic`, then shift: `az ml online-endpoint update -n my-llm --traffic "blue=90 green=10"`. You cannot set `traffic` at endpoint creation. Delete the old deployment only after the new one is proven.

## Gateway

Put LiteLLM in front: a custom `openai/` entry with `api_base` set to the scoring base, key from env (`litellm-and-clients.md`). Only use the `openai/` provider if the container really serves OpenAI routes.

## Sources

- https://learn.microsoft.com/en-us/azure/machine-learning/reference-yaml-endpoint-online?view=azureml-api-2
- https://learn.microsoft.com/en-us/azure/machine-learning/how-to-authenticate-online-endpoint?view=azureml-api-2
- https://learn.microsoft.com/en-us/azure/machine-learning/how-to-deploy-online-endpoints?view=azureml-api-2
- https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/unlocking-function-calling-with-vllm-and-azure-machine-learning/4362457
- https://github.com/mdspinali/azureml-vllm
