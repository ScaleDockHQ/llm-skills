# Managed endpoints for your own model

> Verified against Amazon SageMaker AI Developer Guide (real-time deployment, scale to zero), Gemini Enterprise Agent Platform docs (vLLM serving tutorial), Azure Machine Learning online endpoints concept page, Hugging Face Inference Endpoints docs (autoscaling) and vLLM v0.31.0 HF Inference Endpoints guide, 2026-10-11

The cloud runs the serving infrastructure; you pick the model, container and instance type, and pay per instance-hour while replicas exist. Choose this tier for a fine-tune, niche model or specific quantization when you do not want to run VMs or Kubernetes.

Depth: install the `aws-sagemaker` skill (`npx skills add ScaleDockHQ/llm-skills --skill aws-sagemaker`), the `google-vertex-ai` skill (`npx skills add ScaleDockHQ/llm-skills --skill google-vertex-ai`), the `azure-foundry` skill (`npx skills add ScaleDockHQ/llm-skills --skill azure-foundry`) and the `hugging-face` skill (`npx skills add ScaleDockHQ/llm-skills --skill hugging-face`).

## How it plugs into this stack

```yaml
model_list:
  - model_name: my-finetune
    litellm_params:
      model: openai/<served-model-name>
      api_base: https://<endpoint-host>/v1
      api_key: os.environ/HF_TOKEN # or the platform's token; never inline
```

- SageMaker endpoints use SigV4: use LiteLLM's `sagemaker_chat/` provider for LMI or vLLM containers with a chat template (plain `sagemaker/` fakes streaming). Deleting the endpoint does not delete its endpoint config or model, and scale to zero needs inference components. Check whether Agent Platform and Azure ML endpoints expose OpenAI-compatible routes before using the `openai/` prefix.
- Health: the platform's deployment state; vLLM inside also serves `/health` and `/v1/models`.
- Put the gateway in front so clients never hold platform credentials.
- Roll out updates as a second deployment next to the old one, then switch the gateway alias; keep the old one until proven.
- A minimum replica count of 1 bills all month. Delete endpoints you no longer route to.
- Hugging Face scale to zero returns 502 while a replica starts and has no request queue: retry with backoff in the gateway or keep one replica warm.
- GPU instance quotas are often zero in a new account or region.

## Official links

- SageMaker scale to zero: https://docs.aws.amazon.com/sagemaker/latest/dg/endpoint-auto-scaling-zero-instances.html
- Hugging Face Inference Endpoints autoscaling: https://huggingface.co/docs/inference-endpoints/en/autoscaling
- LiteLLM SageMaker provider: https://docs.litellm.ai/docs/providers/aws_sagemaker
