# Bedrock setup, model access and authentication

> Verified against Amazon Bedrock User Guide pages model-access, api-keys, inference-prereq, AWS CLI v2.37.12 command reference (service-quotas list-service-quotas), 2026-10-11

## Pick Region and identity

Model availability differs by Region. Use an IAM role, SSO profile or instance role so credentials are temporary. Check who you are without printing secrets:

```bash
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output json
```

## Model access

Access to many foundation models is on by default when the caller has the right AWS Marketplace permissions. Key behaviors from the docs:

- First invocation of a third-party model starts a subscription in the background (up to 15 minutes). Calls may succeed briefly, then return `AccessDeniedException` if a prerequisite is missing. After you fix permissions, allow up to 2 minutes.
- Required Marketplace actions: `aws-marketplace:Subscribe`, `aws-marketplace:Unsubscribe`, `aws-marketplace:ViewSubscriptions`. These are only needed the first time a model is used in an account; someone with them can enable the model once for everyone.
- Anthropic models need the First Time Use form once per account (or once at the organization management account). It does not apply to Anthropic models reached through `bedrock-mantle`.
- A valid payment method is required for Marketplace purchases.
- Some models need additional account-level access. If prerequisites are done and the model is supported in the Region but you still get `AccessDeniedException`, the docs say to contact AWS Sales.
- Models from Amazon, DeepSeek, Google, Meta, MiniMax, Mistral AI, Moonshot AI, NVIDIA, Qwen, xAI and Z.AI are not sold through Marketplace, and neither are OpenAI gpt-oss models, so Marketplace scoping does not apply to them.

### Programmatic model access (AWS CLI v2.27.42 or later)

```bash
aws bedrock list-foundation-model-agreement-offers --model-id <modelId>
aws bedrock put-use-case-for-model-access --form-data <base64-json>    # Anthropic only, once
aws bedrock create-foundation-model-agreement --model-id <modelId> --offer-token <offerToken>
aws bedrock get-foundation-model-availability --model-id <modelId>
```

`agreementAvailability.status` is `AVAILABLE`, `PENDING`, `NOT_AVAILABLE` or `ERROR` (with `errorMessage`). `PENDING` can follow an Anthropic form submission; calls keep failing until `AVAILABLE`. These commands create a subscription and an EULA agreement: ask first. `delete-foundation-model-agreement` removes access, but invoking the model creates it again, so also use deny policies to block it.

To require EULA review before use, block access with SCP or IAM first, review, then allow.

## IAM for inference

Minimal action set (scope `Resource` to model and profile ARNs rather than `*` where you can):

- `bedrock:InvokeModel`: InvokeModel and Converse.
- `bedrock:InvokeModelWithResponseStream`: streaming variants.
- `bedrock:GetInferenceProfile`: needed to run inference with an inference profile.
- `bedrock:GetImportedModel`, `bedrock:GetCustomModel`, `bedrock:GetProvisionedModelThroughput`: running those resource types.
- `bedrock:ApplyGuardrail`, `bedrock:GetGuardrail`: guardrails.
- Responses API stored responses on `bedrock-runtime`: `bedrock:GetInvoke`, `bedrock:CancelInvoke`, `bedrock:DeleteInvoke`; creating one also needs `bedrock:InvokeModel` on the project.
- `bedrock-mantle:CreateInference`: the `bedrock-mantle` endpoint.

Authentication alone grants nothing: the IAM principal still needs these actions.

## Bedrock API keys

A bearer token instead of AWS credentials. Two kinds:

| Type       | Lifetime                                            | Notes                                                                                                       |
| ---------- | --------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Short-term | Up to 12 hours or the session, whichever is shorter | Inherits the generating principal's permissions. Recommended for production.                                |
| Long-term  | Until a chosen expiry                               | Creates an IAM user with attached policies. Exploration only. Works only in the Region it was generated in. |

Generate a short-term token with the SDK helpers, never pasted into chat:

```bash
pip install aws-bedrock-token-generator        # Python
npm install @aws/bedrock-token-generator       # JavaScript
```

```python
from aws_bedrock_token_generator import provide_token
token = provide_token()          # cached, refreshed automatically; do not print it
```

Use a key via the environment variable (loaded from a `0600` file, never echoed) or the `Authorization: Bearer` header:

```bash
umask 077; mkdir -p ~/.config/aws-bedrock
# user saves the key into ~/.config/aws-bedrock/api-key (mode 0600), then:
export AWS_BEARER_TOKEN_BEDROCK="$(cat ~/.config/aws-bedrock/api-key)"
```

Long-term key via CLI (creates an IAM user and credential; ask first):

```bash
aws iam create-user --user-name bedrock-api-user
aws iam attach-user-policy --user-name bedrock-api-user \
  --policy-arn arn:aws:iam::aws:policy/AmazonBedrockLimitedAccess
aws iam create-service-specific-credential --user-name bedrock-api-user \
  --service-name bedrock.amazonaws.com --credential-age-days 30
```

The response contains `ServiceApiKeyValue`: write it straight to a `0600` file, do not display it. Control keys with IAM: `iam:CreateServiceSpecificCredential` (limit age with `iam:ServiceSpecificCredentialAgeDays`), `bedrock:CallWithBearerToken` and `bedrock-mantle:CallWithBearerToken` (condition keys `bedrock:bearerTokenType` / `bedrock-mantle:bearerTokenType` with `SHORT_TERM` or `LONG_TERM`). A Deny on those actions blocks API-key use for an identity. Compromised keys: deactivate, reset or delete long-term keys; for short-term keys invalidate the source session or deny `CallWithBearerToken`. See `teardown.md`.

## CLI discovery commands

All read-only:

```bash
aws bedrock list-foundation-models --region <region>
aws bedrock list-inference-profiles --region <region> --type-equals SYSTEM_DEFINED
aws service-quotas list-service-quotas --service-code bedrock --region <region>
```

`list-service-quotas` shows applied account values (`--quota-applied-at-level ACCOUNT` is the default), including `Adjustable`.
