# CoreWeave: LiteLLM and OpenAI clients

> Verified against LiteLLM W&B Inference provider docs and PR 14416, CoreWeave Serverless Inference API reference, Dedicated Inference getting-started guide and the CKS vLLM tutorial, 2026-10-11

Pick the entry for the product you run. All keys come from the environment; the gateway holds them, clients hold a LiteLLM virtual key.

## Serverless Inference (W&B Inference host)

LiteLLM documents a `wandb/` provider prefix for W&B Inference models. The explicit OpenAI-compatible form needs the project header and avoids relying on provider routing:

```yaml
model_list:
  - model_name: cw-serverless
    litellm_params:
      model: openai/<model-id> # e.g. an id returned by GET /models
      api_base: https://api.inference.wandb.ai/v1
      api_key: os.environ/WANDB_API_KEY
      extra_headers:
        OpenAI-Project: os.environ/WANDB_PROJECT # "team/project"
```

Alternative per LiteLLM docs: `model: wandb/<model-id>` with `api_key: os.environ/WANDB_API_KEY`. Unverified: that the `wandb/` route forwards `OpenAI-Project`; test with a single request before relying on it. Use `extra_headers` (not `headers`) unless your LiteLLM version documents otherwise; confirm in `llm-gateway`.

## Dedicated Inference gateway

The gateway is OpenAI-compatible with `model` set to your deployment's model name, and uses your CoreWeave API access token as the bearer.

```yaml
model_list:
  - model_name: cw-dedicated
    litellm_params:
      model: openai/<MODEL_NAME>
      api_base: https://<gateway-name>.<org-id>.gw.cwinference.com/v1
      api_key: os.environ/CW_INFERENCE_TOKEN
      timeout: 120
```

Use a token with the narrowest role and an expiry, and rotate it. Use the gateway endpoint shown by `cwic inference gateway get`; the example shape comes from the docs and your org id differs.

## Your own vLLM on CKS

Expose a Service reachable from the gateway (private network, or a `LoadBalancer` behind auth) and use the `hosted_vllm/` provider as in `cloud-llms/assets/litellm-hybrid.yaml`:

```yaml
model_list:
  - model_name: cw-cks
    litellm_params:
      model: hosted_vllm/<served-model-name>
      api_base: http://<service-or-lb-address>:11434/v1 # the tutorial maps 11434 to container port 8000
      api_key: os.environ/CKS_VLLM_API_KEY
```

## OpenAI SDK directly

```python
import os
from openai import OpenAI
# Serverless
OpenAI(base_url="https://api.inference.wandb.ai/v1", api_key=os.environ["WANDB_API_KEY"], project=os.environ["WANDB_PROJECT"])
# Dedicated gateway
OpenAI(base_url=os.environ["CW_GATEWAY_ENDPOINT"] + "/v1/", api_key=os.environ["CW_API_TOKEN"])
```

## Fallback pattern

Route `cw-dedicated` to a managed API on `5xx` or timeout, and keep a `private` alias with no cloud fallback for data that must stay on CoreWeave. See `llm-gateway` for `fallbacks`, budgets and virtual keys.

## Sources

- https://docs.litellm.ai/docs/providers/wandb_inference
- https://docs.coreweave.com/products/inference/serverless/api-reference
- https://docs.coreweave.com/products/inference/getting-started
- https://docs.coreweave.com/products/cks/deploy-model
