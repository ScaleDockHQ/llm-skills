---
name: aws-bedrock
description: Use Amazon Bedrock to call hosted LLMs from your AWS account via Converse, InvokeModel, OpenAI-compatible Chat Completions or Responses, and Anthropic Messages. Covers model access, inference profiles and cross-Region inference, API keys, IAM, VPC endpoints, batch inference, Custom Model Import, quotas and the aws CLI. Use for bedrock-runtime, bedrock-mantle, AWS_BEARER_TOKEN_BEDROCK, ThrottlingException, AccessDeniedException, LiteLLM bedrock/. For SageMaker endpoints use aws-sagemaker; for cross-provider choices use cloud-llms; gateway design llm-gateway.
license: MIT
compatibility: Needs bash, curl, jq and AWS CLI v2 (v2.27.42+ for model-agreement commands), network access to AWS, and an AWS account with IAM credentials or a Bedrock API key. Model subscriptions, batch jobs, provisioned throughput and imports bill the account, so each needs the user's approval.
metadata:
  author: ScaleDockHQ
  version: "0.1.0"
---

# Amazon Bedrock

Get an LLM answering through Amazon Bedrock in your own AWS account: model access granted, the right endpoint and API chosen, credentials scoped, quotas and spend known, clients and a LiteLLM gateway connected, and every billable extra removed when done.

**Scope:** Bedrock runtime endpoints (`bedrock-runtime`, `bedrock-mantle`), Converse and InvokeModel, OpenAI-compatible and Anthropic-compatible routes, inference profiles (cross-Region and application), Bedrock API keys, IAM and model access, VPC interface endpoints, batch inference, Custom Model Import, Provisioned Throughput, quotas, and the `aws` CLI for discovery.

**Out of scope:** SageMaker endpoints and JumpStart (`aws-sagemaker`), comparing providers (`cloud-llms`, `choosing-llm-hosting`), gateway routing, keys and budgets (`llm-gateway`), Azure or Google equivalents (`azure-foundry`, `google-vertex-ai`), fine-tuning workflow (`fine-tuning-llms`).

Work through the steps in order. Load a reference only when a step names it.

## Discover first

Read-only. Variable names only, never values; never `cat` key files.

```bash
command -v aws && aws --version
env | cut -d= -f1 | grep -E '^(AWS_|BEDROCK|OPENAI|LITELLM)' || echo "no matching env vars"
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output json   # who am I (no secrets)
aws configure list-profiles
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
aws bedrock list-foundation-models --region "$REGION" \
  --query 'modelSummaries[].[modelId,modelLifecycle.status]' --output text | head -40
aws bedrock list-inference-profiles --region "$REGION" --type-equals SYSTEM_DEFINED \
  --query 'inferenceProfileSummaries[].inferenceProfileId' --output text | head -40
aws service-quotas list-service-quotas --service-code bedrock --region "$REGION" \
  --query 'Quotas[].[QuotaName,Value,Adjustable]' --output text | head -40
aws bedrock list-model-invocation-jobs --region "$REGION" --query 'invocationJobSummaries[].[jobName,status]' --output text
aws bedrock list-provisioned-model-throughputs --region "$REGION" --query 'provisionedModelSummaries[].[provisionedModelName,status]' --output text
aws bedrock list-imported-models --region "$REGION" --query 'modelSummaries[].modelName' --output text
```

Note what already exists (batch jobs, provisioned throughput, imported models, API keys) before proposing anything. Unverified: the `--query` field names above come from API shapes, so adjust if a command errors.

## Decision flow

1. **Which endpoint?** Default to `bedrock-runtime`. Use `bedrock-mantle` only for server-side tools (web search), background inference, Projects or Workspaces, or a model only offered there (`references/endpoints-and-apis.md`).
2. **Which API?** Existing OpenAI SDK code: Chat Completions or Responses on the OpenAI-compatible path. Existing Anthropic SDK code: Messages API. New AWS-native code: Converse. Model-specific bodies or batch input: InvokeModel.
3. **Cannot call a model (AccessDeniedException)?** Model access and IAM first (`references/setup-and-auth.md`).
4. **Residency?** Pick geographic over global cross-Region profiles and verify destination Regions (`references/inference-profiles.md`).
5. **Private network?** Interface VPC endpoints (`references/limits-and-security.md`).
6. **Offline bulk work?** Batch inference (`references/batch-and-customization.md`).
7. **Own fine-tuned open weights?** Custom Model Import (`references/batch-and-customization.md`); for full control of the serving stack use `aws-sagemaker`.
8. **Throttled or steady heavy load?** Quotas, cross-Region profiles, then Provisioned Throughput (`references/limits-and-security.md`).
9. **Gateway or clients?** `references/litellm-and-clients.md`.
10. **Broken?** `references/troubleshooting.md`. **Done?** `references/teardown.md`.

## Rules

- **Ask before anything billable.** First invocation of a third-party model starts a Marketplace subscription. Batch jobs, Provisioned Throughput (billed hourly until deleted, with 1 or 6 month commitments that cannot be deleted early) and imports need explicit approval with model, Region and stop time.
- **Secrets stay secret.** Prefer IAM roles and short-term keys. Long-term Bedrock API keys are for exploration only, read from `0600` files or env vars (`AWS_BEARER_TOKEN_BEDROCK`), never printed.
- **Pin model IDs and Regions.** Use exact model or inference profile IDs from `list-foundation-models` and the model cards; track lifecycle (Active, Legacy, EOL).
- **Budget and quota controls before traffic.** Read applied quotas, set an AWS Budget, set `max_tokens` in clients, and tag usage with an application inference profile.
- **Residency is explicit.** Global profiles can route anywhere. Use geographic profiles when data must stay in a geography.
- **Always tear down.** Delete API keys, batch outputs you do not need, application inference profiles, imported models and Provisioned Throughput; verify with list commands.
- **Do not hardcode prices or quota numbers.** Read them from the pricing page and Service Quotas.

## Workflows

### 1. Account, access and auth

- [ ] Choose Region and identity (role, SSO profile). `aws sts get-caller-identity` works.
- [ ] Grant invoke permissions scoped to model or profile ARNs; for first use of third-party models add `aws-marketplace:Subscribe`, `Unsubscribe`, `ViewSubscriptions` (`references/setup-and-auth.md`).
- [ ] Anthropic models: submit the use-case form once (`put-use-case-for-model-access`) and check `get-foundation-model-availability`.
- [ ] Optional API key: short-term from the token generator, or long-term only for exploration.

### 2. Call a model

- [ ] Pick endpoint and API (decision flow) and a model or profile ID from discovery.
- [ ] Smoke test with `aws bedrock-runtime converse` or the curl examples in `references/endpoints-and-apis.md`.
- [ ] Set `max_tokens` and handle `ThrottlingException` with exponential backoff and jitter.

### 3. Connect to LiteLLM and clients

- [ ] Add a `model_list` entry with `bedrock/<id>` (`references/litellm-and-clients.md`).
- [ ] Credentials via the AWS chain or `api_key: os.environ/AWS_BEARER_TOKEN_BEDROCK`; test through the gateway.

### 4. Scale and harden

- [ ] Compare applied quotas with expected tokens per minute; request increases early (`references/limits-and-security.md`).
- [ ] Add a cross-Region profile, VPC endpoint and endpoint policy if needed.

### 5. Batch or import (optional)

- [ ] Batch: JSONL in S3, service role, `create-model-invocation-job` (`references/batch-and-customization.md`).
- [ ] Import: Hugging Face-format weights in S3, check architecture and size limits first.

### 6. Monitor cost

- [ ] AWS Budgets alerts, application inference profile tags, CloudTrail for `inferenceRegion`. Use `llm-observability` for request-level tracking.

### 7. Tear down

- [ ] Follow `references/teardown.md`; verify empty lists and remove gateway entries.

### 8. Troubleshoot

- [ ] Error name first in `references/troubleshooting.md`.

## Reference index

| File                                    | Load when                                                                  |
| --------------------------------------- | -------------------------------------------------------------------------- |
| `references/setup-and-auth.md`          | Model access, IAM actions, API keys, CLI discovery                         |
| `references/endpoints-and-apis.md`      | Choosing endpoint and API, curl and SDK examples, feature gaps             |
| `references/inference-profiles.md`      | Cross-Region (geo vs global) and application inference profiles, lifecycle |
| `references/batch-and-customization.md` | Batch inference, Custom Model Import, Provisioned Throughput               |
| `references/limits-and-security.md`     | Quotas, increases, budgets, VPC endpoints, data path                       |
| `references/litellm-and-clients.md`     | LiteLLM routes, OpenAI and Anthropic SDK config                            |
| `references/teardown.md`                | Removing every billable or exposed resource                                |
| `references/troubleshooting.md`         | Symptom to cause to fix with real error strings                            |

## Companion skills

- `cloud-llms`: `npx skills add ScaleDockHQ/llm-skills --skill cloud-llms` (compare providers, hybrid setups)
- `llm-gateway`: `npx skills add ScaleDockHQ/llm-skills --skill llm-gateway` (one endpoint, keys, budgets)
- `aws-sagemaker`: `npx skills add ScaleDockHQ/llm-skills --skill aws-sagemaker` (your own model on AWS endpoints)
- `choosing-llm-hosting`: `npx skills add ScaleDockHQ/llm-skills --skill choosing-llm-hosting`
- `self-hosted-llms`: `npx skills add ScaleDockHQ/llm-skills --skill self-hosted-llms`
- `llm-clients`: `npx skills add ScaleDockHQ/llm-skills --skill llm-clients`
- `llm-observability`: `npx skills add ScaleDockHQ/llm-skills --skill llm-observability`
- `llm-evals`: `npx skills add ScaleDockHQ/llm-skills --skill llm-evals`
- `fine-tuning-llms`: `npx skills add ScaleDockHQ/llm-skills --skill fine-tuning-llms`
