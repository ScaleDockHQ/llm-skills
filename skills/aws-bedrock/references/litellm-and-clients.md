# Bedrock with LiteLLM and OpenAI or Anthropic clients

> Verified against LiteLLM docs providers/bedrock (route table, auth parameters, cross-Region, application inference profiles, Responses and native Chat Completions routes), Amazon Bedrock User Guide pages inference-chat-completions and api-keys, 2026-10-11

## Choose how the gateway reaches Bedrock

| Option                                                                                                  | When                                                                                                              |
| ------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| LiteLLM `bedrock/` provider                                                                             | Default: uses Converse by default, SigV4 or a Bedrock API key, supports cross-Region IDs and application profiles |
| LiteLLM `openai/` provider with `api_base` = `https://bedrock-runtime.<region>.amazonaws.com/openai/v1` | Plain OpenAI-compatible hop with a Bedrock API key; unverified in LiteLLM docs, test one request                  |
| Direct OpenAI SDK against Bedrock                                                                       | One app, no gateway                                                                                               |

## LiteLLM `model_list`

```yaml
model_list:
  - model_name: bedrock-chat # alias clients use
    litellm_params:
      model: bedrock/<inference-profile-or-model-id>
      aws_region_name: us-east-1 # credentials from the AWS chain
  - model_name: bedrock-chat-apikey
    litellm_params:
      model: bedrock/<inference-profile-or-model-id>
      api_key: os.environ/AWS_BEARER_TOKEN_BEDROCK
      aws_region_name: us-east-1
  - model_name: bedrock-app-profile # application inference profile (cost tracking)
    litellm_params:
      model: bedrock/<underlying-model-or-profile-id>
      model_id: arn:aws:bedrock:<region>:<account>:application-inference-profile/<id>
      aws_region_name: us-east-1
```

Routes documented by LiteLLM: `bedrock/` (auto), `bedrock/converse/<id>` and `bedrock/invoke/<id>` to pin the API, `bedrock/chat_completions/<id>` for native Chat Completions, `bedrock/openai/<arn>` for imported models, plus per-family routes like `bedrock/llama/`. For GPT-5.6 and newer OpenAI models the plain `bedrock/` route is native Chat Completions; older GPT, gpt-oss and Grok keep Converse unless prefixed. Pin with `bedrock/converse/` when behavior must not change on upgrade.

Auth parameters: `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token`, `aws_region_name`, `aws_profile_name`, `aws_role_name`, `aws_session_name`, `aws_web_identity_token`, `aws_bedrock_runtime_endpoint`, `api_key`. Prefer the credential chain (instance role, IRSA or Pod Identity) over static keys; if you use keys reference them with `os.environ/NAME`, never inline. Use `aws_bedrock_runtime_endpoint` to target a VPC endpoint URL.

Other documented knobs: `requestMetadata` (cost tags), `guardrailConfig`, `performanceConfig: {"latency": "optimized"}`, `serviceTier`. Set a generous timeout for long generations and add a fallback alias to another provider (see `llm-gateway`).

Embeddings use the same `bedrock/` prefix with embedding model IDs.

## OpenAI SDK pointed at Bedrock

```python
from openai import OpenAI
import os
client = OpenAI(
    base_url="https://bedrock-runtime.us-east-1.amazonaws.com/openai/v1",
    api_key=os.environ["AWS_BEARER_TOKEN_BEDROCK"],
)
```

No `/models` on `bedrock-runtime`; configure model IDs explicitly. For `bedrock-mantle` use `https://bedrock-mantle.<region>.api.aws/v1` (some models need `/openai/v1`).

## Anthropic SDK pointed at Bedrock

`base_url="https://bedrock-runtime.<region>.amazonaws.com/anthropic"` with a Bedrock token as `api_key` (AWS quickstart). Use a profile ID such as a `global.` or geographic one from the model card.

## Through the gateway

```bash
curl -sS http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_KEY" -H "Content-Type: application/json" \
  -d '{"model":"bedrock-chat","messages":[{"role":"user","content":"ping"}],"max_tokens":16}'
```

Clients hold gateway virtual keys only. Short-term Bedrock keys expire within 12 hours; for a long-running gateway use an IAM role, not a key.
