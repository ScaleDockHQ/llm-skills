# CoreWeave: Dedicated Inference

> Verified against CoreWeave docs: About CoreWeave Inference, Getting started with Dedicated Inference, About Dedicated Inference, Scaling, Billing, Dedicated Inference API reference overview, 2026-10-11

Dedicated Inference serves your own weights (bring your own weights, BYOW) on managed GPUs behind an OpenAI-compatible gateway. The API is `v1alpha1`; expect changes and re-read the docs.

## Prerequisites (all verified in the getting-started guide)

- Dedicated Inference access enabled for your organization (otherwise HTTP 403 `organization is not allowed to perform this operation`).
- Inference GPU quota per organization and instance type (not per zone). Without it: `organization has no GPU quota for it`. Request via a support ticket; `capacityClasses` does not waive it.
- An API access token whose identity has the Inference Admin role.
- Weights in a CoreWeave AI Object Storage bucket (S3-compatible, endpoint `https://cwobject.com`) with a bucket policy letting the Dedicated Inference service account list and read. A missing policy is the most common cause of weights failing to load. Always keep the `cw:PrincipalOrgID` condition on any `"Principal": "*"` statement or the bucket is public.
- `cwic` CLI (or curl or Terraform `coreweave_inference_gateway` and `coreweave_inference_deployment`).

## Create a gateway (billable resources start with the deployment)

```bash
cwic inference gateway parameters         # lists available zones
cwic inference gateway create --name my-gateway --zones <ZONE> --auth coreweave --routing body --api-type openai
cwic inference gateway get <GATEWAY_ID>   # wait for STATUS_READY and an endpoint URL
```

Names must be hostname labels (at most 38 characters for gateways, no dots). DNS and TLS provision asynchronously: an SSL handshake error right after creation means wait a few minutes. REST equivalent: `POST ${CW_BASE_URL}/v1alpha1/inference/gateways` with a bearer token.

## Create a deployment (starts billing)

```bash
cwic inference deployment parameters      # valid instance types and runtime versions
cwic inference deployment create \
  --name my-deployment --gateway-ids "$CW_GATEWAY_ID" \
  --engine vllm --engine-version <ENGINE_VERSION> \
  --instance-type <INSTANCE_TYPE> --gpu-count 1 \
  --model-name <MODEL_NAME> --model-bucket <BUCKET> --model-path <PATH_IN_BUCKET> \
  --min 1 --max 1 --traffic-weight 100
cwic inference deployment get "$CW_DEPLOYMENT_ID"   # poll until STATUS_READY
```

- Engines: `dynamo-vllm` (recommended; wraps vLLM with NVIDIA Dynamo, adds kv-cache-aware routing and parser keys such as `dyn-reasoning-parser`, `dyn-tool-call-parser`) and `vllm`. Version comes from the `parameters` call; pin it.
- Model `name` is the route key (4 to 63 characters) that clients send as `model`. Deployment `name` is a hostname label (at most 63 characters).
- Startup can take several minutes, up to an hour for large models. `STATUS_ERROR` can clear on its own; `STATUS_FAILED` will not.
- Engine options go in `runtime.engineConfig` (for example `max-model-len`) on the REST API.

## Call it

The gateway uses CoreWeave IAM auth: the same API access token authenticates inference calls.

```bash
curl -sS "$CW_GATEWAY_ENDPOINT/v1/chat/completions" \
  -H "Authorization: Bearer $CW_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"model":"<MODEL_NAME>","messages":[{"role":"user","content":"ping"}],"max_tokens":16}' | jq -r '.choices[0].message.content'
```

Responses include extra vLLM fields (`token_ids`, `prompt_logprobs`, `kv_transfer_params`); ignore them. Because the credential is a management token, issue clients a separate token with the narrowest role and expiry, or front the gateway with LiteLLM (`litellm-and-clients.md`).

## Update safely

`PATCH` and `cwic inference deployment update` send the whole spec: omitted fields revert to defaults, so re-pass every flag from create and change only what you need. Changing `runtime.engine`, `model.name` or `model.path` in place disrupts service. For zero downtime create a second deployment with the same gateway and model name and move traffic with `--traffic-weight`, then delete the old one. The CLI has no flag for `hotLoad`; use REST for that.

## Scaling and capacity

- `autoscaling.min` must be at least 1: scale-to-zero is not supported. `max == min` disables autoscaling. Optional `concurrency` (target concurrent requests per replica), `priority` (0 to 1000), `capacityClasses` (`CAPACITY_CLASS_RESERVED`, `CAPACITY_CLASS_ON_DEMAND`).
- Autoscaling does not reserve GPUs. A capacity claim (`CAPACITY_TYPE_MANAGED`) reserves instances in a zone and bills at GPU-hour rates while the claim exists, even idle. Delete claims you no longer need.

## Observability

Cloud Console, Grafana, Inference folder, Inference Model Overview (request rate, TTFT, TPOT, queue, replicas, GPU utilization). Needs the Observability Viewer role. Logs: Explore, CoreWeave Logs, `{cluster="cwinference", container="vllm-server", deployment="<DEPLOYMENT_ID>"}`.

## Sources

- https://docs.coreweave.com/products/inference
- https://docs.coreweave.com/products/inference/getting-started
- https://docs.coreweave.com/products/inference/scaling
- https://docs.coreweave.com/products/inference/billing
- https://docs.coreweave.com/products/inference/reference/api-overview
