# Managed endpoints for your own model

> Verified against Amazon SageMaker AI Developer Guide (LMI container docs, real-time deployment, scale to zero), Gemini Enterprise Agent Platform docs (vLLM serving tutorial, Model Garden), Azure Machine Learning online endpoints concept page, Hugging Face Inference Endpoints docs (autoscaling, pricing) and vLLM v0.31.0 HF Inference Endpoints guide, 2026-10-11

## What it is and when to choose it

The cloud runs the serving infrastructure; you pick the model (open weights, your fine-tune, or a Hub model), the container and the instance type. You pay per instance-hour while the endpoint has replicas. Choose this tier when you need a model the APIs do not host (a fine-tune, a niche model, a specific quantization) but do not want to run VMs or Kubernetes.

| Platform | Serving container options | Scale to zero | Notes |
| --- | --- | --- | --- |
| Amazon SageMaker AI real-time endpoints | AWS Large Model Inference (LMI) containers, which wrap engines such as vLLM; bring your own container | Yes, only for endpoints that host **inference components** | Deep AWS integration (IAM, VPC, CloudWatch) |
| Agent Platform (Vertex AI) endpoints | Model Garden one-click deploy; prebuilt vLLM serving containers; custom containers | Check current docs for your model type | Same project IAM and VPC controls as the model APIs |
| Azure Machine Learning managed online endpoints | Curated environments or custom containers; Foundry "managed compute" deployments | Check current docs | Blue/green traffic splitting between deployments |
| Hugging Face Inference Endpoints | vLLM, TGI, SGLang, llama.cpp and custom images, chosen in the UI or API | Yes, after 15 minutes idle | Deploy straight from a Hub repo; cloud and region selectable |

## Install / setup

Pattern common to all four:

1. Put the weights where the platform can read them (Hub repo, S3/GCS/Blob bucket, model registry). Private repos need a token stored as a secret.
2. Pick the container and pin its version.
3. Pick the instance type with enough GPU memory for weights plus KV cache at your context length (see `model-quantization` if it does not fit).
4. Set min/max replicas and an autoscaling metric.
5. Restrict network access (private endpoint or VPC) and auth.
6. Test `/v1/models` and a chat request; then add it to the gateway.

Platform pointers:

- SageMaker: follow the LMI container documentation (hosted on the Deep Java Library site) for engine-specific options; deploy with inference components if you need scale to zero, and attach an Application Auto Scaling step policy plus a CloudWatch alarm to scale out from zero.
- Agent Platform: the vLLM serving tutorial covers deploying open models with vLLM containers on Cloud GPUs; Model Garden offers preconfigured deployments.
- Azure ML: create a managed online endpoint, then one or more deployments under it; split traffic between deployments for safe rollouts.
- Hugging Face Inference Endpoints: deploy from the catalog (vLLM preconfigured) or the model page; append `/v1` to the endpoint URL for the OpenAI-compatible routes when using vLLM.

## Minimal working config

Gateway entry for an OpenAI-compatible managed endpoint (vLLM or TGI behind it):

```yaml
model_list:
  - model_name: my-finetune
    litellm_params:
      model: openai/<served-model-name>
      api_base: https://<endpoint-host>/v1
      api_key: os.environ/HF_TOKEN   # or the platform's token; never inline
```

SageMaker endpoints are invoked with SigV4 rather than a bearer token; LiteLLM has a `sagemaker/` provider for that (see its docs). Agent Platform and Azure ML endpoints have their own auth; check whether the endpoint exposes OpenAI-compatible routes before using the `openai/` prefix.

## How it plugs into the stack

- Endpoint: the platform's HTTPS URL (public or private).
- Health: the platform reports deployment state; vLLM inside also serves `/health`.
- Auth: platform IAM or tokens; put the gateway in front so clients never hold platform credentials.
- API coverage: whatever the container serves; vLLM gives OpenAI Chat/Completions/Responses/Embeddings routes and the Anthropic Messages API.

## Operating

- Updates: deploy a new version next to the old one, shift traffic, keep the old one until proven (Azure ML traffic split, SageMaker deployment guardrails, or a second HF endpoint plus a gateway alias switch).
- Logs and metrics land in the platform's monitoring (CloudWatch, Cloud Logging/Monitoring, Azure Monitor, HF endpoint analytics).
- Billing runs per replica-hour. A min replica count of 1 bills all month.

## Tuning knobs worth knowing

- Engine flags passed through the container (for vLLM: `--max-model-len`, `--gpu-memory-utilization`, `--tensor-parallel-size`, `--served-model-name`).
- Autoscaling metric and cooldowns: scale on concurrency or queue depth rather than CPU.
- Scale-to-zero idle window vs user-facing latency.

## Known pitfalls

- Scale to zero on Hugging Face Inference Endpoints returns **502 Bad Gateway** while a replica initializes and has no request queue; clients must retry with backoff, or keep one replica warm.
- SageMaker endpoints without inference components cannot scale to zero.
- Instance quotas for GPU types are often zero by default in a new account or region.
- Model weights downloaded on every cold start: bake them into the image or use a cache volume where the platform allows.

## Official links

- SageMaker LMI container docs: https://docs.aws.amazon.com/sagemaker/latest/dg/large-model-inference-container-docs.html
- SageMaker deploy models for real-time inference: https://docs.aws.amazon.com/sagemaker/latest/dg/realtime-endpoints-deploy-models.html
- SageMaker scale to zero: https://docs.aws.amazon.com/sagemaker/latest/dg/endpoint-auto-scaling-zero-instances.html
- Agent Platform vLLM serving tutorial: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/open-models/vllm/use-vllm
- Azure ML online endpoints: https://learn.microsoft.com/en-us/azure/machine-learning/concept-endpoints-online
- Hugging Face Inference Endpoints autoscaling: https://huggingface.co/docs/inference-endpoints/en/autoscaling
- Hugging Face Inference Endpoints pricing: https://huggingface.co/docs/inference-endpoints/en/pricing
- vLLM on HF Inference Endpoints: https://docs.vllm.ai/en/latest/deployment/frameworks/hf_inference_endpoints/
- LiteLLM SageMaker provider: https://docs.litellm.ai/docs/providers/aws_sagemaker
