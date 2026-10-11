# Bedrock endpoints and APIs

> Verified against Amazon Bedrock User Guide pages endpoints, inference-chat-completions, api-keys, inference-converse (overview and quickstart), AWS CLI v2.37.12 bedrock-runtime converse reference, 2026-10-11

## Two inference endpoints

| Endpoint                        | Host                                     | APIs                                                                        |
| ------------------------------- | ---------------------------------------- | --------------------------------------------------------------------------- |
| `bedrock-runtime` (recommended) | `bedrock-runtime.<region>.amazonaws.com` | InvokeModel, Converse/ConverseStream, Chat Completions, Responses, Messages |
| `bedrock-mantle`                | `bedrock-mantle.<region>.api.aws`        | Responses, Chat Completions, Messages                                       |

OpenAI-compatible APIs on `bedrock-runtime` live under `/openai/v1`; the Anthropic Messages API under `/anthropic` (as in the AWS quickstart). Both endpoints share one inference engine, charge the same per-token price for the same model, but have **separate quotas**.

Use `bedrock-mantle` when you need: server-side or pre-configured tools (web search), background inference (`background=true`), Projects (OpenAI-compatible) or Workspaces (Anthropic-compatible), or a model only available there. Everything else goes to `bedrock-runtime`.

Differences to remember:

- `bedrock-runtime` does not implement `GET /models`. `client.models.list()` returns `404 UnknownOperationException`; use `ListFoundationModels` and `ListInferenceProfiles`. The Models API exists only on `bedrock-mantle`.
- `bedrock-runtime` Responses API is always synchronous (`background=true` gets a 400), has no server-side tools, supports only the default project, and a stored response belongs to the Region that served it.
- Guardrails, prompt caching and intelligent prompt routing are listed for `bedrock-runtime`; on `bedrock-mantle` prompt caching depends on the model card.
- Messages API structured outputs (`output_config.format`) are rejected with a 400 on `bedrock-mantle`; use Converse or InvokeModel on `bedrock-runtime`.
- On `bedrock-mantle` the path prefix varies by model (`/v1` for most, `/openai/v1` for some). A wrong prefix gives `model <id> isn't supported on this route`. Check the model card's Programmatic Access table.
- Application inference profiles are rejected (400) as a Responses target on `bedrock-runtime`; system-defined cross-Region profiles work.
- Not every model supports every API (for example gpt-oss supports Chat Completions but not Responses on `bedrock-runtime`). Check the model card.

## Converse (AWS-native)

```bash
aws bedrock-runtime converse --region "$REGION" \
  --model-id <model-or-profile-id> \
  --messages '[{"role":"user","content":[{"text":"Hello"}]}]' \
  --inference-config '{"maxTokens":256}' \
  --query 'output.message.content[0].text' --output text
```

The CLI also accepts `--system`, `--tool-config`, `--guardrail-config`, `--performance-config`, `--service-tier`, `--request-metadata`, `--output-config`.

```python
import boto3
client = boto3.client("bedrock-runtime", region_name="us-east-1")
resp = client.converse(
    modelId="<model-or-profile-id>",
    messages=[{"role": "user", "content": [{"text": "Hello"}]}],
    inferenceConfig={"maxTokens": 256},
)
```

## Over HTTP with a Bedrock API key

```bash
curl -sS -X POST "https://bedrock-runtime.${REGION}.amazonaws.com/model/<model-or-profile-id>/converse" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AWS_BEARER_TOKEN_BEDROCK" \
  -d '{"messages":[{"role":"user","content":[{"text":"Hello"}]}]}'
```

## OpenAI Chat Completions

The docs use `OPENAI_API_KEY` to carry the Bedrock key; map it from your own variable:

```bash
export OPENAI_API_KEY="$AWS_BEARER_TOKEN_BEDROCK"
curl -sS -X POST "https://bedrock-runtime.${REGION}.amazonaws.com/openai/v1/chat/completions" \
  -H "Content-Type: application/json" -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{"model":"<model-id>","messages":[{"role":"user","content":"Hello"}]}'
```

SigV4 variant (no API key):

```bash
curl -sS -X POST "https://bedrock-runtime.${REGION}.amazonaws.com/openai/v1/chat/completions" \
  -H "Content-Type: application/json" \
  --aws-sigv4 "aws:amz:${REGION}:bedrock" --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
  -d '{"model":"<model-id>","messages":[{"role":"user","content":"Hello"}]}'
```

For temporary credentials add the session token header; do not paste it.

```python
from openai import OpenAI
import os
client = OpenAI(
    base_url="https://bedrock-runtime.us-east-1.amazonaws.com/openai/v1",
    api_key=os.environ["AWS_BEARER_TOKEN_BEDROCK"],
)
r = client.chat.completions.create(model="<model-id>", messages=[{"role": "user", "content": "Hello"}])
```

On `bedrock-mantle`, set `OPENAI_BASE_URL=https://bedrock-mantle.<region>.api.aws/v1` and `GET $OPENAI_BASE_URL/models` works.

## Responses API and Messages API

The AWS overview shows the OpenAI Responses API (`client.responses.create`) and the Anthropic SDK pointed at `https://bedrock-runtime.<region>.amazonaws.com/anthropic` with a Bedrock token as `api_key`:

```python
from anthropic import Anthropic
from aws_bedrock_token_generator import provide_token
client = Anthropic(base_url="https://bedrock-runtime.us-east-1.amazonaws.com/anthropic",
                   api_key=provide_token(region="us-east-1"))
```

## InvokeModel

Body is model-specific. For Anthropic models:

```python
import json, boto3
client = boto3.client("bedrock-runtime", region_name="us-east-1")
resp = client.invoke_model(modelId="<model-id>", body=json.dumps({
    "anthropic_version": "bedrock-2023-05-31", "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Hello"}]}))
print(json.loads(resp["body"].read()))
```

## Guardrails on Chat Completions

Send headers `X-Amzn-Bedrock-GuardrailIdentifier` and `X-Amzn-Bedrock-GuardrailVersion` (optional `X-Amzn-Bedrock-Trace`), plus `amazon-bedrock-guardrailConfig` (`tagSuffix`) in the body.

## Long idle connections

Streaming or long-thinking calls through NAT gateways, interface VPC endpoints or NLBs can reset after 350 seconds idle; see `troubleshooting.md`.
