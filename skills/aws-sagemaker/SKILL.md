---
name: aws-sagemaker
description: Host your own LLM on Amazon SageMaker AI endpoints (real-time, async, serverless, inference components), with JumpStart and LMI/vLLM containers, scale to zero, SigV4 invocation, teardown and cost checks. Use for SageMaker, JumpStart, LMI container, djl-inference, create-endpoint, invoke-endpoint, inference component, MinInstanceCount 0, sagemaker/ LiteLLM, endpoint left running. For hosted API models use aws-bedrock; for provider comparison cloud-llms; for gateway design llm-gateway; for vLLM flags vllm.
license: MIT
compatibility: Needs bash, curl, jq and AWS CLI v2, network access to AWS, an AWS account, an execution role for SageMaker, and GPU instance quota in the chosen Region. Endpoints, inference components, async queues and autoscaling bill the account, so each needs the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Amazon SageMaker AI

Deploy an open-weights or fine-tuned LLM on SageMaker AI hosting in your own AWS account, call it through SigV4-signed InvokeEndpoint (or a gateway), scale it down when idle, and delete the endpoint, endpoint config and model when finished. SageMaker was renamed **Amazon SageMaker AI** (2024-12-03); API names, CLI commands (`aws sagemaker`), IAM prefixes and URLs still say `sagemaker`.

**Scope:** real-time, asynchronous and serverless endpoints, inference components, JumpStart models, AWS LMI (Large Model Inference) containers wrapping vLLM, scale to zero, autoscaling, `aws sagemaker` and `aws sagemaker-runtime` discovery, teardown and cost checks.

**Out of scope:** managed model APIs (`aws-bedrock`), choosing a provider (`cloud-llms`, `choosing-llm-hosting`), gateway keys and routing (`llm-gateway`), vLLM engine flags (`vllm`), quantization (`model-quantization`), training and fine-tuning (`fine-tuning-llms`), GPU sizing (`choosing-hardware`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only; variable names only, never values.

```bash
command -v aws && aws --version
env | cut -d= -f1 | grep -E '^(AWS_|HF_|LITELLM)' || echo "no matching env vars"
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output json
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
aws sagemaker list-endpoints --region "$REGION" \
  --query 'Endpoints[].[EndpointName,EndpointStatus,CreationTime]' --output table
aws sagemaker list-endpoint-configs --region "$REGION" --query 'EndpointConfigs[].EndpointConfigName' --output text
aws sagemaker list-models --region "$REGION" --query 'Models[].ModelName' --output text
aws sagemaker list-inference-components --region "$REGION" --query 'InferenceComponents[].[InferenceComponentName,EndpointName,InferenceComponentStatus]' --output table
aws service-quotas list-service-quotas --service-code sagemaker --region "$REGION" \
  --query "Quotas[?contains(QuotaName,'endpoint usage')].[QuotaName,Value]" --output text | head -40
```

Anything `InService` is billing right now. Unverified: the `--query` field names above come from API shapes; adjust if a command errors.

## Decision flow

1. **Hosted model API is enough?** Use `aws-bedrock`; SageMaker is for models Bedrock does not host, fine-tunes, or full control of the serving stack.
2. **Steady or low-latency traffic?** Real-time endpoint on a GPU instance (`references/deploy-llm.md`).
3. **Idle gaps and cold starts acceptable, need scale to zero with sync calls?** Real-time endpoint using **inference components** and `MinInstanceCount` 0 (`references/scaling-and-cost.md`).
4. **Queued, long or large requests (up to 1 GB payload, up to 1 hour)?** Asynchronous endpoint, can scale to zero (`references/scaling-and-cost.md`).
5. **Serverless Inference?** Not for LLMs: no GPUs, max 6 GB memory (`references/scaling-and-cost.md`).
6. **Pick the model:** JumpStart for catalog models, LMI container with `HF_MODEL_ID` for Hugging Face or S3 weights (`references/deploy-llm.md`).
7. **Gateway or clients:** `references/litellm-and-clients.md`.
8. **Broken:** `references/troubleshooting.md`. **Done:** `references/teardown.md`.

## Rules

- **Ask before anything billable.** State instance type and count, max instances, region and a stop time first. An endpoint bills per instance-hour until deleted.
- **Secrets stay secret.** Use IAM roles; pass `HF_TOKEN` for gated models from a secret manager or `0600` file, never printed or committed. No static keys in code.
- **Pin versions.** Pin the LMI container tag (from the DLC release list, not `latest`) and model revision (`HF_REVISION`).
- **Quota and budget checks before deploy.** GPU instance quotas are per instance type and Region and are often zero; read them first and set an AWS Budget.
- **Least privilege.** Separate the execution role (what the container can read) from the caller role (`sagemaker:InvokeEndpoint` on one endpoint ARN).
- **Always tear down.** Deleting the endpoint stops instance charges but leaves the endpoint config and model; delete all three, plus inference components, autoscaling targets and alarms, then verify.
- **Do not hardcode prices.** Read https://aws.amazon.com/sagemaker/ai/pricing/ and use Cost Explorer.

## Workflows

### 1. Account, role and quota

- [ ] Region chosen, `aws sts get-caller-identity` works, GPU instance quota for the target type is above zero (`references/setup-and-auth.md`).
- [ ] Execution role exists with SageMaker trust and S3 and ECR read; caller can invoke.

### 2. Deploy an LLM

- [ ] Choose JumpStart or LMI (`references/deploy-llm.md`); size the instance with `choosing-hardware`.
- [ ] After approval, create model, endpoint config and endpoint (or `ModelBuilder.deploy`); wait for `InService`.
- [ ] Smoke test with `aws sagemaker-runtime invoke-endpoint` and a chat payload.

### 3. Connect LiteLLM and clients

- [ ] Add `sagemaker_chat/<endpoint>` (messages payload) or `sagemaker/<endpoint>` (`references/litellm-and-clients.md`).
- [ ] Test through the gateway; the gateway role needs `sagemaker:InvokeEndpoint`.

### 4. Scale

- [ ] Enable autoscaling; for scale to zero use inference components and `MinInstanceCount` 0 with a step policy and alarm, or async endpoints (`references/scaling-and-cost.md`).
- [ ] Expect minutes of cold start; clients must retry.

### 5. Monitor cost

- [ ] AWS Budgets, CloudWatch utilization, tag resources, `list-endpoints` daily.

### 6. Update

- [ ] Create a new endpoint config and `update-endpoint`, or a second endpoint plus gateway alias switch; delete the old config afterwards.

### 7. Tear down

- [ ] `references/teardown.md`: endpoint, endpoint config, model, inference components, autoscaling, alarms; verify.

### 8. Troubleshoot

- [ ] CloudWatch endpoint logs and `describe-endpoint` `FailureReason`, then `references/troubleshooting.md`.

## Reference index

| File                                | Load when                                                                       |
| ----------------------------------- | ------------------------------------------------------------------------------- |
| `references/setup-and-auth.md`      | Roles, quotas, region, CLI discovery, invoking permissions                      |
| `references/deploy-llm.md`          | JumpStart, LMI container settings, CLI and boto3 deploy flows, invocation       |
| `references/scaling-and-cost.md`    | Endpoint types, autoscaling, scale to zero, async, serverless limits, budgets   |
| `references/litellm-and-clients.md` | LiteLLM `sagemaker/` routes, calling with boto3 and curl, OpenAI-style payloads |
| `references/teardown.md`            | Removing every billable resource and verifying                                  |
| `references/troubleshooting.md`     | Symptom to cause to fix                                                         |

## Companion skills

- `cloud-llms`: `npx skills add ScaleDockHQ/llms-skills --skill cloud-llms` (compare providers, hybrid setups)
- `llm-gateway`: `npx skills add ScaleDockHQ/llms-skills --skill llm-gateway` (one endpoint, keys, budgets)
- `aws-bedrock`: `npx skills add ScaleDockHQ/llms-skills --skill aws-bedrock` (hosted models on AWS)
- `vllm`: `npx skills add ScaleDockHQ/llms-skills --skill vllm` (engine flags behind LMI)
- `choosing-llm-hosting`: `npx skills add ScaleDockHQ/llms-skills --skill choosing-llm-hosting`
- `self-hosted-llms`: `npx skills add ScaleDockHQ/llms-skills --skill self-hosted-llms`
- `model-quantization`: `npx skills add ScaleDockHQ/llms-skills --skill model-quantization`
- `fine-tuning-llms`: `npx skills add ScaleDockHQ/llms-skills --skill fine-tuning-llms`
- `llm-observability`: `npx skills add ScaleDockHQ/llms-skills --skill llm-observability`
- `llm-evals`: `npx skills add ScaleDockHQ/llms-skills --skill llm-evals`
